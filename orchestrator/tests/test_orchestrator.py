"""
Test Suite for Orchestrator Service
Following TDD principles - tests written BEFORE implementation
"""

import pytest
import asyncio
import json
from unittest.mock import Mock, patch, AsyncMock
from datetime import datetime

# Import the module we're testing (will fail initially in RED phase)
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from orchestrator.main import (
    TaskManager, 
    ExecutionMode, 
    TaskStatus,
    TaskRequest,
    TaskResponse,
    app
)


class TestTaskManager:
    """Test suite for TaskManager following RED-GREEN-REFACTOR cycle"""
    
    @pytest.fixture
    def task_manager(self):
        """Create a TaskManager instance for testing"""
        return TaskManager()
    
    @pytest.fixture
    def sample_task_request(self):
        """Sample task request for testing"""
        return TaskRequest(
            task_type="test_task",
            execution_mode=ExecutionMode.PARALLEL,
            agents=["claude-architect", "gemini-developer"],
            payload={"test": True, "data": "sample"},
            priority=5,
            timeout=300
        )
    
    # RED Phase Test 1: Task submission should generate unique ID
    @pytest.mark.asyncio
    async def test_submit_task_generates_unique_id(self, task_manager, sample_task_request):
        """Test that submitting a task generates a unique ID"""
        # Act
        task_id_1 = await task_manager.submit_task(sample_task_request)
        task_id_2 = await task_manager.submit_task(sample_task_request)
        
        # Assert
        assert task_id_1 is not None
        assert task_id_2 is not None
        assert task_id_1 != task_id_2
        assert task_id_1.startswith("task_")
    
    # RED Phase Test 2: Task should be queued in Redis
    @pytest.mark.asyncio
    async def test_task_queued_in_redis(self, task_manager, sample_task_request):
        """Test that submitted tasks are queued in Redis"""
        # Arrange
        with patch('orchestrator.main.redis_client') as mock_redis:
            mock_redis.lpush = AsyncMock()
            task_manager.redis_client = mock_redis
            
            # Act
            task_id = await task_manager.submit_task(sample_task_request)
            
            # Assert
            mock_redis.lpush.assert_called_once()
            call_args = mock_redis.lpush.call_args[0]
            assert call_args[0] == "task_queue"
            task_data = json.loads(call_args[1])
            assert task_data["id"] == task_id
            assert task_data["type"] == "test_task"
    
    # RED Phase Test 3: Parallel execution should run agents concurrently
    @pytest.mark.asyncio
    async def test_parallel_execution_runs_concurrently(self, task_manager):
        """Test that parallel execution runs agents concurrently"""
        # Arrange
        task = {
            "id": "task_123",
            "agents": ["agent1", "agent2", "agent3"],
            "payload": {"test": True}
        }
        
        with patch.object(task_manager, '_invoke_agent') as mock_invoke:
            mock_invoke.return_value = {"result": "success"}
            
            # Act
            start_time = asyncio.get_event_loop().time()
            results = await task_manager._execute_parallel(task)
            duration = asyncio.get_event_loop().time() - start_time
            
            # Assert
            assert len(results) == 3
            assert mock_invoke.call_count == 3
            # Should run in parallel, not sequentially
            assert duration < 1.0  # Assuming each agent takes < 1s
    
    # RED Phase Test 4: Sequential execution should pass results forward
    @pytest.mark.asyncio
    async def test_sequential_execution_passes_results(self, task_manager):
        """Test that sequential execution passes results between agents"""
        # Arrange
        task = {
            "id": "task_456",
            "agents": ["agent1", "agent2"],
            "payload": {"initial": "data"}
        }
        
        results_chain = []
        
        async def mock_agent(agent_name, payload):
            results_chain.append(payload)
            return {"agent": agent_name, "processed": True}
        
        with patch.object(task_manager, '_invoke_agent', side_effect=mock_agent):
            # Act
            results = await task_manager._execute_sequential(task)
            
            # Assert
            assert len(results) == 2
            # Second agent should receive first agent's output
            assert "previous_result" in results_chain[1]
            assert results_chain[1]["previous_result"]["agent"] == "agent1"
    
    # RED Phase Test 5: Hybrid mode should intelligently route tasks
    @pytest.mark.asyncio
    async def test_hybrid_mode_intelligent_routing(self, task_manager):
        """Test that hybrid mode routes tasks based on type"""
        # Arrange
        review_task = {
            "id": "task_789",
            "type": "code_review",
            "agents": ["agent1", "agent2"],
            "payload": {}
        }
        
        feature_task = {
            "id": "task_890",
            "type": "feature_development",
            "agents": ["agent1", "agent2"],
            "payload": {}
        }
        
        with patch.object(task_manager, '_execute_parallel') as mock_parallel:
            with patch.object(task_manager, '_execute_sequential') as mock_sequential:
                mock_parallel.return_value = []
                mock_sequential.return_value = []
                
                # Act
                await task_manager._execute_hybrid(review_task)
                await task_manager._execute_hybrid(feature_task)
                
                # Assert
                mock_parallel.assert_called_once()  # Review should be parallel
                mock_sequential.assert_called_once()  # Feature should be sequential
    
    # RED Phase Test 6: Failed tasks should be marked appropriately
    @pytest.mark.asyncio
    async def test_failed_task_status_update(self, task_manager, sample_task_request):
        """Test that failed tasks are marked with FAILED status"""
        # Arrange
        task_id = await task_manager.submit_task(sample_task_request)
        
        with patch.object(task_manager, '_execute_parallel', side_effect=Exception("Test error")):
            # Act
            try:
                await task_manager.execute_task(task_id)
            except:
                pass
            
            # Assert
            task = task_manager.tasks[task_id]
            assert task["status"] == TaskStatus.FAILED
            assert "error" in task
            assert "Test error" in task["error"]
    
    # RED Phase Test 7: Resource limits should be enforced
    @pytest.mark.asyncio
    async def test_parallel_execution_respects_limits(self, task_manager):
        """Test that parallel execution respects MAX_PARALLEL_AGENTS limit"""
        # Arrange
        task = {
            "id": "task_limit",
            "agents": ["agent1", "agent2", "agent3", "agent4", "agent5"],
            "payload": {}
        }
        
        concurrent_count = 0
        max_concurrent = 0
        
        async def mock_agent(agent_name, payload):
            nonlocal concurrent_count, max_concurrent
            concurrent_count += 1
            max_concurrent = max(max_concurrent, concurrent_count)
            await asyncio.sleep(0.1)
            concurrent_count -= 1
            return {"result": "success"}
        
        with patch.object(task_manager, '_invoke_agent', side_effect=mock_agent):
            with patch('orchestrator.main.MAX_PARALLEL_AGENTS', 3):
                # Act
                await task_manager._execute_parallel(task)
                
                # Assert
                assert max_concurrent <= 3  # Should not exceed limit


