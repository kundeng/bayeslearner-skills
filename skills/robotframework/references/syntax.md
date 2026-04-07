# Syntax

Precise Robot Framework syntax rules from the official User Guide (RF 7.x).
Use this file for grammar, not design guidance.

## File Format

Robot Framework uses space-separated format by default. Cell separators are
**two or more spaces** or **one or more tabs**. Four-space indentation is the
usual body style.

An alternative pipe-separated format uses `| cell | cell |` with a mandatory
leading pipe and at least one space on each side. Pipes in data must be
escaped as `\|`.

Long lines use ellipsis continuation:

```robot
Log Many
...    first argument
...    second argument
...    third argument
```

Continuation joins values with a space by default. Inside `[Documentation]` and
`Metadata`, continuation joins with a newline.

## Section Headers

Section headers are case-insensitive and need at least one asterisk. Canonical form:

```
*** Settings ***
*** Variables ***
*** Test Cases ***
*** Tasks ***
*** Keywords ***
*** Comments ***
```

Singular forms like `*** Setting ***` are deprecated since RF 6.0 and warn in
RF 7.0+.

## Variables

### Scalar `${name}`

Single value. Used in arguments, settings, and other variables:

```robot
*** Variables ***
${URL}       https://example.com
${TIMEOUT}   30s
```

### List `@{name}`

Multiple values. Expands into separate arguments when called with `@{}`:

```robot
*** Variables ***
@{USERS}    alice    bob    charlie

*** Test Cases ***
Example
    Log Many    @{USERS}    # three separate arguments
```

Access individual items: `${USERS}[0]`, `${USERS}[-1]`.

### Dictionary `&{name}`

Key-value pairs. Expands to named arguments when called with `&{}`:

```robot
*** Variables ***
&{CREDS}    username=admin    password=secret

*** Test Cases ***
Example
    Login    &{CREDS}    # named arguments username=admin, password=secret
```

Access: `${CREDS}[username]` or `${CREDS.username}`.

### Environment `%{name}`

OS environment variables. Case-sensitive on Unix:

```robot
Log    Home is %{HOME}
Log    With default: %{MY_VAR|fallback_value}
```

### Extended Variable Syntax

Python expressions inside variable references:

```
${LIST}[0]            indexing
${LIST}[1:]           slicing
${DICT}[key]          dictionary access
${OBJ.attribute}      attribute access
${DICT}[k1][k2]      nested access
${SPACE * 4}          repetition
```

### Built-in Variables

Paths and OS:

| Variable | Value |
|---|---|
| `${CURDIR}` | directory of current test data file |
| `${EXECDIR}` | directory where execution started |
| `${TEMPDIR}` | OS temporary directory |
| `${/}` | OS path separator |
| `${:}` | OS path list separator |

String constants:

| Variable | Value |
|---|---|
| `${SPACE}` | single space |
| `${EMPTY}` | empty string |
| `${LF}` | line feed `\n` |
| `${CR}` | carriage return `\r` |
| `${\n}` | OS-native line separator |

Boolean and null:

| Variable | Value |
|---|---|
| `${TRUE}` | Python `True` |
| `${FALSE}` | Python `False` |
| `${NONE}` | Python `None` |
| `${NULL}` | alias for `${NONE}` |

Automatic test/suite context. Read-only during execution:

| Variable | Meaning |
|---|---|
| `${TEST NAME}` | current test case name |
| `${TEST TAGS}` | current test tags as list |
| `${TEST STATUS}` | `PASS` or `FAIL` (in teardown) |
| `${TEST MESSAGE}` | failure message (in teardown) |
| `${SUITE NAME}` | current suite name |
| `${SUITE SOURCE}` | suite file path |
| `${OUTPUT DIR}` | output directory path |
| `${LOG FILE}` | log HTML file path |
| `${REPORT FILE}` | report HTML file path |

### VAR Statement (RF 7.0+)

