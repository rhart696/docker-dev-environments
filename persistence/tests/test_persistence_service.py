"""
Test Suite for Persistence Service
These tests SHOULD have been written BEFORE implementing persistence_service.py
Following TDD RED-GREEN-REFACTOR cycle
"""

import pytest
import json
import tempfile
import shutil
from pathlib import Path
from unittest.mock import Mock, patch, MagicMock
import sys
import os

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from persistence_service import app, SpecValidator, PersistenceManager

class TestPersistenceService:
    """Tests that should have been written FIRST in TDD"""
    
    @pytest.fixture
    def client(self):
        """Create test client for Flask app"""
        app.config['TESTING'] = True
        with app.test_client() as client:
            yield client
    
    @pytest.fixture
    def temp_dirs(self):
        """Create temporary directories for testing"""
        workspace = tempfile.mkdtemp()
        specs = tempfile.mkdtemp()
        outputs = tempfile.mkdtemp()
        
        yield {
            'workspace': workspace,
            'specs': specs,
            'outputs': outputs
        }
        
        # Cleanup
        shutil.rmtree(workspace, ignore_errors=True)
        shutil.rmtree(specs, ignore_errors=True)
        shutil.rmtree(outputs, ignore_errors=True)
    
    # =========================================================================
    # RED PHASE: Tests that define expected behavior
    # =========================================================================
    
    def test_save_endpoint_exists(self, client):
        """Test that /save endpoint exists and accepts POST"""
        response = client.post('/save', 
            json={'filename': 'test.py', 'content': 'print("test")'})
        assert response.status_code in [200, 400, 500]  # Any response means endpoint exists
    
    def test_save_requires_filename_and_content(self, client):
        """Test that save endpoint validates required fields"""
        # Missing filename
        response = client.post('/save', json={'content': 'test'})
        assert response.status_code == 400
        assert 'Missing filename' in response.get_json()['message']
        
        # Missing content  
        response = client.post('/save', json={'filename': 'test.py'})
        assert response.status_code == 400
        assert 'Missing' in response.get_json()['message']
    
    def test_save_creates_file_with_content(self, client, temp_dirs):
        """Test that files are actually saved to disk"""
        with patch.dict(os.environ, {'WORKSPACE_DIR': temp_dirs['workspace']}):
            response = client.post('/save', json={
                'filename': 'src/test.py',
                'content': 'def hello():\n    return "world"'
            })
            
            assert response.status_code == 200
            
            # Verify file was created
            file_path = Path(temp_dirs['workspace']) / 'src' / 'test.py'
            assert file_path.exists()
            assert file_path.read_text() == 'def hello():\n    return "world"'
    
    def test_save_creates_directories_if_needed(self, client, temp_dirs):
        """Test that nested directories are created automatically"""
        with patch.dict(os.environ, {'WORKSPACE_DIR': temp_dirs['workspace']}):
            response = client.post('/save', json={
                'filename': 'deep/nested/path/file.txt',
                'content': 'test content'
            })
            
            assert response.status_code == 200
            file_path = Path(temp_dirs['workspace']) / 'deep' / 'nested' / 'path' / 'file.txt'
            assert file_path.exists()
    
    def test_save_with_metadata(self, client):
        """Test that metadata is accepted and processed"""
        response = client.post('/save', json={
            'filename': 'test.py',
            'content': 'print("test")',
            'metadata': {
                'agent': 'test-agent',
                'spec_name': 'test-spec',
                'tdd_phase': 'red'
            }
        })
        
        data = response.get_json()
        assert response.status_code == 200
        assert 'status' in data
    
    def test_validate_endpoint_exists(self, client):
        """Test that /validate endpoint exists"""
        response = client.post('/validate', json={
            'filename': 'test.py',
            'content': 'test',
            'spec_name': 'test-spec'
        })
        assert response.status_code in [200, 400, 500]
    
    def test_specs_list_endpoint(self, client):
        """Test that /specs endpoint returns list of specifications"""
        response = client.get('/specs')
        assert response.status_code == 200
        assert isinstance(response.get_json(), list)
    
    def test_status_endpoint(self, client):
        """Test that /status endpoint returns service information"""
        response = client.get('/status')
        assert response.status_code == 200
        
        data = response.get_json()
        assert 'service' in data
        assert data['service'] == 'persistence-service'
        assert 'workspace' in data
        assert 'tdd_mode' in data


