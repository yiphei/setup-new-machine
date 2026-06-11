---
name: python-type-annotation
description: Python type annotation practices. Use when writing python type annotations
---

# Python Type Annotation: best practices and conventions

This document outlines some of the best practices for python type annotations. These are not exhaustive, so you must adhere to other best practices and general modern programming best practices as well.

We use python 3.14 and `basedpyright` in strict mode.

## Modern Syntax (Python 3.12+)

### Use PEP 695 type parameter syntax

#### Generic class
```python
# Wrong
from typing import TypeVar, Generic
T = TypeVar("T")
class Box(Generic[T]): ...

# Correct
class Box[T]: ...
```

**Exceptions for using the old Generic syntax** 

They can include:
- PEP 695 syntax doesn't support explicit variance declarations. When you need covariant or contravariant type parameters, use the old `TypeVar` + `Generic` syntax. If any type parameter requires explicit variance, all type parameters for that class must use the old syntax. 
- You need to reuse the same type var definition in multiple places

When using the old syntax, suppress ruff's UP046 and RUF100 warning with `# noqa: UP046, RUF100`.

```python
# Wrong — T_co is invariant
class Box[T_co: (str | int)]: ...

# Correct
from typing import TypeVar, Generic
T_co = TypeVar("T_co", bound= str | int, covariant=True)
class Box(Generic[T_co]): ...  # noqa: UP046, RUF100
```

#### Type alias
```python
# Wrong
from typing import TypeAlias
StrOrInt: TypeAlias = str | int

# Correct
type StrOrInt = str | int
```

#### Generic function

```python
# Wrong
from typing import TypeVar
T = TypeVar("T")
def first(items: list[T]) -> T: ...

# Correct
def first[T](items: list[T]) -> T: ...
```

### Use `Self` and `type[Self]` for self-returning methods

```python
# Wrong
class Builder:
    def set_name(self, name: str) -> Builder: ...

# Correct
from typing import Self
class Builder:
    def set_name(self, name: str) -> Self: ...

# Wrong
class BaseModel:
    @classmethod
    def get_model_class(cls) -> type[BaseModel]: ...

# Correct
from typing import Self

class BaseModel:
    @classmethod
    def get_model_class(cls) -> type[Self]: ...

class UserModel(BaseModel): ...

model_cls = UserModel.get_model_class()  # Correctly inferred as type[UserModel]
```

### Use TypeIs over TypeGuard

```python
# Wrong — else branch stays int | str
from typing import TypeGuard
def is_str(x: object) -> TypeGuard[str]: ...

# Correct — else branch narrows to int
from typing import TypeIs
def is_str(x: object) -> TypeIs[str]: ...
```

Use `TypeGuard` only when narrowing to a non-subtype of input.

### Use Never for functions that never return

```python
from typing import Never

# Wrong
def fail(message: str) -> None:
    raise RuntimeError(message)

# Wrong — uses old convention
def fail(message: str) -> NoReturn:
    raise RuntimeError(message)

# Correct
def fail(message: str) -> Never:
    raise RuntimeError(message)
```

## Container and Callable Types

### Import from collections.abc, not typing

```python
# Wrong — deprecated in 3.9+
from typing import Callable, Iterable, Mapping

# Correct
from collections.abc import Callable, Iterable, Mapping
```

Exception: `typing.TypedDict`, `typing.Protocol`, `typing.NamedTuple` stay in typing.

### Accept wide, return narrow

```python
# Avoid — rejects tuples, generators
def process(items: list[str]) -> list[str]: ...

# Prefer
from collections.abc import Iterable
def process(items: Iterable[str]) -> list[str]: ...
```

### Use read-only types for covariant parameters

```python
# Wrong — list[Dog] incompatible with list[Animal]
def feed(animals: list[Animal]) -> None: ...

# Correct — Sequence[Dog] compatible with Sequence[Animal]
from collections.abc import Sequence
def feed(animals: Sequence[Animal]) -> None: ...
```

### Use ParamSpec for decorators that preserve signatures

```python
from collections.abc import Callable
from functools import wraps

def logged[T, **P](func: Callable[P, T]) -> Callable[P, T]:
    @wraps(func)
    def wrapper(*args: P.args, **kwargs: P.kwargs) -> T:
        print(f"Calling {func.__name__}")
        return func(*args, **kwargs)
    return wrapper

@logged
def greet(name: str, excited: bool = False) -> str: ...
# greet retains its original signature for callers
```

Use `Concatenate[X, P]` when adding parameters

### Use overloads judiciously

Use `@overload` when return type depends on input type or value. Avoid it when a union return type suffices.

## Type Inference and Annotations

### Use Literal and Final

When applicable, prefer using Literal and Final

### Always annotate empty containers

```python
# Wrong
items = []

# Correct
items: list[str] = []
```

### Don't over-annotate obvious types

```python
# Wrong
x: int = 1
items: list[str] = ["hello"]

# Correct — let pyright infer
x = 1
items = ["hello"]
```

### Always specify generic type arguments

```python
# Wrong
def get_items() -> list: ...

# Correct
def get_items() -> list[int]: ...
```

### Use ClassVar for class-level attributes

```python
from typing import ClassVar
class Connection:
    pool_size: ClassVar[int] = 10  # Class attribute
    host: str  # Instance attribute
```

