"""
Claude Agent Wrapper
Provides AI-powered code analysis, architecture, and testing capabilities
"""

import os
import json
import asyncio
from typing import Dict, List, Optional, Any
from datetime import datetime
from pathlib import Path

from anthropic import AsyncAnthropic
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
import uvicorn
import redis.asyncio as redis
from gitpython import Repo
import structlog
from tenacity import retry, stop_after_attempt, wait_exponential
from prometheus_client import Counter, Histogram, generate_latest

# Configure logging
logger = structlog.get_logger()

# Configuration
CLAUDE_API_KEY = os.getenv('CLAUDE_API_KEY_FILE', '/run/secrets/claude_api_key')
MODEL = os.getenv('MODEL', 'claude-3-opus-20240229')
AGENT_ROLE = os.getenv('AGENT_ROLE', 'architect')
FOCUS_AREAS = os.getenv('FOCUS_AREAS', 'architecture,design,patterns,security').split(',')
REDIS_HOST = os.getenv('REDIS_HOST', 'redis')
REDIS_PORT = int(os.getenv('REDIS_PORT', 6379))
MAX_TOKENS = int(os.getenv('MAX_TOKENS', 4096))

# Metrics
task_counter = Counter('claude_agent_tasks_total', 'Total tasks processed', ['task_type', 'status'])
task_duration = Histogram('claude_agent_task_duration_seconds', 'Task execution duration', ['task_type'])
api_calls = Counter('claude_agent_api_calls', 'API calls made', ['endpoint'])

# Initialize FastAPI
app = FastAPI(title=f"Claude Agent - {AGENT_ROLE}", version="1.0.0")

class TaskRequest(BaseModel):
    task_id: str
    task_type: str
    payload: Dict[str, Any]
    context: Optional[Dict[str, Any]] = None
    timeout: int = Field(default=300, ge=60, le=3600)

class TaskResponse(BaseModel):
    task_id: str
    agent: str
    role: str
    status: str
    output: Any
    metadata: Dict[str, Any]
    timestamp: datetime

