# Library Authoring

Use this file when creating Python libraries or extending Robot Framework.

Source basis: Robot Framework User Guide sections on creating test libraries,
remote libraries, listeners, dynamic/hybrid APIs, and Libdoc.

## When To Write A Python Library

Write a library when you need:

- external API or system interaction
- non-trivial data transformation
- logic that would make `.robot` files hard to read
- reusable low-level operations across many suites

Do not write a library just to wrap two or three readable keywords.

The goal is to make suites simpler, not to move all test logic into Python.

## Minimal Python Library

```python
class ExampleLibrary:
    def open_record(self, record_id: str):
        # Implementation detail hidden from .robot suite.
        return {"id": record_id, "status": "open"}

    def record_status_should_be(self, record: dict, expected: str):
        actual = record["status"]
        if actual != expected:
            raise AssertionError(
                f"Expected status {expected!r} but got {actual!r}"
            )
```

Used from Robot Framework:

```robot
*** Settings ***
Library    ExampleLibrary.py

*** Test Cases ***
Record Opens As Expected
    ${record}=    Open Record    123
    Record Status Should Be    ${record}    open
```

## Better Real-World Shape

```python
class UserApiLibrary:
    def create_user(self, username: str, role: str = "member") -> dict:
        response = self._client.post("/users", json={"username": username, "role": role})
        response.raise_for_status()
        return response.json()

    def user_role_should_be(self, user: dict, expected: str):
        actual = user["role"]
        if actual != expected:
            raise AssertionError(
                f"Expected role {expected!r} but got {actual!r}"
            )
```

This keeps transport mechanics in Python while Robot suites speak in domain
language.

## Library Scope

Control instance lifecycle with `ROBOT_LIBRARY_SCOPE`:

```python
class SessionLibrary:
    ROBOT_LIBRARY_SCOPE = 'SUITE'  # new instance per suite file
```

| Scope | Instance lifecycle | Use when |
|---|---|---|
| `GLOBAL` | one instance for entire run | stateless utilities |
| `SUITE` | one instance per suite file | suite-scoped connections or state |
| `TEST` | one instance per test case | test-isolated state |

Default is `GLOBAL`.

## Keyword Decorator API

Use `robot.api.deco` for explicit keyword registration and embedded arguments:

```python
from robot.api.deco import keyword, library

@library(scope='SUITE', auto_keywords=False)
class MyLibrary:

    @keyword('Open page "${url}"')
    def open_page(self, url: str):
        """Open page with embedded argument."""
        pass

    @keyword(tags=['setup'])
    def initialize(self):
        pass
```

`auto_keywords=False` prevents all public methods from becoming keywords.
Only decorated methods are exposed. Use this for precision.

## Type Conversion

Robot Framework auto-converts string arguments when Python type hints are
present:

```python
def set_count(self, count: int):       # "42" → 42
def set_flag(self, flag: bool):        # "True"/"Yes"/"On"/"1" → True
def add_items(self, items: list):      # @{var} → list
def configure(self, opts: dict):       # &{var} → dict
```

Boolean conversion is case-insensitive. Recognized true: `True`, `Yes`, `On`,
`1`. Recognized false: `False`, `No`, `Off`, `0`, empty string.

Union types work: `Union[int, str]` tries int first, falls back to str.

For custom types, implement `__init__(self, value: str)` or register a
converter.

## Design Rules

- keep keyword names action-oriented
- raise clear assertion or runtime errors
- keep library APIs stable even if implementation changes
- return Robot-friendly data shapes
- avoid leaking unnecessary implementation detail into suite code
- prefer small composable keywords over giant "do everything" methods
- keep hidden retries, auth, parsing, and client setup in the library, not in
  `.robot`

## Keyword Surface Design

Prefer keyword surfaces like:

- `Create User`
- `Get User`
- `Delete User`
- `User Role Should Be`

Avoid surfaces like:

- `Execute User Management Scenario`
- `Do User Flow`
- `Call Backend With Configurable Payload`

Robot suites need a stable, intention-revealing vocabulary.

## Dynamic vs Hybrid APIs

Robot Framework supports static, dynamic, and hybrid library APIs. Default to
the normal static Python library style unless you have a concrete reason to
generate keywords dynamically.

Choose dynamic or hybrid APIs only when keyword discovery is data-driven or you
are adapting another system's callable surface.

## Remote Libraries

Use the remote library model when keywords should be served by another process
or machine. Do not choose this unless distribution or isolation is a real
requirement.

Remote libraries add protocol and process complexity. They are architecture
choices, not convenience shortcuts.

## Listeners

Use listeners when you need execution-time hooks for logging, metrics, custom
reporting, or side-channel integration.

### Listener v3 API (current)

```python
class MetricsListener:
    ROBOT_LISTENER_API_VERSION = 3

    def start_suite(self, data, result):
        print(f'Suite started: {result.name}')

    def end_test(self, data, result):
        print(f'Test {result.name}: {result.status}')

    def log_message(self, message):
        if message.level == 'FAIL':
            print(f'FAILURE: {message.message}')
```

Activate from CLI:

```bash
robot --listener MetricsListener.py tests/
robot --listener MetricsListener:arg1:arg2 tests/
```

Available callbacks: `start_suite`, `end_suite`, `start_test`, `end_test`,
`start_keyword`, `end_keyword`, `log_message`, `message`.

Do not use listeners as a substitute for ordinary keyword design. They are for
framework-level concerns, not feature logic.

## Libdoc

Use Libdoc to generate documentation for libraries:

```bash
libdoc ExampleLibrary.py docs/ExampleLibrary.html
```

This is the best way to expose library keyword contracts clearly.

Generate Libdoc when:

- a library is shared across teams or agents
- keyword arguments need to be discoverable
- you want a durable contract beyond reading Python source

## Extension Boundary

Before using listeners, remote libraries, or parser interfaces, ask:

- is ordinary suite/resource/library code enough?
- is the extension solving a framework-shaped problem?
- will another agent understand and maintain this hook?

Prefer the simplest extension surface that meets the need.

## Refactor Boundary

Move code from `.robot` to Python when you see:

- repeated parsing and normalization
- nested control flow around external calls
- complex assertion helpers with lots of intermediate values
- retry/polling logic that obscures the suite's intent

Keep code in `.robot` when the main value is readability of the scenario.
