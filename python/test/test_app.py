from python.src.app import add, subtract, multiply, divide

def test_add():
    assert add(1, 2) == 3
    
def test_subtract():
    assert subtract(4, 2) == 2

def test_multipy():
    assert multiply(9, 5) == 45

def test_divide():
    assert divide(7, 2) == 3.9