### Annotate *args and **kwargs correctly

```python
# Wrong
def log(*args, **kwargs) -> None: ...

# Correct – all positional args are str, all keyword args are int
def log(*args: str, **kwargs: int) -> None: ...

# For heterogeneous signatures, use ParamSpec or Unpack[TypedDict]
```

## Any and object

`Any` and `object` are escape hatches, so avoid them. Prefer precise types.

### When to use object

Use `object` when you accept any type but only use universal methods (`__str__`, `__eq__`, etc.):

```python
def log_value(value: object) -> None:
    print(f"Value: {value}")  # __str__ is on object

def is_none(value: object) -> TypeIs[None]:
    return value is None

def handle(value: object) -> str:
    if isinstance(value, str):
        return value.upper()  # Narrowed to str
    return str(value)
```

### When to use Any (rarely)

Reserve `Any` ONLY for:
- Wrapping untyped third-party code
- Truly dynamic runtime behavior (json.loads, etc.)

### Prefer these alternatives to Any/object

Use generics to preserve type information

```python
# Wrong
def first(items: list[Any]) -> Any: ...

# Correct
def first[T](items: list[T]) -> T: ...
```

Use Protocol for structural typing

```python
# Wrong
def serialize(obj: Any) -> str:
    return obj.to_json()

# Correct
class JsonSerializable(Protocol):
    def to_json(self) -> str: ...

def serialize(obj: JsonSerializable) -> str:
    return obj.to_json()
```

## Other

### How to deal with reportMissingTypeArgument error

When you have a generic class and pyright reports `reportMissingTypeArgument`, evaluate if it can be resolved at the generic class definition level

#### Create a union type alias

Create an explicit union of all valid type instantiations. Define this alias in the same module as the generic class, not at usage sites.

```python
class Container[T: (int, str)]: ...

# Before
def foo(x: Container): ...  # reportMissingTypeArgument

# After
type AnyContainer = Container[str] | Container[int] # define this in the same module of Container, not of foo

def foo(x: AnyContainer): ...  # no type errors
```

If there are multiple type parameters with many combinations, union together only the concrete instantiations that actually exist in the codebase:

```python
class Container[T: (str, int), AnotherT: (str, int)]: ...

# Only these combinations exist in the codebase
class TypeAContainer(Container[str, int]): ...
class TypeBContainer(Container[int, str]): ...

type AnyContainer = TypeAContainer | TypeBContainer

def foo(x: AnyContainer): ...  # no type errors
```

#### Add a default type for the generic type parameter

Only do this if there is a sensible default. When in doubt, DO NOT do this because most type parameters don't have a sensible default.

```python
# Before
class Container[T: (int, str)]: ...

def foo(x: Container): ...  # reportMissingTypeArgument

# After
class Container[T: (int, str) = int]: ...

def foo(x: Container): ...  # no type errors
```

### Consider making type param variant when reportArgumentType

If an issue stems from type invariance (e.g., `Container[int]` not assignable to `Container[int | str]`), evaluate if it can be resolved by making the type param variant. Only do this if variance (covariance or contravariance) actually makes semantic and business logic sense. Don't do this just to suppress pyright

```python
# Before
class Container[T: int | str = int | str]: ...

class SubContainer(Container[int]): ...

def foo(x: Container): ...

sub_c = SubContainer()
foo(sub_c)  # reportArgumentType

# After
T_co = TypeVar("T_co", bound=int | str, covariant=True, default=int | str)
class Container(Generic[T_co]): ...  # noqa: UP046, RUF100

class SubContainer(Container[int]): ...

def foo(x: Container): ...

sub_c = SubContainer()
foo(sub_c)  # no error
```

### Use TYPE_CHECKING for import cycles

```python
from typing import TYPE_CHECKING
if TYPE_CHECKING:
    from .other_module import OtherClass

class MyClass:
    def method(self, other: OtherClass) -> None: ...
```

### Avoid type or pyright ignores

Avoid type or pyright ignores, but if you really can't solve a type error, use specific pyright ignores

```python
# Wrong
x = call()  # type: ignore

# Correct
x = call()  # pyright: ignore[reportUnknownMemberType]
```

### Avoid unnecessary cast()

`cast()` bypasses type checking. Prefer runtime narrowing.

```python
from typing import cast

# Avoid — hides potential bugs
user = cast(User, data["user"])

# Prefer — runtime check + type narrowing
if isinstance(data["user"], User):
    user = data["user"]
```

### Forward references are handled automatically

Python 3.14 (PEP 649) defers evaluation of annotations, so forward references work without any special syntax:

```python
class Department:
    manager: Employee | None = None  # Employee defined below

class Employee:
    department: Department
```

No `from __future__ import annotations` or string quoting is needed.

### Use assert_never for exhaustive type checking

Use `assert_never` to ensure exhaustive handling of enums, unions, and literal types.

```python
from typing import assert_never
from enum import Enum

class Status(Enum):
    PENDING = "pending"
    APPROVED = "approved"

def handle_status(status: Status) -> str:
    if status is Status.PENDING:
        return "Waiting..."
    elif status is Status.APPROVED:
        return "Good to go!"
    else:
        assert_never(status)  # Type checker proves this is unreachable
```
