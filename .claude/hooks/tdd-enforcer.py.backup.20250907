#!/usr/bin/env python3
"""
TDD Enforcer Hook for Claude Code
Ensures test-first development by blocking code generation without tests
"""

import os
import re
import json
import sys
from pathlib import Path
from typing import Dict, List, Tuple, Optional

class TDDEnforcer:
    """Enforces Test-Driven Development practices in Claude Code"""
    
    def __init__(self):
        self.project_root = Path.cwd()
        self.test_patterns = [
            r'test_.*\.py$',
            r'.*\.test\.[jt]sx?$',
            r'.*\.spec\.[jt]sx?$',
            r'.*_test\.go$',
            r'.*Test\.java$'
        ]
        self.implementation_patterns = [
            r'(?<!test_)(?<!spec\.)(?<!test\.).*\.(py|js|ts|jsx|tsx|go|java)$'
        ]
        self.coverage_threshold = 80
        self.test_first_mode = os.getenv('TDD_MODE', 'strict') == 'strict'
        
    def hook_pre_code_generation(self, context: Dict) -> Tuple[bool, str]:
        """
        Hook called before Claude generates code
        Returns (allow, message)
        """
        file_path = context.get('file_path', '')
        code_type = context.get('code_type', 'implementation')
        existing_tests = context.get('existing_tests', [])
        
        # Check if this is implementation code
        if self._is_implementation_file(file_path):
            # In strict mode, require tests first
            if self.test_first_mode:
                if not self._has_corresponding_test(file_path):
                    return (False, 
                           f"❌ TDD Violation: No test found for {file_path}\n"
                           f"Please write a test first:\n"
                           f"  - For Python: test_{Path(file_path).stem}.py\n"
                           f"  - For JS/TS: {Path(file_path).stem}.test.{Path(file_path).suffix}\n"
                           f"  - For Go: {Path(file_path).stem}_test.go")
                
                # Check if tests are failing (RED phase)
                if not self._are_tests_failing(file_path):
                    return (False,
                           f"⚠️ TDD Violation: Tests are passing\n"
                           f"In RED phase, tests must fail first.\n"
                           f"Ensure your test describes new behavior that doesn't exist yet.")
        
        return (True, "✅ TDD check passed")
    
    def hook_post_code_generation(self, context: Dict) -> Dict:
        """
        Hook called after Claude generates code
        Returns metrics and suggestions
        """
        file_path = context.get('file_path', '')
        generated_code = context.get('generated_code', '')
        
        metrics = {
            'has_test': self._has_corresponding_test(file_path),
            'test_coverage': self._estimate_coverage(generated_code),
            'follows_tdd': True,
            'suggestions': []
        }
        
        # Add suggestions based on analysis
        if not metrics['has_test']:
            metrics['suggestions'].append(
                "Write a test for this code to follow TDD practices"
            )
            metrics['follows_tdd'] = False
        
        if metrics['test_coverage'] < self.coverage_threshold:
            metrics['suggestions'].append(
                f"Add more tests to reach {self.coverage_threshold}% coverage"
            )
        
        # Check for untested edge cases
        edge_cases = self._identify_edge_cases(generated_code)
        if edge_cases:
            metrics['suggestions'].append(
                f"Consider testing edge cases: {', '.join(edge_cases)}"
            )
        
        return metrics
    
    def hook_pre_commit(self, context: Dict) -> Tuple[bool, str]:
        """
        Hook called before committing code
        Ensures all code has tests
        """
        changed_files = context.get('changed_files', [])
        implementation_files = [f for f in changed_files if self._is_implementation_file(f)]
        
        missing_tests = []
        for impl_file in implementation_files:
            if not self._has_corresponding_test(impl_file):
                missing_tests.append(impl_file)
        
        if missing_tests:
            return (False,
                   f"❌ Commit blocked: Missing tests for:\n" +
                   "\n".join(f"  - {f}" for f in missing_tests) +
                   f"\n\nPlease add tests before committing.")
        
        # Check coverage
        coverage = self._get_project_coverage()
        if coverage < self.coverage_threshold:
            return (False,
                   f"❌ Commit blocked: Coverage {coverage}% is below threshold {self.coverage_threshold}%\n"
                   f"Run: npm test -- --coverage")
        
        return (True, f"✅ All files have tests. Coverage: {coverage}%")
    
    def hook_test_suggestion(self, context: Dict) -> List[str]:
        """
        Hook that suggests tests based on code
        """
        code = context.get('code', '')
        language = context.get('language', 'javascript')
        
        suggestions = []
        
        if language in ['javascript', 'typescript']:
            suggestions.extend(self._suggest_js_tests(code))
        elif language == 'python':
            suggestions.extend(self._suggest_python_tests(code))
        
        return suggestions
    
    def _is_implementation_file(self, file_path: str) -> bool:
        """Check if file is implementation (not test) code"""
        for pattern in self.test_patterns:
            if re.match(pattern, file_path):
                return False
        
        for pattern in self.implementation_patterns:
            if re.match(pattern, file_path):
                return True
        
        return False
    
    def _has_corresponding_test(self, file_path: str) -> bool:
        """Check if implementation file has a corresponding test file"""
        path = Path(file_path)
        stem = path.stem
        suffix = path.suffix
        
        # Common test file patterns
        test_variants = [
            path.parent / f"test_{stem}.py",
            path.parent / f"{stem}_test.py",
            path.parent / f"{stem}.test{suffix}",
            path.parent / f"{stem}.spec{suffix}",
            path.parent / f"{stem}_test.go",
            path.parent / f"{stem}Test.java",
            path.parent / "__tests__" / f"{stem}.test{suffix}",
            path.parent / "tests" / f"test_{stem}.py",
            path.parent.parent / "tests" / path.parent.name / f"test_{stem}.py"
        ]
        
        return any(variant.exists() for variant in test_variants)
    
    def _are_tests_failing(self, file_path: str) -> bool:
        """Check if tests for a file are currently failing (RED phase)"""
        # This would run the actual test
        # For now, check if implementation exists
        impl_path = Path(file_path)
        
        # If implementation doesn't exist or is empty, tests should fail
        if not impl_path.exists() or impl_path.stat().st_size == 0:
            return True
        
        # Check for TODO or NotImplemented markers
        if impl_path.exists():
            content = impl_path.read_text()
            if 'TODO' in content or 'NotImplemented' in content or 'pass' in content:
                return True
        
        return False
    
    def _estimate_coverage(self, code: str) -> float:
        """Estimate test coverage based on code analysis"""
        if not code:
            return 100.0
        
        # Count testable elements
        testable_elements = 0
        tested_elements = 0
        
        # Check for functions/methods
        function_matches = re.findall(r'(def |function |func |public \w+ )', code)
        testable_elements += len(function_matches)
        
        # Check for conditionals
        conditional_matches = re.findall(r'(if |else if |switch |case )', code)
        testable_elements += len(conditional_matches)
        
        # Check for error handling
        error_matches = re.findall(r'(try |catch |except |raise |throw )', code)
        testable_elements += len(error_matches)
        
        # Estimate based on heuristics (would need actual test running)
        if testable_elements == 0:
            return 100.0
        
        # Assume 70% coverage as baseline for new code
        return min(70.0, (tested_elements / testable_elements) * 100)
    
    def _identify_edge_cases(self, code: str) -> List[str]:
        """Identify potential edge cases that need testing"""
        edge_cases = []
        
        # Check for array/list operations
        if 'length' in code or 'len(' in code or '.size' in code:
            edge_cases.append("empty collections")
        
        # Check for null/undefined handling
        if 'null' in code or 'undefined' in code or 'None' in code:
            edge_cases.append("null/undefined values")
        
        # Check for numeric operations
        if any(op in code for op in ['+', '-', '*', '/', '%']):
            edge_cases.append("zero/negative numbers")
        
        # Check for string operations
        if 'substring' in code or 'slice' in code or 'split' in code:
            edge_cases.append("empty strings")
        
        # Check for async operations
        if 'async' in code or 'await' in code or 'Promise' in code:
            edge_cases.append("async errors/timeouts")
        
        return edge_cases
    
    def _get_project_coverage(self) -> float:
        """Get current project test coverage"""
        coverage_file = self.project_root / "coverage" / "coverage-summary.json"
        
        if coverage_file.exists():
            with open(coverage_file) as f:
                data = json.load(f)
                return data.get('total', {}).get('lines', {}).get('pct', 0)
        
        # Try to run coverage command
        import subprocess
        try:
            result = subprocess.run(
                ["npm", "run", "test:coverage", "--", "--silent"],
                capture_output=True,
                text=True,
                timeout=30
            )
            # Parse coverage from output
            for line in result.stdout.split('\n'):
                if 'All files' in line or 'TOTAL' in line:
                    # Extract percentage
                    match = re.search(r'(\d+\.?\d*)%', line)
                    if match:
                        return float(match.group(1))
        except:
            pass
        
        return 0.0
    
    def _suggest_js_tests(self, code: str) -> List[str]:
        """Suggest JavaScript/TypeScript tests"""
        suggestions = []
        
        # Find function names
        functions = re.findall(r'(?:function|const|let|var)\s+(\w+)\s*(?:=\s*)?(?:\([^)]*\)|async)', code)
        
        for func in functions:
            suggestions.append(f"""
test('should {func} correctly', () => {{
    // Arrange
    const input = // setup test data
    
    // Act
    const result = {func}(input);
    
    // Assert
    expect(result).toBe(expected);
}});""")
        
        return suggestions
    
    def _suggest_python_tests(self, code: str) -> List[str]:
        """Suggest Python tests"""
        suggestions = []
        
        # Find function/method names
        functions = re.findall(r'def\s+(\w+)\s*\([^)]*\):', code)
        
        for func in functions:
            suggestions.append(f"""
def test_{func}():
    # Arrange
    input_data = # setup test data
    
    # Act
    result = {func}(input_data)
    
    # Assert
    assert result == expected""")
        
        return suggestions


