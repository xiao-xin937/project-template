"""示例测试。"""

import pytest

from src.example import add, divide


def test_add():
    assert add(2, 3) == 5
    assert add(-1, 1) == 0


def test_divide():
    assert divide(10, 4) == 2.5


def test_divide_by_zero_raises():
    with pytest.raises(ZeroDivisionError, match="除数不能为 0"):
        divide(1, 0)
