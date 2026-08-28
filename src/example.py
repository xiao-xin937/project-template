"""示例模块，用于验证 CI 流水线可以跑通。开始写真实代码后可以删掉。"""


def add(a: int, b: int) -> int:
    """返回两个整数之和。"""
    return a + b


def divide(a: float, b: float) -> float:
    """返回 a 除以 b。

    Raises:
        ZeroDivisionError: 当 b 为 0 时。
    """
    if b == 0:
        raise ZeroDivisionError("除数不能为 0")
    return a / b
