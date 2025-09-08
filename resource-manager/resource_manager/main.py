"""
Resource Manager Service
Monitors and manages resource allocation for AI agents
"""

import os
import time
import asyncio
import json
from typing import Dict, List, Optional, Any
from datetime import datetime, timedelta
from dataclasses import dataclass, asdict

import docker
import psutil
import redis.asyncio as redis
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
import uvicorn
from prometheus_client import Gauge, Counter, generate_latest
import structlog

# Configure logging
logger = structlog.get_logger()

# Configuration
MAX_TOTAL_MEMORY = os.getenv('MAX_TOTAL_MEMORY', '16G')
MAX_TOTAL_CPU = int(os.getenv('MAX_TOTAL_CPU', 8))
REDIS_HOST = os.getenv('REDIS_HOST', 'redis')
REDIS_PORT = int(os.getenv('REDIS_PORT', 6379))
CHECK_INTERVAL = int(os.getenv('CHECK_INTERVAL', 30))

# Parse memory limit
def parse_memory(mem_str: str) -> int:
    """Parse memory string (e.g., '16G') to bytes"""
    units = {'K': 1024, 'M': 1024**2, 'G': 1024**3}
    if mem_str[-1] in units:
        return int(mem_str[:-1]) * units[mem_str[-1]]
    return int(mem_str)

MAX_MEMORY_BYTES = parse_memory(MAX_TOTAL_MEMORY)

# Metrics
memory_usage_gauge = Gauge('resource_manager_memory_usage_bytes', 'Memory usage by container', ['container'])
cpu_usage_gauge = Gauge('resource_manager_cpu_usage_percent', 'CPU usage by container', ['container'])
total_memory_gauge = Gauge('resource_manager_total_memory_bytes', 'Total memory usage')
total_cpu_gauge = Gauge('resource_manager_total_cpu_percent', 'Total CPU usage')
resource_violations = Counter('resource_manager_violations', 'Resource limit violations', ['type'])

# Initialize FastAPI
app = FastAPI(title="Resource Manager", version="1.0.0")

# Docker client
docker_client = docker.from_env()

@dataclass
class ContainerResources:
    container_id: str
    name: str
    memory_usage: int
    memory_limit: int
    cpu_percent: float
    status: str
    created_at: datetime

@dataclass
class ResourceAllocation:
    container_name: str
    memory_allocated: int
    cpu_allocated: float
    priority: int
    can_scale: bool

class ResourceRequest(BaseModel):
    container_name: str
    memory_required: str  # e.g., "2G"
    cpu_required: float  # e.g., 1.0
    priority: int = Field(default=5, ge=1, le=10)

class ResourceResponse(BaseModel):
    approved: bool
    allocated_memory: Optional[int]
    allocated_cpu: Optional[float]
    reason: Optional[str]