Create variables dynamically inside a test or keyword body:

```robot
VAR    ${GREETING}    Hello, World!
VAR    @{ITEMS}       apple    banana    cherry
VAR    &{USER}        name=Alice    age=30
```

Scope control:

```robot
VAR    ${LOCAL}     value                    # keyword-local (default)
VAR    ${TEST_V}    value    scope=TEST      # visible in entire test
VAR    ${SUITE_V}   value    scope=SUITE     # visible in suite
VAR    ${GLOBAL_V}  value    scope=GLOBAL    # visible everywhere
```

`VAR` replaces `Set Variable`, `Set Test Variable`, `Set Suite Variable`, and
`Set Global Variable` in most cases.

### Variable Assignment from Keywords

```robot
${result}=                    Get Value
${first}    ${second}=        Get Two Values
${head}    @{tail}=           Get List    # rest capture
```

The trailing `=` on the last variable is optional but conventional.

## Control Structures

All control structures use `END`.

### FOR

```robot
FOR    ${item}    IN    @{ITEMS}
    Log    ${item}
END
```

Variants:

```robot
# Range (0-based by default)
FOR    ${i}    IN RANGE    10               # 0..9
FOR    ${i}    IN RANGE    1    11           # 1..10
FOR    ${i}    IN RANGE    0    100    10    # 0, 10, 20 .. 90

# Multiple assignment (unpacking)
FOR    ${key}    ${value}    IN    @{PAIRS}
    Log    ${key} = ${value}
END

# Enumerate (index + item)
FOR    ${index}    ${item}    IN ENUMERATE    @{ITEMS}    start=1
    Log    ${index}: ${item}
END

# Zip (parallel iteration)
FOR    ${a}    ${b}    IN ZIP    @{LIST1}    @{LIST2}
    Log    ${a} paired with ${b}
END
```

Nested loops are supported. `BREAK` and `CONTINUE` affect the innermost loop.

### WHILE

```robot
WHILE    ${counter} < 10
    ${counter}=    Evaluate    ${counter} + 1
END
```

A safety limit prevents infinite loops. Override with `limit=`:

```robot
WHILE    True    limit=100
    ${value}=    Get Next
    IF    '${value}' == 'done'    BREAK
END
```

### IF / ELSE IF / ELSE

```robot
IF    ${status} == 'PASS'
    Log    passed
ELSE IF    ${status} == 'SKIP'
    Log    skipped
ELSE
    Log    other
END
```

Conditions use Python expression syntax: `==`, `!=`, `<`, `>`, `<=`, `>=`,
`and`, `or`, `not`, `in`, `not in`, `is`, `is not`, parentheses.

Inline form for single assignments:

```robot
${result}=    Set Variable If    ${condition}    true_val    false_val
```

### TRY / EXCEPT / ELSE / FINALLY

```robot
TRY
    Risky Keyword
EXCEPT    ValueError    AS    ${err}
    Log    Caught: ${err}
EXCEPT
    Log    Unknown error
ELSE
    Log    No error
FINALLY
    Log    Always runs
END
```

Multiple `EXCEPT` blocks can match specific error types. A bare `EXCEPT`
catches the rest.

### BREAK and CONTINUE

```robot
FOR    ${item}    IN    @{LIST}
    IF    '${item}' == 'skip'    CONTINUE
    IF    '${item}' == 'stop'    BREAK
    Process    ${item}
END
```

### GROUP (RF 7.0+)

Organizational grouping inside test/keyword bodies:

```robot
GROUP    Setup Phase
    Prepare Data
    Initialize Config
END
GROUP    Execution Phase
    Run Main Flow
END
```

Primarily for readability and log structure. It does not change execution.

## RETURN Statement

Modern way to return values from keywords (RF 5.0+). Replaces deprecated
`[Return]`:

```robot
*** Keywords ***
Get Processed Value
    [Arguments]    ${raw}
    ${result}=    Process    ${raw}
    RETURN    ${result}
```

Conditional return:

```robot
Find Item
    [Arguments]    @{items}    ${target}
    FOR    ${item}    IN    @{items}
        IF    '${item}' == '${target}'
            RETURN    ${item}
        END
    END
    RETURN    ${EMPTY}
```

`[Return]` still works but is deprecated since RF 6.1. Use `RETURN` in new
code.

## Keyword Arguments

### Positional with defaults

```robot
*** Keywords ***
Login As
    [Arguments]    ${user}    ${password}=${EMPTY}    ${mfa}=${FALSE}
    Log    Logging in ${user}
```

### Variable-length (`*args` and `**kwargs`)

```robot
*** Keywords ***
Flexible Keyword
    [Arguments]    ${required}    @{extra}    &{named}
    Log    Required: ${required}
    Log Many    @{extra}
    Log    Named: &{named}
```

### Named-only arguments (RF 5+)

Arguments after a bare `@{}` marker are named-only:

```robot
*** Keywords ***
Create User
    [Arguments]    ${name}    @{}    ${role}=member    ${active}=${TRUE}
    Log    ${name} with role ${role}
```

Callers must use `role=admin` syntax; positional passing is rejected.

### Embedded arguments

Variables in the keyword name itself:

```robot
*** Keywords ***
User ${username} should have role ${role}
    Check Role    ${username}    ${role}

*** Test Cases ***
Role Check
    User alice should have role admin
```

Embedded arguments are extracted by pattern match at call time. They can coexist
with BDD prefixes.

## BDD Prefixes

Robot Framework strips `Given`, `When`, `Then`, `And`, and `But` from keyword
names during resolution:

```robot
*** Test Cases ***
Login Flow
    Given the login page is open
    When the user enters valid credentials
    Then the dashboard is visible

*** Keywords ***
The login page is open
    Open Browser    ${LOGIN_URL}

The user enters valid credentials
    Input Text    id=user    ${USERNAME}
    Input Text    id=pass    ${PASSWORD}
    Click Button    id=login

The dashboard is visible
    Page Should Contain    Dashboard
```

Rules:

- prefixes are case-insensitive
- must be followed by a space
- stripped before keyword lookup
- work with embedded arguments: `Given I have ${count} items`
- custom prefixes can be defined via RF language configuration files

## Type Conversion

When a Python library keyword has type hints, Robot Framework automatically
converts string arguments:

```python
def set_count(self, count: int):       # "42" → 42
def set_flag(self, flag: bool):        # "True"/"Yes"/"On"/"1" → True
def add_items(self, items: list):      # @{var} → list
def configure(self, opts: dict):       # &{var} → dict
```

Boolean conversion is case-insensitive. Recognized true values: `True`, `Yes`,
`On`, `1`. Recognized false values: `False`, `No`, `Off`, `0`, empty string.

Union types and custom converters are supported for more complex cases.

## Suite Initialization: `__init__.robot`

One per directory. Sets suite-level configuration for all files in that
directory:

```robot
*** Settings ***
Documentation    Integration test suite
Suite Setup      Connect To Database
Suite Teardown   Disconnect Database
Test Tags        integration
Test Timeout     30 seconds

*** Variables ***
${DB_HOST}    localhost
```

The `__init__.robot` in a parent directory executes before child directories.
Suites inherit tags and settings from their `__init__.robot`.

## Separator and Whitespace Rules

- Two or more spaces (or tabs) separate cells.
- Leading spaces on a line indicate the row belongs to the preceding test case,
  task, or keyword.
- Empty cells must be represented by `${EMPTY}` or escaped with `\`.
- Trailing whitespace is stripped.
- Blank lines between test cases or keywords are optional but improve
  readability.
- Comments start with `#` and must be preceded by a cell separator to be
  recognized as comments on data lines.
