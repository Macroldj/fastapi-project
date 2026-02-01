import pytest
from app.jobs.calculator import (
    add,
    subtract,
    multiply,
    divide,
    slow_calculation,
    database_integration,
)

# ------------- 单独的测试函数（符合test_*规则）-------------
def test_add_basic():
    """测试加法基础场景"""
    assert add(1, 2) == 3  # 核心断言：验证结果符合预期
    assert add(-1, 1) == 0
    assert add(0.5, 0.3) == 0.8

def test_subtract_basic():
    """测试减法基础场景"""
    assert subtract(5, 3) == 2
    assert subtract(2, 5) == -3

# ------------- 测试类（符合Test*规则，类内方法符合test_*规则）-------------
class TestCalculator:
    """计算器测试类（多个相关测试用例聚合）"""
    def test_multiply_basic(self):
        """测试乘法基础场景"""
        assert multiply(4, 5) == 20
        assert multiply(0, 100) == 0

    def test_divide_normal(self):
        """测试除法正常场景"""
        assert divide(10, 2) == 5
        assert divide(7, 2) == 3.5

    def test_divide_by_zero(self):
        """测试除法除零异常（核心：捕获预期异常）"""
        # pytest.raises 捕获指定异常，验证异常类型和描述
        with pytest.raises(ZeroDivisionError, match="除数不能为0"):
            divide(10, 0)

# ------------- 带标记的测试用例（适配配置中的markers）-------------
@pytest.mark.slow  # 标记为慢测试（符合配置中的slow: marks tests as slow）
def test_slow_calculation():
    """测试慢执行函数，带slow标记"""
    assert slow_calculation(100) == 4950  # sum(0-99)=4950

@pytest.mark.integration  # 标记为集成测试（符合integration标记定义）
def test_database_integration():
    """测试集成场景，带integration标记"""
    assert database_integration() is True  # 验证集成调用成功

# ------------- 组合标记：一个用例可带多个标记 -------------
@pytest.mark.slow
@pytest.mark.integration
def test_slow_integration():
    """模拟既慢又属于集成的测试用例"""
    assert slow_calculation(50) + 1 == 1226  # sum(0-49)=1225 +1=1226