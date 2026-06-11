---
name: pytest
description: Pytest unit tests practices. Use when writing python unit tests
---

# Python unit test: best practices and conventions

This document outlines some of the best practices for writing python unit tests. These are not exhaustive, so you must adhere to other best practices and general modern programming best practices as well.

We use the `pytest` framework.

## Test Structure

### Follow the Arrange-Act-Assert pattern

```python
def test_cart_checkout_calculation():
    # Arrange
    cart = Cart(items=[Item("widget", 100.00), Item("apple", 50.00)])

    # Act
    total = checkout.calculate(cart)

    # Assert
    assert total == 150.00
```

The Act section should generally be one line but may span multiple lines when necessary. Also, do not add `# Arrange`, `# Act`, and `# Assert` comments; the example added them for illustrative purposes.

### Each test must be completely isolated

```python
# WRONG - tests share state that depends on execution order
class TestUser:
    user = None

    def test_create(self):
        self.user = create_user("alice")

    def test_fetch(self):
        assert self.user.name == "alice"  # Fails if test_create didn't run first

# CORRECT - each test is self-contained
class TestUser:
    def test_create(self):
        user = create_user("alice")
        ...

    def test_fetch(self):
        user = create_user("bob")
        ...
```

### Test names must describe the behavior being verified

```python
# WRONG - vague, doesn't describe expected behavior
def test_calculate(): ...
def test_user_1(): ...

# CORRECT - describes scenario and expected outcome
def test_calculate_returns_zero_for_empty_input(): ...
def test_user_creation_fails_with_invalid_email(): ...
```

### Don't add the `@pytest.mark.asyncio` decorator to async tests

If your project has `asyncio_mode = "auto"` configured in pytest, the decorator is redundant and should be omitted.

## Assertions

### Every test must have meaningful value assertions

```python
# WRONG - proves nothing
def test_process():
    result = process(data)
    assert result is not None
    assert isinstance(result, dict)

# CORRECT - verifies actual expected values
def test_process():
    result = process(input=5)
    assert result["status"] == "complete"
```

### Calculate expected values explicitly

```python
# WRONG - unexplained magic number
def test_total():
    cart.add(Item(price=50.00, qty=3))
    assert cart.total == 150

# CORRECT - show derivation
def test_total():
    item_price = 50
    cart.add(Item(price=item_price, qty=3))
    assert cart.total == (item_price * 3)
```

### Verify exception type AND message content

```python
# WEAK - only verifies exception type
def test_validation():
    with pytest.raises(ValueError):
        validate(bad_data)

# STRONG - verifies the specific error
def test_validation():
    with pytest.raises(ValueError, match=r"email.*required"):
        validate({"name": "test"})

# STRONG - for complex exception inspection
def test_api_error():
    with pytest.raises(APIError) as exc_info:
        client.get("/invalid")
    assert exc_info.value.status_code == 404
    assert "not found" in str(exc_info.value).lower()
```

## Fixtures

### Reuse and extend existing fixtures

Before creating a new fixture, check `conftest.py` files for existing fixtures that can be reused or extended.

### Use factory fixtures instead of static fixtures

```python
# WRONG - separate fixture for every variation
@pytest.fixture
def admin_user(): ...
@pytest.fixture
def guest_user(): ...

# CORRECT - factory with sensible defaults
@pytest.fixture
def make_user():
    def _make(name="test", role="user", active=True, **kwargs):
        return User(name=name, role=role, active=active, **kwargs)
    return _make

def test_admin_can_delete(make_user):
    admin = make_user(role="admin")
    target = make_user(role="user")
    assert admin.can_delete(target)
```

### Fixtures must clean up after themselves

```python
@pytest.fixture
def db_session():
    session = create_session()
    yield session
    session.rollback()
    session.close()
```

### Place shared fixtures in conftest.py

Place fixtures in the narrowest applicable fixture scope and test directory scope. When in doubt, prefer the narrower scope.

## Mocking

### Patch at the import location, not the definition location

```python
# WRONG - patches where requests is defined
@patch('requests.get')
def test_fetch(mock_get):
    my_module.fetch_data()  # Still uses real requests!

# CORRECT - patch where the module imports/uses requests
@patch('my_module.requests.get')
def test_fetch(mock_get):
    my_module.fetch_data()
```

### Use autospec=True when mocking

```python
# WRONG - mock accepts any arguments silently
def test_service(mocker):
    mock = mocker.patch('module.service.call')
    mock("wrong", "signature")  # No error raised!

# CORRECT - autospec enforces the real function signature
def test_service(mocker):
    mock = mocker.patch('module.service.call', autospec=True)
    mock("wrong", "signature")  # TypeError if signature doesn't match
```

**When to skip autospec:** mocking objects with `__getattr__`, properties (use `PropertyMock`), or complex class hierarchies that cause issues.

### Prefer `mocker` fixture over `@patch` decorator

The `mocker` fixture comes from `pytest-mock`

```python
# AVOID - decorator ordering is error-prone and implicit
@patch('module.service_b', autospec=True)
@patch('module.service_a', autospec=True)
def test_thing(mock_a, mock_b):
    ...

# PREFER - explicit assignment, no ordering issues
def test_thing(mocker):
    mock_a = mocker.patch('module.service_a', autospec=True)
    mock_b = mocker.patch('module.service_b', autospec=True)
    ...
```