class ResourceManager:
    def __init__(self):
        self.redis_client: Optional[redis.Redis] = None
        self.resource_cache: Dict[str, ContainerResources] = {}
        self.allocation_history: List[ResourceAllocation] = []
        self.monitoring_task: Optional[asyncio.Task] = None
        
    async def initialize(self):
        """Initialize Redis connection and start monitoring"""
        self.redis_client = await redis.from_url(f"redis://{REDIS_HOST}:{REDIS_PORT}")
        self.monitoring_task = asyncio.create_task(self.monitor_resources())
        logger.info("resource_manager_initialized")
    
    async def shutdown(self):
        """Cleanup resources"""
        if self.monitoring_task:
            self.monitoring_task.cancel()
        if self.redis_client:
            await self.redis_client.close()
    
    async def monitor_resources(self):
        """Continuously monitor container resources"""
        while True:
            try:
                await self.check_resources()
                await asyncio.sleep(CHECK_INTERVAL)
            except asyncio.CancelledError:
                break
            except Exception as e:
                logger.error("monitoring_error", error=str(e))
                await asyncio.sleep(5)
    
    async def check_resources(self):
        """Check current resource usage across all containers"""
        total_memory = 0
        total_cpu = 0.0
        
        containers = docker_client.containers.list()
        
        for container in containers:
            # Skip non-agent containers
            if not any(name in container.name for name in ["agent", "claude", "gemini", "codeium"]):
                continue
            
            try:
                stats = container.stats(stream=False)
                
                # Calculate memory usage
                memory_usage = stats["memory_stats"].get("usage", 0)
                memory_limit = stats["memory_stats"].get("limit", 0)
                
                # Calculate CPU percentage
                cpu_percent = self._calculate_cpu_percent(stats)
                
                # Update cache
                resource_info = ContainerResources(
                    container_id=container.id[:12],
                    name=container.name,
                    memory_usage=memory_usage,
                    memory_limit=memory_limit,
                    cpu_percent=cpu_percent,
                    status=container.status,
                    created_at=datetime.now()
                )
                
                self.resource_cache[container.name] = resource_info
                
                # Update metrics
                memory_usage_gauge.labels(container=container.name).set(memory_usage)
                cpu_usage_gauge.labels(container=container.name).set(cpu_percent)
                
                total_memory += memory_usage
                total_cpu += cpu_percent
                
                # Store in Redis
                await self.redis_client.hset(
                    f"resources:{container.name}",
                    mapping={
                        "memory_usage": memory_usage,
                        "memory_limit": memory_limit,
                        "cpu_percent": cpu_percent,
                        "updated_at": datetime.now().isoformat()
                    }
                )
                
            except Exception as e:
                logger.error("container_stats_error", container=container.name, error=str(e))
        
        # Update total metrics
        total_memory_gauge.set(total_memory)
        total_cpu_gauge.set(total_cpu)
        
        # Check for violations
        if total_memory > MAX_MEMORY_BYTES:
            resource_violations.labels(type="memory").inc()
            await self.handle_memory_violation(total_memory)
        
        if total_cpu > MAX_TOTAL_CPU * 100:
            resource_violations.labels(type="cpu").inc()
            await self.handle_cpu_violation(total_cpu)
    
    def _calculate_cpu_percent(self, stats: Dict) -> float:
        """Calculate CPU percentage from Docker stats"""
        try:
            cpu_delta = stats["cpu_stats"]["cpu_usage"]["total_usage"] - \
                       stats["precpu_stats"]["cpu_usage"]["total_usage"]
            system_delta = stats["cpu_stats"]["system_cpu_usage"] - \
                          stats["precpu_stats"]["system_cpu_usage"]
            
            if system_delta > 0 and cpu_delta > 0:
                cpu_count = len(stats["cpu_stats"]["cpu_usage"].get("percpu_usage", [1]))
                return (cpu_delta / system_delta) * cpu_count * 100.0
        except (KeyError, ZeroDivisionError):
            pass
        return 0.0
    
    async def handle_memory_violation(self, current_usage: int):
        """Handle memory limit violation"""
        logger.warning("memory_violation", 
                      current=current_usage, 
                      limit=MAX_MEMORY_BYTES,
                      overage=current_usage - MAX_MEMORY_BYTES)
        
        # Find containers to scale down
        sorted_containers = sorted(
            self.resource_cache.values(),
            key=lambda x: (x.memory_usage, -self._get_container_priority(x.name)),
            reverse=True
        )
        
        for container_res in sorted_containers:
            if current_usage <= MAX_MEMORY_BYTES:
                break
            
            # Try to reduce memory allocation
            container = docker_client.containers.get(container_res.container_id)
            new_limit = int(container_res.memory_limit * 0.9)  # Reduce by 10%
            
            try:
                container.update(mem_limit=new_limit)
                logger.info("memory_scaled_down", 
                           container=container_res.name,
                           new_limit=new_limit)
                current_usage -= (container_res.memory_limit - new_limit)
            except Exception as e:
                logger.error("scale_down_failed", container=container_res.name, error=str(e))
    
    async def handle_cpu_violation(self, current_usage: float):
        """Handle CPU limit violation"""
        logger.warning("cpu_violation",
                      current=current_usage,
                      limit=MAX_TOTAL_CPU * 100)
        
        # Find containers to throttle
        sorted_containers = sorted(
            self.resource_cache.values(),
            key=lambda x: (x.cpu_percent, -self._get_container_priority(x.name)),
            reverse=True
        )
        
        for container_res in sorted_containers:
            if current_usage <= MAX_TOTAL_CPU * 100:
                break
            
            # Try to reduce CPU allocation
            container = docker_client.containers.get(container_res.container_id)
            
            try:
                # Reduce CPU quota
                new_cpu_quota = int(container_res.cpu_percent * 0.9 * 100000 / 100)
                container.update(cpu_quota=new_cpu_quota)
                logger.info("cpu_throttled",
                           container=container_res.name,
                           new_quota=new_cpu_quota)
            except Exception as e:
                logger.error("throttle_failed", container=container_res.name, error=str(e))
    
    def _get_container_priority(self, container_name: str) -> int:
        """Get priority for a container (higher = more important)"""
        priority_map = {
            "orchestrator": 10,
            "claude-architect": 8,
            "gemini-developer": 7,
            "claude-tester": 6,
            "codeium-refactorer": 5,
            "resource-manager": 9,
            "redis": 10,
            "prometheus": 4,
            "grafana": 3
        }
        
        for key, priority in priority_map.items():
            if key in container_name:
                return priority
        return 5  # Default priority
    
    async def request_resources(self, request: ResourceRequest) -> ResourceResponse:
        """Handle resource allocation request"""
        required_memory = parse_memory(request.memory_required)
        required_cpu = request.cpu_required * 100  # Convert to percentage
        
        # Calculate current usage
        current_memory = sum(r.memory_usage for r in self.resource_cache.values())
        current_cpu = sum(r.cpu_percent for r in self.resource_cache.values())
        
        # Check if resources are available
        memory_available = (MAX_MEMORY_BYTES - current_memory) >= required_memory
        cpu_available = ((MAX_TOTAL_CPU * 100) - current_cpu) >= required_cpu
        
        if memory_available and cpu_available:
            # Approve allocation
            allocation = ResourceAllocation(
                container_name=request.container_name,
                memory_allocated=required_memory,
                cpu_allocated=request.cpu_required,
                priority=request.priority,
                can_scale=True
            )
            
            self.allocation_history.append(allocation)
            
            # Store in Redis
            await self.redis_client.hset(
                f"allocation:{request.container_name}",
                mapping={
                    "memory": required_memory,
                    "cpu": request.cpu_required,
                    "priority": request.priority,
                    "approved_at": datetime.now().isoformat()
                }
            )
            
            return ResourceResponse(
                approved=True,
                allocated_memory=required_memory,
                allocated_cpu=request.cpu_required,
                reason="Resources allocated successfully"
            )
        else:
            # Try to free up resources if high priority
            if request.priority >= 8:
                await self.free_resources_for_priority(required_memory, required_cpu)
                # Recheck availability
                current_memory = sum(r.memory_usage for r in self.resource_cache.values())
                current_cpu = sum(r.cpu_percent for r in self.resource_cache.values())
                
                memory_available = (MAX_MEMORY_BYTES - current_memory) >= required_memory
                cpu_available = ((MAX_TOTAL_CPU * 100) - current_cpu) >= required_cpu
                
                if memory_available and cpu_available:
                    return ResourceResponse(
                        approved=True,
                        allocated_memory=required_memory,
                        allocated_cpu=request.cpu_required,
                        reason="Resources allocated after rebalancing"
                    )
            
            return ResourceResponse(
                approved=False,
                allocated_memory=None,
                allocated_cpu=None,
                reason=f"Insufficient resources. Memory available: {memory_available}, CPU available: {cpu_available}"
            )
    
    async def free_resources_for_priority(self, required_memory: int, required_cpu: float):
        """Try to free resources for high-priority request"""
        logger.info("freeing_resources_for_priority", 
                   required_memory=required_memory,
                   required_cpu=required_cpu)
        
        # Find low-priority containers to stop or scale down
        sorted_containers = sorted(
            self.resource_cache.values(),
            key=lambda x: self._get_container_priority(x.name)
        )
        
        freed_memory = 0
        freed_cpu = 0
        
        for container_res in sorted_containers:
            if freed_memory >= required_memory and freed_cpu >= required_cpu:
                break
            
            priority = self._get_container_priority(container_res.name)
            if priority <= 5:  # Only affect low-priority containers
                try:
                    container = docker_client.containers.get(container_res.container_id)
                    
                    # Stop container if very low priority
                    if priority <= 3:
                        container.stop()
                        freed_memory += container_res.memory_usage
                        freed_cpu += container_res.cpu_percent
                        logger.info("container_stopped_for_priority", container=container_res.name)
                    else:
                        # Scale down
                        new_mem = int(container_res.memory_limit * 0.7)
                        container.update(mem_limit=new_mem)
                        freed_memory += (container_res.memory_limit - new_mem)
                        logger.info("container_scaled_for_priority", container=container_res.name)
                        
                except Exception as e:
                    logger.error("free_resources_failed", container=container_res.name, error=str(e))
    
    def get_resource_summary(self) -> Dict:
        """Get current resource usage summary"""
        total_memory = sum(r.memory_usage for r in self.resource_cache.values())
        total_cpu = sum(r.cpu_percent for r in self.resource_cache.values())
        
        return {
            "total_memory_used": total_memory,
            "total_memory_limit": MAX_MEMORY_BYTES,
            "memory_usage_percent": (total_memory / MAX_MEMORY_BYTES) * 100,
            "total_cpu_used": total_cpu,
            "total_cpu_limit": MAX_TOTAL_CPU * 100,
            "cpu_usage_percent": (total_cpu / (MAX_TOTAL_CPU * 100)) * 100,
            "active_containers": len(self.resource_cache),
            "containers": [
                {
                    "name": res.name,
                    "memory_mb": res.memory_usage / 1024 / 1024,
                    "cpu_percent": res.cpu_percent,
                    "status": res.status
                }
                for res in self.resource_cache.values()
            ]
        }

# Initialize resource manager
resource_manager = ResourceManager()

@app.on_event("startup")
async def startup():
    """Initialize on startup"""
    await resource_manager.initialize()

@app.on_event("shutdown")
async def shutdown():
    """Cleanup on shutdown"""
    await resource_manager.shutdown()

@app.get("/health")
async def health():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "service": "resource-manager",
        "timestamp": datetime.now().isoformat()
    }

@app.post("/allocate", response_model=ResourceResponse)
async def allocate_resources(request: ResourceRequest):
    """Request resource allocation"""
    return await resource_manager.request_resources(request)

@app.get("/summary")
async def get_summary():
    """Get resource usage summary"""
    return resource_manager.get_resource_summary()

@app.get("/metrics")
async def metrics():
    """Prometheus metrics endpoint"""
    return generate_latest()

@app.get("/containers")
async def list_containers():
    """List monitored containers and their resources"""
    return {
        "containers": [
            asdict(res) for res in resource_manager.resource_cache.values()
        ]
    }

@app.post("/rebalance")
async def rebalance_resources():
    """Trigger resource rebalancing"""
    await resource_manager.check_resources()
    return {"message": "Resource rebalancing triggered"}

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8001,
        log_level="info"
    )