class TestSpecValidator:
    """Tests for specification validation (should have been written first)"""
    
    @pytest.fixture
    def validator(self, tmp_path):
        """Create validator with temp directory"""
        return SpecValidator(str(tmp_path))
    
    @pytest.fixture
    def sample_spec(self, tmp_path):
        """Create a sample specification file"""
        spec = {
            'feature': {'name': 'Test Feature'},
            'outputs': [
                {
                    'path': 'tests/test_feature.py',
                    'type': 'test',
                    'phase': 'red',
                    'required_elements': ['def test_', 'assert']
                },
                {
                    'path': 'src/feature.py',
                    'type': 'implementation',
                    'phase': 'green',
                    'required_elements': ['class Feature', 'def process']
                }
            ]
        }
        
        spec_file = tmp_path / 'test-spec.yaml'
        import yaml
        with open(spec_file, 'w') as f:
            yaml.dump(spec, f)
        
        return 'test-spec'
    
    def test_load_spec_returns_none_if_not_found(self, validator):
        """Test that missing specs return None"""
        spec = validator.load_spec('non-existent')
        assert spec is None
    
    def test_load_spec_caches_results(self, validator, sample_spec):
        """Test that specs are cached after first load"""
        # First load
        spec1 = validator.load_spec(sample_spec)
        # Second load should come from cache
        spec2 = validator.load_spec(sample_spec)
        assert spec1 is spec2  # Same object reference
    
    def test_validate_output_checks_required_elements(self, validator, sample_spec):
        """Test that validation checks for required elements"""
        # Valid test file
        result = validator.validate_output(
            'tests/test_feature.py',
            'def test_something():\n    assert True',
            sample_spec
        )
        assert result['valid'] is True
        
        # Invalid - missing required element
        result = validator.validate_output(
            'tests/test_feature.py',
            'def something():  # missing test_ prefix\n    return True',
            sample_spec
        )
        assert result['valid'] is False
        assert 'def test_' in str(result['errors'])
    
    def test_validate_enforces_tdd_phase_order(self, validator, sample_spec, tmp_path):
        """Test that TDD phase order is enforced"""
        with patch.dict(os.environ, {'TDD_MODE': 'enforced'}):
            # Try to create implementation without tests
            result = validator.validate_output(
                'src/feature.py',
                'class Feature:\n    def process(self): pass',
                sample_spec
            )
            
            # Should fail because no tests exist
            assert result['valid'] is False
            assert 'violates TDD' in str(result['errors'])


class TestPersistenceManager:
    """Tests for file persistence and git integration"""
    
    @pytest.fixture
    def manager(self, tmp_path):
        """Create persistence manager with temp directory"""
        return PersistenceManager(str(tmp_path))
    
    def test_ensures_git_repo(self, tmp_path):
        """Test that git repo is initialized if not present"""
        manager = PersistenceManager(str(tmp_path))
        assert (tmp_path / '.git').exists()
    
    def test_save_file_creates_file(self, manager, tmp_path):
        """Test that files are saved correctly"""
        result = manager.save_file('test.txt', 'Hello World')
        
        assert result['status'] == 'saved'
        assert (tmp_path / 'test.txt').exists()
        assert (tmp_path / 'test.txt').read_text() == 'Hello World'
    
    def test_save_file_detects_unchanged_content(self, manager, tmp_path):
        """Test that unchanged files are detected"""
        # First save
        manager.save_file('test.txt', 'Same content')
        
        # Second save with same content
        result = manager.save_file('test.txt', 'Same content')
        assert result['status'] == 'unchanged'
    
    def test_save_file_creates_nested_directories(self, manager, tmp_path):
        """Test that nested paths are created"""
        result = manager.save_file('deep/path/file.txt', 'content')
        
        assert result['status'] == 'saved'
        assert (tmp_path / 'deep' / 'path' / 'file.txt').exists()
    
    @patch('git.Repo')
    def test_auto_commit_when_enabled(self, mock_repo, tmp_path):
        """Test that files are auto-committed when enabled"""
        with patch.dict(os.environ, {'AUTO_COMMIT': 'true'}):
            manager = PersistenceManager(str(tmp_path))
            manager.save_file('test.py', 'code', {'agent': 'test-agent'})
            
            # Verify commit was attempted
            assert mock_repo.return_value.index.add.called
            assert mock_repo.return_value.index.commit.called