class TestResourceManager:
    """Test suite for Resource Manager service"""
    
    # RED Phase Test 8: Resource allocation should check availability
    @pytest.mark.asyncio
    async def test_resource_allocation_checks_availability(self):
        """Test that resource allocation checks current usage"""
        # This test will fail until ResourceManager is properly implemented
        from resource_manager.main import ResourceManager, ResourceRequest
        
        # Arrange
        manager = ResourceManager()
        request = ResourceRequest(
            container_name="test-container",
            memory_required="2G",
            cpu_required=1.0,
            priority=5
        )
        
        # Mock current usage to be near limit
        manager.resource_cache = {
            "existing-container": Mock(memory_usage=15*1024**3, cpu_percent=700)
        }
        
        # Act
        response = await manager.request_resources(request)
        
        # Assert
        assert response.approved == False
        assert "Insufficient resources" in response.reason


class TestTDDWorkflow:
    """Test suite for TDD workflow automation"""
    
    # RED Phase Test 9: TDD cycle should enforce test-first
    def test_tdd_cycle_enforces_test_first(self):
        """Test that TDD cycle blocks implementation without tests"""
        from .claude.hooks.tdd_enforcer import TDDEnforcer
        
        # Arrange
        enforcer = TDDEnforcer()
        context = {
            'file_path': 'src/new_feature.py',
            'code_type': 'implementation',
            'existing_tests': []
        }
        
        # Act
        allowed, message = enforcer.hook_pre_code_generation(context)
        
        # Assert
        assert allowed == False
        assert "No test found" in message
        assert "Please write a test first" in message
    
    # RED Phase Test 10: Coverage should be tracked
    def test_coverage_tracking(self):
        """Test that coverage is tracked and enforced"""
        from .claude.hooks.tdd_enforcer import TDDEnforcer
        
        # Arrange
        enforcer = TDDEnforcer()
        enforcer.coverage_threshold = 80
        
        # Mock low coverage
        with patch.object(enforcer, '_get_project_coverage', return_value=60):
            context = {'changed_files': ['src/feature.py']}
            
            # Act
            allowed, message = enforcer.hook_pre_commit(context)
            
            # Assert
            assert allowed == False
            assert "Coverage" in message
            assert "below threshold" in message


# Integration tests
class TestIntegration:
    """Integration tests for the complete system"""
    
    # RED Phase Test 11: End-to-end task execution
    @pytest.mark.asyncio
    async def test_end_to_end_task_execution(self):
        """Test complete task execution from submission to completion"""
        # Arrange
        from httpx import AsyncClient
        
        async with AsyncClient(app=app, base_url="http://test") as client:
            task_data = {
                "task_type": "test_integration",
                "execution_mode": "parallel",
                "agents": ["claude-architect"],
                "payload": {"test": True},
                "timeout": 60
            }
            
            # Act
            response = await client.post("/execute", json=task_data)
            
            # Assert
            assert response.status_code == 200
            data = response.json()
            assert "task_id" in data
            assert data["status"] == "pending"


if __name__ == "__main__":
    # Run tests with coverage
    pytest.main([__file__, "-v", "--cov=orchestrator", "--cov-report=term-missing"])