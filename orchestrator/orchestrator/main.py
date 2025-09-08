#!/usr/bin/env python3
"""
Multi-Agent Orchestrator for Docker Dev Environments
Manages parallel and sequential execution of AI coding agents
"""

import asyncio
import json
import os
from typing import Dict, List, Any, Optional
from enum import Enum
from dataclasses import dataclass
import docker
import redis
from fastapi import FastAPI, BackgroundTasks
from pydantic import BaseModel
import structlog

# Configure structured logging
logger = structlog.get_logger()

# Initialize FastAPI app
app = FastAPI(title="Agent Orchestrator", version="1.0.0")

# Initialize Docker and Redis clients
docker_client = docker.from_env()
redis_client = redis.Redis(host=os.getenv('REDIS_HOST', 'redis'), port=6379, decode_responses=True)


class ExecutionMode(Enum):
    PARALLEL = "parallel"
    SEQUENTIAL = "sequential"
    HYBRID = "hybrid"


class AgentRole(Enum):
    ARCHITECT = "architect"
    DEVELOPER = "developer"
    TESTER = "tester"
    REVIEWER = "reviewer"
    ANALYZER = "analyzer"
    DOCUMENTER = "documenter"


@dataclass
class AgentConfig:
    name: str
    image: str
    role: AgentRole
    environment: Dict[str, str]
    resources: Dict[str, Any]
    dependencies: List[str] = None


class TaskRequest(BaseModel):
    task_type: str
    execution_mode: ExecutionMode
    agents: List[str]
    payload: Dict[str, Any]
    timeout: int = 3600


class TaskResult(BaseModel):
    task_id: str
    status: str
    results: Dict[str, Any]
    errors: List[str] = []
    execution_time: float


