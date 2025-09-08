import pytest
import sys
import os
from pathlib import Path
from unittest.mock import Mock, patch, MagicMock

# Add hooks directory to path
sys.path.insert(0, str(Path(__file__).parent.parent / '.claude' / 'hooks'))

from tdd_enforcer_enhanced import ResilientTDDEnforcer

class TestResilientTDDEnforcer:
    """Test suite for enhanced TDD enforcer"""
    
    def setup_method(self):
        """Set up test environment"""
        self.enforcer = ResilientTDDEnforcer()
        
    def test_safe_hook_execution_handles_errors(self):
        """Verify hooks don't crash on errors"""
        def failing_hook(context):
            raise Exception("Test error")
            
        result = self.enforcer.safe_hook_execution(failing_hook, {})
        
        assert result[0] == True  # Should return permissive result
        assert "skipped due to error" in result[1]
        
    def test_fallback_test_detection(self):
        """Test multiple fallback strategies"""
        with patch.object(self.enforcer, '_check_test_files', return_value=False):
            with patch.object(self.enforcer, '_check_git_history', return_value=True):
                result = self.enforcer._has_test_with_fallbacks('test.py')
                assert result == True
                
    def test_coverage_fallback_strategies(self):
        """Test coverage calculation fallbacks"""
        with patch.object(self.enforcer, '_try_npm_coverage', return_value=None):
            with patch.object(self.enforcer, '_try_python_coverage', return_value=75.5):
                coverage = self.enforcer.get_coverage_with_fallback(Path.cwd())
                assert coverage == 75.5
                
    def test_language_detection(self):
        """Test programming language detection"""
        assert self.enforcer._detect_language('test.py') == 'python'
        assert self.enforcer._detect_language('test.js') == 'javascript'
        assert self.enforcer._detect_language('test.ts') == 'typescript'
        assert self.enforcer._detect_language('test.go') == 'go'
        assert self.enforcer._detect_language('test.rs') == 'rust'
        
    def test_caching_performance(self):
        """Verify caching improves performance"""
        import time
        
        file_hash = "test_hash"
        
        # First call should be slower
        start = time.time()
        self.enforcer._has_corresponding_test_cached("test.py", file_hash)
        first_call = time.time() - start
        
        # Second call should be faster (cached)
        start = time.time()
        self.enforcer._has_corresponding_test_cached("test.py", file_hash)
        second_call = time.time() - start
        
        assert second_call < first_call
        
    def test_performance_under_100ms(self):
        """Ensure hook execution stays under 100ms"""
        import time
        
        def sample_hook(context):
            return (True, "Success")
            
        start = time.time()
        result = self.enforcer.safe_hook_execution(sample_hook, {})
        elapsed = time.time() - start
        
        assert elapsed < 0.1  # 100ms threshold
        
    @pytest.mark.parametrize("file_path,expected", [
        ("src/calculator.py", ["test_calculator.py", "calculator_test.py"]),
        ("lib/parser.js", ["parser.test.js", "parser.spec.js"]),
        ("cmd/main.go", ["main_test.go"]),
    ])
    def test_test_pattern_generation(self, file_path, expected):
        """Test generation of test file patterns"""
        path = Path(file_path)
        language = self.enforcer._detect_language(file_path)
        patterns = self.enforcer._get_test_patterns(path, language)
        
        pattern_names = [p.name for p in patterns]
        for exp in expected:
            assert any(exp in name for name in pattern_names)

if __name__ == "__main__":
    pytest.main([__file__, "-v"])