### Only mock at system boundaries

```python
# WRONG - mocking internal helpers tests nothing real
def test_process(mocker):
    mocker.patch('module.helper')
    mocker.patch('module.validator')
    mocker.patch('module.formatter')
    ...
    process(data)  # What is this even testing?
    ...

# CORRECT - mock only external dependencies
def test_process(mocker):
    mock_fetch = mocker.patch('module.external_api.fetch', autospec=True)
    ...
    process(data)
    ...
```

### Configure mock return values and side effects explicitly

```python
def test_retry_on_failure(mocker):
    mock_api = mocker.patch('module.api.call', autospec=True)
    # Fail twice, then succeed
    mock_api.side_effect = [ConnectionError(), ConnectionError(), {"status": "ok"}]

    result = resilient_call()

    assert result == {"status": "ok"}
    assert mock_api.call_count == 3
```

### Verify mock calls with appropriate specificity

```python
# WEAK - only checks the mock was called
mock_api.assert_called_once()

# STRONG - verifies exact arguments
mock_api.assert_called_once_with(to="user@example.com", body="Hello")
```

### Monkeypatch environment variables

```python
def test_config_reads_from_env(monkeypatch):
    monkeypatch.setenv("API_KEY", "test-key-123")
    config = load_config()
    assert config.api_key == "test-key-123"
```

## Parametrization

### Use pytest.param with descriptive IDs

```python
@pytest.mark.parametrize("input_val,expected", [
    pytest.param([], 0, id="empty_list"),
    pytest.param([1], 1, id="single_element"),
    pytest.param([1, 2, 3], 6, id="multiple_elements"),
    pytest.param([-1, 1], 0, id="mixed_signs"),
])
def test_sum(input_val, expected):
    assert sum_values(input_val) == expected
```

### Include reasonable edge cases

```python
@pytest.mark.parametrize("value", [
    pytest.param(None, id="none"),
    pytest.param("", id="empty_string"),
    pytest.param([], id="empty_list"),
    pytest.param({}, id="empty_dict"),
    pytest.param(0, id="zero"),
    pytest.param(-1, id="negative"),
    ...
])
def test_handles_edge_cases(value):
    result = robust_function(value)
    # Assert appropriate behavior for each edge case
```

### Use dataclasses or pydantic for complex test cases

```python
from dataclasses import dataclass

@dataclass
class PricingCase:
    id: str
    base_price: float
    quantity: int
    discount_pct: float

PRICING_CASES = [
    PricingCase(id="no_discount", base_price=10.0, quantity=5, discount_pct=0),
    PricingCase(id="with_discount", base_price=10.0, quantity=5, discount_pct=10),
    PricingCase(id="bulk_discount", base_price=10.0, quantity=100, discount_pct=20),
]

@pytest.mark.parametrize("case", PRICING_CASES, ids=lambda c: c.id)
def test_pricing(case):
    ...
```

## Avoiding Flaky Tests

### Freeze time for time-dependent tests

Use `time_machine` library

### Use pytest.approx for float comparisons

```python
# WRONG - fails due to floating point precision
assert 0.1 + 0.2 == 0.3

# CORRECT
assert 0.1 + 0.2 == pytest.approx(0.3)
```

### Never depend on iteration order (e.g. set order) for assertions

```python
# WRONG - may fail randomly
assert list(result.keys()) == ["a", "b", "c"]

# CORRECT
assert set(result.keys()) == {"a", "b", "c"}
assert result["a"] == expected_a
```

## Anti-Patterns to Avoid

### Never test implementation details

```python
# WRONG - tests HOW not WHAT
def test_user_service():
    service = UserService()
    service._validate = Mock()
    service._save = Mock()
    service.create(data)
    service._validate.assert_called_once()
    service._save.assert_called_once()

# CORRECT - tests observable behavior
def test_user_service():
    service = UserService()
    user = service.create({"email": "a@b.com", "password": "secret"})
    assert user.email == "a@b.com"
    assert user.password != "secret"  # was hashed
```

### Never test private methods directly

```python
# WRONG
def test_internal():
    assert obj._private_method(5) == 10

# CORRECT - test through public interface
def test_public_behavior():
    assert obj.public_method(5) == 10
```

### Never use try/except to test exceptions

```python
# WRONG
def test_error():
    try:
        risky_operation()
        assert False, "Should have raised"
    except ValueError:
        pass

# CORRECT
def test_error():
    with pytest.raises(ValueError, match="specific message"):
        risky_operation()
```

## Pre-Submission Checklist

Before finalizing any test:

1. Does every test have at least one assertion checking a **specific value**?
2. Are mocks patched at the **import location** in the module under test?
3. Do mocks use **autospec=True** (unless there's a documented reason not to)?
4. Is each test **completely independent** of other tests?
5. Are expected values **calculated inline**, not unexplained magic numbers?
6. Do exception tests verify both **type and message**?
7. Do fixtures **clean up** resources after yield?
8. Are reasonable **edge cases** covered?
9. Does the test name describe the **behavior**, not the implementation?
10. Does the test verify **what** the code does, not **how**?