class AgentOrchestrator:
    def __init__(self):
        self.agents = self._load_agent_configs()
        self.active_tasks = {}
        self.task_queue = asyncio.Queue()
        
    def _load_agent_configs(self) -> Dict[str, AgentConfig]:
        """Load agent configurations from config file or environment"""
        return {
            "claude-architect": AgentConfig(
                name="claude-architect",
                image="claude-agent:latest",
                role=AgentRole.ARCHITECT,
                environment={"MODEL": "claude-3-opus", "FOCUS": "architecture"},
                resources={"memory": "2g", "cpus": "1.0"}
            ),
            "gemini-developer": AgentConfig(
                name="gemini-developer",
                image="gemini-agent:latest",
                role=AgentRole.DEVELOPER,
                environment={"MODEL": "gemini-2.5-pro", "FOCUS": "implementation"},
                resources={"memory": "2g", "cpus": "1.0"}
            ),
            "claude-tester": AgentConfig(
                name="claude-tester",
                image="claude-agent:latest",
                role=AgentRole.TESTER,
                environment={"MODEL": "claude-3-sonnet", "FOCUS": "testing"},
                resources={"memory": "1g", "cpus": "0.5"}
            )
        }
    
    async def execute_task(self, request: TaskRequest) -> TaskResult:
        """Main entry point for task execution"""
        task_id = self._generate_task_id()
        logger.info("executing_task", task_id=task_id, mode=request.execution_mode.value)
        
        try:
            if request.execution_mode == ExecutionMode.PARALLEL:
                result = await self._execute_parallel(task_id, request)
            elif request.execution_mode == ExecutionMode.SEQUENTIAL:
                result = await self._execute_sequential(task_id, request)
            else:  # HYBRID
                result = await self._execute_hybrid(task_id, request)
            
            return TaskResult(
                task_id=task_id,
                status="completed",
                results=result,
                execution_time=self._get_execution_time(task_id)
            )
        except Exception as e:
            logger.error("task_execution_failed", task_id=task_id, error=str(e))
            return TaskResult(
                task_id=task_id,
                status="failed",
                results={},
                errors=[str(e)],
                execution_time=self._get_execution_time(task_id)
            )
    
    async def _execute_parallel(self, task_id: str, request: TaskRequest) -> Dict:
        """Execute agents in parallel"""
        tasks = []
        for agent_name in request.agents:
            if agent_name in self.agents:
                task = self._run_agent(task_id, agent_name, request.payload)
                tasks.append(task)
        
        results = await asyncio.gather(*tasks, return_exceptions=True)
        return self._merge_parallel_results(results)
    
    async def _execute_sequential(self, task_id: str, request: TaskRequest) -> Dict:
        """Execute agents in sequence, passing results forward"""
        current_payload = request.payload
        results = {}
        
        for agent_name in request.agents:
            if agent_name in self.agents:
                agent_result = await self._run_agent(task_id, agent_name, current_payload)
                results[agent_name] = agent_result
                # Pass result to next agent
                current_payload = {**current_payload, "previous_result": agent_result}
        
        return results
    
    async def _execute_hybrid(self, task_id: str, request: TaskRequest) -> Dict:
        """Execute with smart routing based on task type"""
        # Analyze task to determine optimal execution strategy
        strategy = self._analyze_task_strategy(request)
        
        results = {}
        for phase in strategy:
            if phase["parallel"]:
                phase_results = await self._execute_parallel_phase(task_id, phase["agents"], request.payload)
            else:
                phase_results = await self._execute_sequential_phase(task_id, phase["agents"], request.payload)
            
            results[phase["name"]] = phase_results
            # Update payload with phase results for next phase
            request.payload.update({"previous_phase": phase_results})
        
        return results
    
    async def _run_agent(self, task_id: str, agent_name: str, payload: Dict) -> Dict:
        """Run a single agent in a Docker container"""
        agent_config = self.agents[agent_name]
        
        # Prepare container configuration
        container_config = {
            "image": agent_config.image,
            "name": f"{agent_name}-{task_id}",
            "environment": {
                **agent_config.environment,
                "TASK_ID": task_id,
                "PAYLOAD": json.dumps(payload)
            },
            "volumes": {
                "/workspace": {"bind": "/workspace", "mode": "rw"},
                "/artifacts": {"bind": "/artifacts", "mode": "rw"}
            },
            "mem_limit": agent_config.resources["memory"],
            "nano_cpus": int(float(agent_config.resources["cpus"]) * 1e9),
            "network": "agent-network",
            "detach": True,
            "remove": True
        }
        
        # Run container
        container = docker_client.containers.run(**container_config)
        
        # Wait for completion and get results
        result = await self._wait_for_agent_completion(container, agent_name)
        return result
    
    async def _wait_for_agent_completion(self, container, agent_name: str, timeout: int = 600) -> Dict:
        """Wait for agent container to complete and retrieve results"""
        start_time = asyncio.get_event_loop().time()
        
        while asyncio.get_event_loop().time() - start_time < timeout:
            container.reload()
            if container.status in ['exited', 'dead']:
                # Get logs as result
                logs = container.logs(stdout=True, stderr=False).decode('utf-8')
                
                # Try to parse JSON result from logs
                try:
                    # Assume last line is JSON result
                    result_line = logs.strip().split('\n')[-1]
                    return json.loads(result_line)
                except json.JSONDecodeError:
                    return {"output": logs, "agent": agent_name}
            
            await asyncio.sleep(1)
        
        # Timeout reached
        container.stop()
        raise TimeoutError(f"Agent {agent_name} execution timed out")
    
    def _analyze_task_strategy(self, request: TaskRequest) -> List[Dict]:
        """Analyze task and determine optimal execution strategy"""
        task_type = request.task_type
        
        # Predefined strategies for common task types
        strategies = {
            "feature_development": [
                {"name": "analysis", "agents": ["claude-architect", "gemini-developer"], "parallel": True},
                {"name": "implementation", "agents": ["gemini-developer"], "parallel": False},
                {"name": "testing", "agents": ["claude-tester"], "parallel": False},
                {"name": "review", "agents": ["claude-architect"], "parallel": False}
            ],
            "code_review": [
                {"name": "review", "agents": ["claude-architect", "gemini-developer", "claude-tester"], "parallel": True}
            ],
            "bug_fix": [
                {"name": "reproduce", "agents": ["claude-tester"], "parallel": False},
                {"name": "analyze", "agents": ["claude-architect"], "parallel": False},
                {"name": "fix", "agents": ["gemini-developer"], "parallel": False},
                {"name": "verify", "agents": ["claude-tester"], "parallel": False}
            ]
        }
        
        return strategies.get(task_type, [
            {"name": "default", "agents": request.agents, "parallel": True}
        ])
    
    def _merge_parallel_results(self, results: List) -> Dict:
        """Merge results from parallel execution"""
        merged = {
            "combined_output": [],
            "by_agent": {}
        }
        
        for i, result in enumerate(results):
            if isinstance(result, Exception):
                merged["by_agent"][f"agent_{i}"] = {"error": str(result)}
            else:
                merged["by_agent"][f"agent_{i}"] = result
                if isinstance(result, dict) and "output" in result:
                    merged["combined_output"].append(result["output"])
        
        return merged
    
    def _generate_task_id(self) -> str:
        """Generate unique task ID"""
        import uuid
        return str(uuid.uuid4())[:8]
    
    def _get_execution_time(self, task_id: str) -> float:
        """Get task execution time from Redis"""
        exec_time = redis_client.get(f"task:{task_id}:execution_time")
        return float(exec_time) if exec_time else 0.0


# Initialize orchestrator
orchestrator = AgentOrchestrator()


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "service": "orchestrator"}


@app.post("/execute", response_model=TaskResult)
async def execute_task(request: TaskRequest, background_tasks: BackgroundTasks):
    """Execute a task with specified agents and mode"""
    result = await orchestrator.execute_task(request)
    return result


@app.get("/agents")
async def list_agents():
    """List available agents and their configurations"""
    return {
        "agents": [
            {
                "name": agent.name,
                "role": agent.role.value,
                "image": agent.image,
                "resources": agent.resources
            }
            for agent in orchestrator.agents.values()
        ]
    }


@app.get("/tasks/{task_id}")
async def get_task_status(task_id: str):
    """Get status of a specific task"""
    status = redis_client.get(f"task:{task_id}:status")
    if not status:
        return {"error": "Task not found"}
    
    return {
        "task_id": task_id,
        "status": status,
        "execution_time": redis_client.get(f"task:{task_id}:execution_time")
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)