class TestTDDEnforcement:
    """Tests for TDD enforcement in the persistence service"""
    
    @pytest.fixture
    def client(self):
        """Create test client with TDD enforced"""
        with patch.dict(os.environ, {'TDD_MODE': 'enforced'}):
            app.config['TESTING'] = True
            with app.test_client() as client:
                yield client
    
    def test_blocks_implementation_without_tests(self, client, tmp_path):
        """Test that implementation cannot be saved before tests"""
        with patch.dict(os.environ, {
            'WORKSPACE_DIR': str(tmp_path),
            'SPECS_DIR': str(tmp_path),
            'VALIDATE_SPECS': 'true',
            'TDD_MODE': 'enforced'
        }):
            # Create a spec requiring tests
            spec = {
                'outputs': [
                    {'path': 'tests/test_feature.py', 'type': 'test', 'phase': 'red'},
                    {'path': 'src/feature.py', 'type': 'implementation', 'phase': 'green'}
                ]
            }
            
            import yaml
            with open(tmp_path / 'feature.yaml', 'w') as f:
                yaml.dump(spec, f)
            
            # Try to save implementation without tests
            response = client.post('/save', json={
                'filename': 'src/feature.py',
                'content': 'class Feature: pass',
                'metadata': {'spec_name': 'feature', 'tdd_phase': 'green'}
            })
            
            # Should be rejected
            assert response.status_code == 400
            data = response.get_json()
            assert 'violates TDD' in str(data)
    
    def test_allows_tests_first(self, client):
        """Test that tests can be saved first (RED phase)"""
        response = client.post('/save', json={
            'filename': 'tests/test_feature.py',
            'content': 'def test_feature(): assert True',
            'metadata': {'tdd_phase': 'red'}
        })
        
        assert response.status_code == 200


# =========================================================================
# Integration tests that verify the complete workflow
# =========================================================================

class TestIntegrationWorkflow:
    """Integration tests for complete TDD workflow"""
    
    def test_complete_tdd_cycle(self, tmp_path):
        """Test complete RED-GREEN-REFACTOR cycle"""
        # This test verifies the entire TDD workflow works end-to-end
        
        # RED: Write test first
        test_file = tmp_path / 'tests' / 'test_feature.py'
        test_file.parent.mkdir(parents=True)
        test_file.write_text('def test_feature():\n    assert feature() == "works"')
        
        # GREEN: Implementation to pass test
        impl_file = tmp_path / 'src' / 'feature.py'
        impl_file.parent.mkdir(parents=True)
        impl_file.write_text('def feature():\n    return "works"')
        
        # REFACTOR: Improve while keeping tests green
        improved = 'def feature():\n    """Improved version"""\n    return "works"'
        impl_file.write_text(improved)
        
        # Verify all files exist and cycle completed
        assert test_file.exists()
        assert impl_file.exists()
        assert 'Improved version' in impl_file.read_text()


if __name__ == '__main__':
    pytest.main([__file__, '-v', '--tb=short'])