class ClaudeAgent:
    def __init__(self):
        self.client: Optional[AsyncAnthropic] = None
        self.redis_client: Optional[redis.Redis] = None
        self.workspace_path = Path("/workspace")
        self.artifacts_path = Path("/artifacts")
        
    async def initialize(self):
        """Initialize Claude client and Redis connection"""
        # Load API key
        api_key = self._load_api_key()
        if not api_key:
            logger.error("claude_api_key_not_found")
            raise ValueError("Claude API key not found")
        
        self.client = AsyncAnthropic(api_key=api_key)
        self.redis_client = await redis.from_url(f"redis://{REDIS_HOST}:{REDIS_PORT}")
        
        logger.info("claude_agent_initialized", role=AGENT_ROLE, model=MODEL)
    
    def _load_api_key(self) -> Optional[str]:
        """Load API key from file"""
        try:
            if os.path.exists(CLAUDE_API_KEY):
                with open(CLAUDE_API_KEY, 'r') as f:
                    return f.read().strip()
            # Try environment variable as fallback
            return os.getenv('CLAUDE_API_KEY')
        except Exception as e:
            logger.error("api_key_load_failed", error=str(e))
            return None
    
    async def execute_task(self, request: TaskRequest) -> TaskResponse:
        """Execute a task based on the agent's role"""
        logger.info("executing_task", task_id=request.task_id, task_type=request.task_type)
        
        try:
            with task_duration.labels(task_type=request.task_type).time():
                if AGENT_ROLE == "architect":
                    result = await self._execute_architecture_task(request)
                elif AGENT_ROLE == "tester":
                    result = await self._execute_testing_task(request)
                elif AGENT_ROLE == "reviewer":
                    result = await self._execute_review_task(request)
                else:
                    result = await self._execute_general_task(request)
            
            task_counter.labels(task_type=request.task_type, status="success").inc()
            
            return TaskResponse(
                task_id=request.task_id,
                agent=f"claude-{AGENT_ROLE}",
                role=AGENT_ROLE,
                status="completed",
                output=result,
                metadata={
                    "model": MODEL,
                    "focus_areas": FOCUS_AREAS,
                    "execution_time": datetime.now().isoformat()
                },
                timestamp=datetime.now()
            )
            
        except Exception as e:
            logger.error("task_execution_failed", task_id=request.task_id, error=str(e))
            task_counter.labels(task_type=request.task_type, status="failed").inc()
            
            return TaskResponse(
                task_id=request.task_id,
                agent=f"claude-{AGENT_ROLE}",
                role=AGENT_ROLE,
                status="failed",
                output={"error": str(e)},
                metadata={},
                timestamp=datetime.now()
            )
    
    async def _execute_architecture_task(self, request: TaskRequest) -> Dict:
        """Execute architecture and design tasks"""
        payload = request.payload
        
        # Analyze codebase structure
        code_context = await self._analyze_codebase(payload.get("repository", "/workspace"))
        
        # Generate architecture recommendations
        prompt = self._build_architecture_prompt(payload, code_context)
        
        response = await self._call_claude(prompt)
        
        # Parse and structure the response
        return {
            "analysis": response,
            "recommendations": self._extract_recommendations(response),
            "diagrams": self._generate_architecture_diagrams(response),
            "patterns": self._identify_patterns(code_context)
        }
    
    async def _execute_testing_task(self, request: TaskRequest) -> Dict:
        """Execute testing and verification tasks"""
        payload = request.payload
        
        # Analyze code for testing
        code_to_test = await self._load_code_files(payload.get("files", []))
        
        # Generate test cases
        prompt = self._build_testing_prompt(payload, code_to_test)
        
        response = await self._call_claude(prompt)
        
        # Generate test code
        test_code = await self._generate_test_code(response, code_to_test)
        
        return {
            "test_plan": response,
            "test_cases": test_code,
            "coverage_areas": self._identify_coverage_areas(code_to_test),
            "edge_cases": self._identify_edge_cases(response)
        }
    
    async def _execute_review_task(self, request: TaskRequest) -> Dict:
        """Execute code review tasks"""
        payload = request.payload
        
        # Load code to review
        if "pr_number" in payload:
            code_changes = await self._load_pr_changes(payload["pr_number"])
        else:
            code_changes = await self._load_code_files(payload.get("files", []))
        
        # Perform review
        prompt = self._build_review_prompt(payload, code_changes)
        
        response = await self._call_claude(prompt)
        
        return {
            "review": response,
            "issues": self._extract_issues(response),
            "suggestions": self._extract_suggestions(response),
            "security_concerns": self._check_security(code_changes),
            "performance_concerns": self._check_performance(code_changes)
        }
    
    async def _execute_general_task(self, request: TaskRequest) -> Dict:
        """Execute general development tasks"""
        payload = request.payload
        
        prompt = f"""
        Task: {request.task_type}
        Payload: {json.dumps(payload, indent=2)}
        
        Please complete this task with focus on: {', '.join(FOCUS_AREAS)}
        """
        
        response = await self._call_claude(prompt)
        
        return {
            "output": response,
            "metadata": {
                "task_type": request.task_type,
                "focus_areas": FOCUS_AREAS
            }
        }
    
    @retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=2, max=10))
    async def _call_claude(self, prompt: str, system_prompt: Optional[str] = None) -> str:
        """Call Claude API with retry logic"""
        api_calls.labels(endpoint="messages").inc()
        
        messages = [{"role": "user", "content": prompt}]
        
        if not system_prompt:
            system_prompt = f"""You are an expert {AGENT_ROLE} focused on {', '.join(FOCUS_AREAS)}.
            Provide detailed, actionable insights and code when appropriate.
            Be concise but thorough in your analysis."""
        
        response = await self.client.messages.create(
            model=MODEL,
            max_tokens=MAX_TOKENS,
            messages=messages,
            system=system_prompt
        )
        
        return response.content[0].text
    
    async def _analyze_codebase(self, repo_path: str) -> Dict:
        """Analyze codebase structure"""
        try:
            repo = Repo(repo_path)
            
            # Get file structure
            files = []
            for item in Path(repo_path).rglob("*"):
                if item.is_file() and not any(p in str(item) for p in ['.git', '__pycache__', 'node_modules']):
                    files.append(str(item.relative_to(repo_path)))
            
            # Analyze git history
            recent_commits = list(repo.iter_commits(max_count=10))
            
            return {
                "files": files[:100],  # Limit to 100 files
                "total_files": len(files),
                "recent_commits": [
                    {
                        "hash": c.hexsha[:8],
                        "message": c.message.strip(),
                        "author": str(c.author),
                        "date": c.committed_datetime.isoformat()
                    }
                    for c in recent_commits
                ],
                "branches": [b.name for b in repo.branches],
                "languages": self._detect_languages(files)
            }
        except Exception as e:
            logger.error("codebase_analysis_failed", error=str(e))
            return {"error": str(e)}
    
    async def _load_code_files(self, files: List[str]) -> Dict[str, str]:
        """Load code from specified files"""
        code_files = {}
        
        for file_path in files:
            full_path = self.workspace_path / file_path
            if full_path.exists():
                try:
                    with open(full_path, 'r') as f:
                        code_files[file_path] = f.read()
                except Exception as e:
                    logger.error("file_load_failed", file=file_path, error=str(e))
        
        return code_files
    
    async def _load_pr_changes(self, pr_number: int) -> Dict:
        """Load changes from a pull request"""
        # This would integrate with GitHub/GitLab API
        # For now, return mock data
        return {
            "pr_number": pr_number,
            "files_changed": [],
            "additions": 0,
            "deletions": 0
        }
    
    def _build_architecture_prompt(self, payload: Dict, context: Dict) -> str:
        """Build prompt for architecture analysis"""
        return f"""
        Analyze the following codebase and provide architecture recommendations:
        
        Repository Structure:
        - Total Files: {context.get('total_files', 0)}
        - Languages: {', '.join(context.get('languages', []))}
        - Recent Activity: {len(context.get('recent_commits', []))} commits
        
        Task Requirements:
        {json.dumps(payload, indent=2)}
        
        Please provide:
        1. Current architecture assessment
        2. Identified patterns and anti-patterns
        3. Scalability considerations
        4. Security recommendations
        5. Suggested improvements
        6. Implementation roadmap
        """
    
    def _build_testing_prompt(self, payload: Dict, code: Dict[str, str]) -> str:
        """Build prompt for test generation"""
        code_summary = "\n".join([f"File: {f} ({len(c)} chars)" for f, c in code.items()])
        
        return f"""
        Generate comprehensive test cases for the following code:
        
        Files to test:
        {code_summary}
        
        Requirements:
        {json.dumps(payload, indent=2)}
        
        Please provide:
        1. Test strategy
        2. Unit test cases
        3. Integration test scenarios
        4. Edge cases to consider
        5. Mock data requirements
        6. Expected coverage
        """
    
    def _build_review_prompt(self, payload: Dict, changes: Dict) -> str:
        """Build prompt for code review"""
        return f"""
        Perform a comprehensive code review:
        
        Changes to review:
        {json.dumps(changes, indent=2)}
        
        Review criteria:
        {json.dumps(payload.get('criteria', ['quality', 'security', 'performance']), indent=2)}
        
        Please evaluate:
        1. Code quality and maintainability
        2. Security vulnerabilities
        3. Performance implications
        4. Best practices adherence
        5. Documentation completeness
        6. Test coverage
        
        Provide specific, actionable feedback with severity levels.
        """
    
    def _extract_recommendations(self, response: str) -> List[Dict]:
        """Extract structured recommendations from response"""
        # Parse recommendations from the response
        # This would use more sophisticated NLP in production
        recommendations = []
        
        for line in response.split('\n'):
            if any(keyword in line.lower() for keyword in ['recommend', 'suggest', 'should', 'consider']):
                recommendations.append({
                    "text": line.strip(),
                    "priority": "high" if "critical" in line.lower() else "medium"
                })
        
        return recommendations[:10]  # Limit to top 10
    
    def _extract_issues(self, response: str) -> List[Dict]:
        """Extract issues from code review"""
        issues = []
        
        for line in response.split('\n'):
            if any(keyword in line.lower() for keyword in ['issue', 'problem', 'error', 'bug', 'vulnerability']):
                severity = "high"
                if "minor" in line.lower():
                    severity = "low"
                elif "moderate" in line.lower():
                    severity = "medium"
                
                issues.append({
                    "description": line.strip(),
                    "severity": severity
                })
        
        return issues
    
    def _extract_suggestions(self, response: str) -> List[str]:
        """Extract improvement suggestions"""
        suggestions = []
        
        for line in response.split('\n'):
            if any(keyword in line.lower() for keyword in ['could', 'might', 'consider', 'improve']):
                suggestions.append(line.strip())
        
        return suggestions[:10]
    
    def _generate_architecture_diagrams(self, response: str) -> List[Dict]:
        """Generate architecture diagram specifications"""
        # This would generate mermaid/plantuml diagrams
        return [
            {
                "type": "component",
                "description": "Component interaction diagram",
                "format": "mermaid"
            }
        ]
    
    def _identify_patterns(self, context: Dict) -> List[str]:
        """Identify design patterns in codebase"""
        patterns = []
        
        # Analyze file structure for common patterns
        files = context.get('files', [])
        
        if any('controller' in f.lower() for f in files):
            patterns.append("MVC Pattern")
        if any('factory' in f.lower() for f in files):
            patterns.append("Factory Pattern")
        if any('singleton' in f.lower() for f in files):
            patterns.append("Singleton Pattern")
        if any('observer' in f.lower() for f in files):
            patterns.append("Observer Pattern")
        
        return patterns
    
    def _detect_languages(self, files: List[str]) -> List[str]:
        """Detect programming languages from file extensions"""
        extensions = set()
        for file in files:
            if '.' in file:
                ext = file.split('.')[-1]
                extensions.add(ext)
        
        language_map = {
            'py': 'Python',
            'js': 'JavaScript',
            'ts': 'TypeScript',
            'java': 'Java',
            'go': 'Go',
            'rs': 'Rust',
            'cpp': 'C++',
            'c': 'C',
            'rb': 'Ruby',
            'php': 'PHP'
        }
        
        languages = []
        for ext in extensions:
            if ext in language_map:
                languages.append(language_map[ext])
        
        return languages
    
    def _identify_coverage_areas(self, code: Dict[str, str]) -> List[str]:
        """Identify areas that need test coverage"""
        areas = []
        
        for file_path, content in code.items():
            # Simple heuristic-based identification
            if 'class' in content:
                areas.append(f"Classes in {file_path}")
            if 'def ' in content or 'function ' in content:
                areas.append(f"Functions in {file_path}")
            if 'try' in content or 'catch' in content:
                areas.append(f"Error handling in {file_path}")
        
        return areas
    
    def _identify_edge_cases(self, response: str) -> List[str]:
        """Extract edge cases from testing response"""
        edge_cases = []
        
        for line in response.split('\n'):
            if any(keyword in line.lower() for keyword in ['edge case', 'boundary', 'extreme', 'corner case']):
                edge_cases.append(line.strip())
        
        return edge_cases
    
    def _check_security(self, code: Any) -> List[Dict]:
        """Check for security concerns"""
        concerns = []
        
        # This would use more sophisticated security scanning
        security_keywords = ['eval', 'exec', 'sql', 'password', 'token', 'secret', 'api_key']
        
        code_str = str(code)
        for keyword in security_keywords:
            if keyword in code_str.lower():
                concerns.append({
                    "type": keyword,
                    "severity": "high" if keyword in ['eval', 'exec', 'sql'] else "medium",
                    "description": f"Potential security issue related to {keyword}"
                })
        
        return concerns
    
    def _check_performance(self, code: Any) -> List[Dict]:
        """Check for performance concerns"""
        concerns = []
        
        # Simple performance checks
        performance_keywords = ['nested loop', 'recursion', 'n+1', 'synchronous', 'blocking']
        
        code_str = str(code)
        for keyword in performance_keywords:
            if keyword in code_str.lower():
                concerns.append({
                    "type": keyword,
                    "description": f"Potential performance issue: {keyword}"
                })
        
        return concerns
    
    async def _generate_test_code(self, test_plan: str, code: Dict[str, str]) -> Dict[str, str]:
        """Generate actual test code based on plan"""
        test_files = {}
        
        for file_path in code.keys():
            test_file_path = f"test_{file_path}"
            
            # Generate test code prompt
            prompt = f"""
            Generate test code for {file_path} based on this plan:
            {test_plan}
            
            Original code file: {file_path}
            
            Generate complete, runnable test code using appropriate testing framework.
            """
            
            test_code = await self._call_claude(prompt)
            test_files[test_file_path] = test_code
        
        return test_files

# Initialize agent
agent = ClaudeAgent()

@app.on_event("startup")
async def startup():
    """Initialize on startup"""
    await agent.initialize()

@app.get("/health")
async def health():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "agent": f"claude-{AGENT_ROLE}",
        "model": MODEL,
        "timestamp": datetime.now().isoformat()
    }

@app.post("/execute", response_model=TaskResponse)
async def execute_task(request: TaskRequest):
    """Execute a task"""
    return await agent.execute_task(request)

@app.get("/metrics")
async def metrics():
    """Prometheus metrics endpoint"""
    return generate_latest()

@app.get("/capabilities")
async def capabilities():
    """Get agent capabilities"""
    return {
        "agent": f"claude-{AGENT_ROLE}",
        "role": AGENT_ROLE,
        "model": MODEL,
        "focus_areas": FOCUS_AREAS,
        "capabilities": {
            "architecture": AGENT_ROLE == "architect",
            "testing": AGENT_ROLE == "tester",
            "review": AGENT_ROLE == "reviewer",
            "implementation": False,  # Claude focuses on analysis
            "refactoring": False
        }
    }

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8080,
        log_level="info"
    )