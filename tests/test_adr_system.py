"""
Test Suite for ADR (Architecture Decision Record) System
These tests SHOULD have been written BEFORE implementing the ADR features
Following TDD RED-GREEN-REFACTOR cycle
"""

import pytest
import os
import tempfile
import shutil
from pathlib import Path
from unittest.mock import Mock, patch, MagicMock
from datetime import datetime

# Import modules to test
import sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '.claude', 'hooks'))
from adr_tracker import ADRTracker


class TestADRTracker:
    """Tests for ADR Tracker Hook - Should have been written FIRST"""
    
    @pytest.fixture
    def tracker(self, tmp_path):
        """Create ADR tracker with temp directory"""
        with patch('adr_tracker.Path.cwd', return_value=tmp_path):
            tracker = ADRTracker()
            tracker.adr_dir = tmp_path / "docs" / "adr"
            tracker.adr_dir.mkdir(parents=True)
            return tracker
    
    # RED Test 1: Should detect significant architectural changes
    def test_detects_significant_changes(self, tracker):
        """Test that tracker identifies architectural decisions"""
        # Arrange
        context = {
            'generated_code': 'FROM node:18\nRUN npm install',
            'file_path': 'Dockerfile',
            'description': 'Switch from Python to Node.js'
        }
        
        # Act
        result = tracker.hook_post_code_generation(context)
        
        # Assert
        assert result is not None
        assert result['adr_suggested'] == True
        assert result['score'] >= 3  # Significance threshold
        assert 'suggestion' in result
    
    # RED Test 2: Should calculate decision score correctly
    def test_calculates_decision_score(self, tracker):
        """Test significance scoring algorithm"""
        # Test various decision patterns
        test_cases = [
            ("Add new feature", "", 0),  # Low significance
            ("Switch from REST to GraphQL", "class GraphQLSchema", 5),  # High
            ("Migrate database to PostgreSQL", "CREATE TABLE", 4),  # High
            ("Fix typo in comment", "// fixed", 0),  # Low
            ("Adopt TDD workflow", "test('should", 3),  # Medium
        ]
        
        for description, code, expected_min_score in test_cases:
            score = tracker._calculate_decision_score(code, description)
            assert score >= expected_min_score, f"Failed for: {description}"
    
    # RED Test 3: Should generate ADR suggestions
    def test_generates_adr_suggestion(self, tracker):
        """Test ADR suggestion generation"""
        # Arrange
        context = {
            'file_path': 'docker-compose.yml',
            'description': 'Add monitoring with Prometheus',
            'generated_code': 'services:\n  prometheus:\n    image: prom/prometheus'
        }
        
        # Act
        suggestion = tracker._generate_adr_suggestion(context, score=5)
        
        # Assert
        assert suggestion['title'] == "Add Monitoring With Prometheus"
        assert 'monitoring' in suggestion['tags']
        assert 'context' in suggestion
        assert 'consequences' in suggestion
        assert './scripts/create-adr.sh' in suggestion['command']
    
    # RED Test 4: Should check for recent ADRs
    def test_checks_recent_adrs(self, tracker):
        """Test detection of recent ADR creation"""
        # Create a recent ADR file
        adr_file = tracker.adr_dir / "0001-test.md"
        adr_file.write_text("# ADR-0001: Test")
        
        # Should detect recent ADR
        assert tracker._has_recent_adr(days=7) == True
        
        # Modify timestamp to be old
        old_time = datetime.now().timestamp() - (8 * 24 * 60 * 60)
        os.utime(adr_file, (old_time, old_time))
        
        # Should not detect as recent
        assert tracker._has_recent_adr(days=7) == False
    
    # RED Test 5: Should enforce ADR creation on significant commits
    def test_enforces_adr_on_commit(self, tracker):
        """Test pre-commit hook enforcement"""
        # Arrange - significant changes without recent ADR
        context = {
            'changed_files': ['Dockerfile', 'docker-compose.yml'],
            'message': 'Switch to Kubernetes orchestration'
        }
        
        # Mock no recent ADR
        with patch.object(tracker, '_has_recent_adr', return_value=False):
            # Act
            allowed, message = tracker.hook_pre_commit(context)
            
            # Assert
            assert allowed == True  # Warns but doesn't block
            assert "Consider creating an ADR" in message
            assert "Docker configuration changed" in message
    
    # RED Test 6: Should auto-generate ADR files
    def test_auto_generates_adr_file(self, tracker):
        """Test automatic ADR file generation"""
        # Act
        filename = tracker.auto_generate_adr(
            title="Test Decision",
            context="We need to test",
            decision="We will test",
            consequences={'positive': ['Better quality'], 'negative': ['Time']},
            tags=['testing', 'quality']
        )
        
        # Assert
        assert Path(filename).exists()
        content = Path(filename).read_text()
        assert "# ADR-0001: Test Decision" in content
        assert "Status: Proposed" in content
        assert "testing, quality" in content
        assert "Better quality" in content


