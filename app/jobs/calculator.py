def add(a: int | float, b: int | float) -> int | float:
    """加法运算"""
    return a + b

def subtract(a: int | float, b: int | float) -> int | float:
    """减法运算"""
    return a - b

def multiply(a: int | float, b: int | float) -> int | float:
    """乘法运算"""
    return a * b

def divide(a: int | float, b: int | float) -> int | float:
    """除法运算，除零抛出异常"""
    if b == 0:
        raise ZeroDivisionError("除数不能为0")
    return a / b

def slow_calculation(n: int) -> int:
    """模拟慢执行函数（适配@pytest.mark.slow标记）"""
    import time
    time.sleep(1)  # 休眠1秒，模拟耗时操作
    return sum(range(n))

def database_integration() -> bool:
    """模拟集成测试（适配@pytest.mark.integration标记），模拟数据库连接"""
    # 实际场景可替换为真实的数据库/第三方服务调用
    return True  # 模拟集成调用成功