# Hook registration for Claude Code
def register_hooks():
    """Register TDD hooks with Claude Code"""
    enforcer = TDDEnforcer()
    
    return {
        'pre_code_generation': enforcer.hook_pre_code_generation,
        'post_code_generation': enforcer.hook_post_code_generation,
        'pre_commit': enforcer.hook_pre_commit,
        'test_suggestion': enforcer.hook_test_suggestion
    }


if __name__ == "__main__":
    # CLI interface for testing
    import argparse
    
    parser = argparse.ArgumentParser(description='TDD Enforcer for Claude Code')
    parser.add_argument('command', choices=['check', 'suggest', 'coverage'])
    parser.add_argument('file', nargs='?', help='File to check')
    parser.add_argument('--strict', action='store_true', help='Enable strict TDD mode')
    
    args = parser.parse_args()
    
    enforcer = TDDEnforcer()
    
    if args.command == 'check':
        if args.file:
            has_test = enforcer._has_corresponding_test(args.file)
            print(f"{'✅' if has_test else '❌'} {args.file} {'has' if has_test else 'needs'} test")
    
    elif args.command == 'coverage':
        coverage = enforcer._get_project_coverage()
        print(f"Project coverage: {coverage}%")
        
    elif args.command == 'suggest':
        if args.file:
            with open(args.file) as f:
                code = f.read()
            suggestions = enforcer._suggest_js_tests(code) if args.file.endswith(('.js', '.ts')) else enforcer._suggest_python_tests(code)
            for suggestion in suggestions:
                print(suggestion)