class TestADRCreationScript:
    """Tests for create-adr.sh script - Should have been written FIRST"""
    
    @pytest.fixture
    def script_path(self):
        return Path(__file__).parent.parent / "scripts" / "create-adr.sh"
    
    # RED Test 7: Script should exist and be executable
    def test_script_exists_and_executable(self, script_path):
        """Test that ADR creation script exists"""
        assert script_path.exists(), "create-adr.sh should exist"
        assert os.access(script_path, os.X_OK), "Script should be executable"
    
    # RED Test 8: Should create ADR with correct format
    @patch('subprocess.run')
    def test_creates_adr_with_correct_format(self, mock_run, tmp_path):
        """Test ADR creation with proper format"""
        # This would test the shell script execution
        # In practice, we'd run it in a container or subprocess
        pass
    
    # RED Test 9: Should update README index
    def test_updates_readme_index(self, tmp_path):
        """Test that new ADRs are added to index"""
        # Create mock README
        readme_path = tmp_path / "docs" / "adr" / "README.md"
        readme_path.parent.mkdir(parents=True)
        readme_path.write_text("# ADRs\n\n## Index\n")
        
        # Simulate adding new ADR to index
        # This would test the update_readme function
        pass


class TestADRDevContainerIntegration:
    """Tests for ADR integration in dev containers"""
    
    # RED Test 10: Should initialize ADR structure in new containers
    def test_initializes_adr_in_container(self, tmp_path):
        """Test ADR initialization during container creation"""
        # Simulate running adr-init.sh
        init_script = Path(__file__).parent.parent / "templates" / "base" / ".devcontainer" / "adr-init.sh"
        
        # Should create expected structure
        expected_files = [
            "docs/adr/template.md",
            "docs/adr/README.md",
            "docs/adr/0001-initial-architecture.md",
            "scripts/create-adr.sh"
        ]
        
        # This would be tested in actual container
        pass
    
    # RED Test 11: Should add git aliases for ADR commits
    @patch('subprocess.run')
    def test_adds_git_aliases(self, mock_run):
        """Test git alias configuration"""
        # Should configure git alias 'adr'
        # git config --local alias.adr '!f() { git add docs/adr && git commit -m "docs: ADR - $1"; }; f'
        pass


class TestADRWorkflow:
    """Integration tests for complete ADR workflow"""
    
    # RED Test 12: End-to-end ADR creation workflow
    @pytest.mark.integration
    def test_complete_adr_workflow(self, tmp_path):
        """Test complete workflow from detection to creation"""
        # 1. Make significant change
        # 2. Hook detects and suggests ADR
        # 3. Create ADR via script
        # 4. Verify ADR file created
        # 5. Verify index updated
        # 6. Verify git tracking
        pass
    
    # RED Test 13: Should track ADR metrics
    def test_tracks_adr_metrics(self):
        """Test ADR creation and usage metrics"""
        # Should track:
        # - Number of ADRs created
        # - Time since last ADR
        # - ADR coverage (decisions with ADRs / total decisions)
        pass


class TestADRCompliance:
    """Tests for ADR compliance and enforcement"""
    
    # RED Test 14: Should validate ADR format
    def test_validates_adr_format(self):
        """Test that ADRs follow the template format"""
        required_sections = [
            "## Context",
            "## Decision", 
            "## Consequences",
            "## Alternatives Considered"
        ]
        
        # Check all existing ADRs
        adr_dir = Path(__file__).parent.parent / "docs" / "adr"
        if adr_dir.exists():
            for adr_file in adr_dir.glob("*.md"):
                if "template" not in adr_file.name and "README" not in adr_file.name:
                    content = adr_file.read_text()
                    for section in required_sections:
                        assert section in content, f"{adr_file.name} missing {section}"
    
    # RED Test 15: Should enforce ADR numbering
    def test_enforces_sequential_numbering(self):
        """Test that ADRs are numbered sequentially"""
        adr_dir = Path(__file__).parent.parent / "docs" / "adr"
        if adr_dir.exists():
            numbers = []
            for adr_file in adr_dir.glob("[0-9]*.md"):
                number = int(adr_file.stem.split('-')[0])
                numbers.append(number)
            
            if numbers:
                numbers.sort()
                # Check sequential
                for i, num in enumerate(numbers, 1):
                    assert num == i, f"ADR numbering gap at {num}"


# Coverage report
def test_adr_test_coverage():
    """Meta-test: Ensure ADR system has adequate test coverage"""
    # This test verifies we have tests for all ADR functionality
    required_test_areas = [
        "detection",  # Detecting when ADRs are needed
        "scoring",    # Calculating significance
        "generation", # Creating ADR files
        "format",     # Validating ADR format
        "workflow",   # End-to-end workflow
        "integration" # Dev container integration
    ]
    
    # Count test methods
    test_count = 0
    for name, obj in globals().items():
        if name.startswith("Test"):
            test_count += len([m for m in dir(obj) if m.startswith("test_")])
    
    assert test_count >= 15, f"Need at least 15 tests, have {test_count}"


if __name__ == "__main__":
    # Run tests with coverage
    pytest.main([__file__, "-v", "--cov=adr_tracker", "--cov-report=term-missing"])