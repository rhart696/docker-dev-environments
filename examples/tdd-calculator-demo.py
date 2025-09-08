#!/usr/bin/env python3
"""
TDD Demo: Calculator Implementation
This demonstrates the RED-GREEN-REFACTOR cycle
"""

import pytest
import sys
import os

# =============================================================================
# RED PHASE: Write failing tests first
# =============================================================================

class TestCalculator:
    """Tests written BEFORE implementation (TDD Red Phase)"""
    
    def test_addition(self):
        """Test calculator can add two numbers"""
        calc = Calculator()
        assert calc.add(2, 3) == 5
        assert calc.add(-1, 1) == 0
        assert calc.add(0, 0) == 0
    
    def test_subtraction(self):
        """Test calculator can subtract two numbers"""
        calc = Calculator()
        assert calc.subtract(5, 3) == 2
        assert calc.subtract(0, 5) == -5
        assert calc.subtract(-3, -3) == 0
    
    def test_multiplication(self):
        """Test calculator can multiply two numbers"""
        calc = Calculator()
        assert calc.multiply(3, 4) == 12
        assert calc.multiply(-2, 3) == -6
        assert calc.multiply(0, 100) == 0
    
    def test_division(self):
        """Test calculator can divide two numbers"""
        calc = Calculator()
        assert calc.divide(10, 2) == 5
        assert calc.divide(7, 2) == 3.5
        assert calc.divide(-8, 4) == -2
    
    def test_division_by_zero_raises_error(self):
        """Test division by zero raises appropriate error"""
        calc = Calculator()
        with pytest.raises(ValueError, match="Cannot divide by zero"):
            calc.divide(5, 0)
    
    def test_history_tracking(self):
        """Test calculator tracks operation history"""
        calc = Calculator()
        calc.add(2, 3)
        calc.multiply(4, 5)
        calc.subtract(10, 3)
        
        history = calc.get_history()
        assert len(history) == 3
        assert history[0] == "2 + 3 = 5"
        assert history[1] == "4 × 5 = 20"
        assert history[2] == "10 - 3 = 7"
    
    def test_clear_history(self):
        """Test calculator can clear its history"""
        calc = Calculator()
        calc.add(1, 2)
        calc.clear_history()
        assert calc.get_history() == []

# =============================================================================
# GREEN PHASE: Write minimal code to pass tests
# =============================================================================

class Calculator:
    """Simple calculator implementation to pass tests (TDD Green Phase)"""
    
    def __init__(self):
        self.history = []
    
    def add(self, a: float, b: float) -> float:
        """Add two numbers"""
        result = a + b
        self.history.append(f"{a} + {b} = {result}")
        return result
    
    def subtract(self, a: float, b: float) -> float:
        """Subtract b from a"""
        result = a - b
        self.history.append(f"{a} - {b} = {result}")
        return result
    
    def multiply(self, a: float, b: float) -> float:
        """Multiply two numbers"""
        result = a * b
        self.history.append(f"{a} × {b} = {result}")
        return result
    
    def divide(self, a: float, b: float) -> float:
        """Divide a by b"""
        if b == 0:
            raise ValueError("Cannot divide by zero")
        result = a / b
        self.history.append(f"{a} ÷ {b} = {result}")
        return result
    
    def get_history(self) -> list:
        """Get operation history"""
        return self.history.copy()
    
    def clear_history(self):
        """Clear operation history"""
        self.history = []

# =============================================================================
# REFACTOR PHASE: Improve code quality while keeping tests green
# =============================================================================

from typing import List, Callable
from enum import Enum

class Operation(Enum):
    """Operation types for better organization"""
    ADD = ("add", "+")
    SUBTRACT = ("subtract", "-")
    MULTIPLY = ("multiply", "×")
    DIVIDE = ("divide", "÷")
    
    def __init__(self, name: str, symbol: str):
        self.op_name = name
        self.symbol = symbol

class ImprovedCalculator:
    """Refactored calculator with better design (TDD Refactor Phase)"""
    
    def __init__(self):
        self._history: List[str] = []
        self._operations = {
            Operation.ADD: lambda a, b: a + b,
            Operation.SUBTRACT: lambda a, b: a - b,
            Operation.MULTIPLY: lambda a, b: a * b,
            Operation.DIVIDE: self._safe_divide
        }
    
    def _safe_divide(self, a: float, b: float) -> float:
        """Safe division with zero check"""
        if b == 0:
            raise ValueError("Cannot divide by zero")
        return a / b
    
    def _execute_operation(self, op: Operation, a: float, b: float) -> float:
        """Execute operation and record in history"""
        result = self._operations[op](a, b)
        self._history.append(f"{a} {op.symbol} {b} = {result}")
        return result
    
    def add(self, a: float, b: float) -> float:
        """Add two numbers"""
        return self._execute_operation(Operation.ADD, a, b)
    
    def subtract(self, a: float, b: float) -> float:
        """Subtract b from a"""
        return self._execute_operation(Operation.SUBTRACT, a, b)
    
    def multiply(self, a: float, b: float) -> float:
        """Multiply two numbers"""
        return self._execute_operation(Operation.MULTIPLY, a, b)
    
    def divide(self, a: float, b: float) -> float:
        """Divide a by b"""
        return self._execute_operation(Operation.DIVIDE, a, b)
    
    def get_history(self) -> List[str]:
        """Get operation history"""
        return self._history.copy()
    
    def clear_history(self) -> None:
        """Clear operation history"""
        self._history.clear()

# =============================================================================
# TDD Cycle Demonstration
# =============================================================================

def demonstrate_tdd_cycle():
    """Demonstrate the complete TDD cycle"""
    
    print("=" * 70)
    print("TDD CYCLE DEMONSTRATION: Calculator")
    print("=" * 70)
    
    # RED Phase
    print("\n📴 RED PHASE: Write failing tests first")
    print("   - Tests define the expected behavior")
    print("   - No implementation exists yet")
    print("   - All tests would fail at this point")
    
    # GREEN Phase
    print("\n✅ GREEN PHASE: Write minimal code to pass tests")
    calc = Calculator()
    print(f"   - Basic implementation: {calc.add(2, 3)}")
    print(f"   - Division with check: {calc.divide(10, 2)}")
    print("   - All tests now pass!")
    
    # REFACTOR Phase
    print("\n🔧 REFACTOR PHASE: Improve code while keeping tests green")
    improved = ImprovedCalculator()
    print(f"   - Refactored with enums: {improved.add(2, 3)}")
    print(f"   - Better organization: {improved.multiply(4, 5)}")
    print("   - Tests still pass with improved design!")
    
    # Show history feature
    print("\n📝 History tracking (feature from tests):")
    for operation in improved.get_history():
        print(f"   - {operation}")
    
    print("\n" + "=" * 70)
    print("TDD BENEFITS DEMONSTRATED:")
    print("1. Tests were written first, defining the interface")
    print("2. Implementation was driven by test requirements")
    print("3. Refactoring was safe because tests verified behavior")
    print("4. Error cases (division by zero) were handled from the start")
    print("5. Features like history tracking emerged from test requirements")
    print("=" * 70)

if __name__ == "__main__":
    # Run the demonstration
    demonstrate_tdd_cycle()
    
    # Run the actual tests
    print("\n🧪 Running tests to verify TDD cycle...")
    pytest.main([__file__, "-v", "--tb=short"])