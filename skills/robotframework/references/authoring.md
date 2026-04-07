# Authoring

Use this file when writing or refactoring `.robot` files.

Source basis: Robot Framework User Guide sections on test data syntax, test
cases, tasks, variables, user keywords, resource files, control structures,
templates, and timeouts.

## Core Mental Model

Robot Framework test data lives in four sections: `*** Settings ***`,
`*** Variables ***`, `*** Test Cases ***` (or `*** Tasks ***`), and
`*** Keywords ***`. Tests and tasks share the same syntax. Use tasks when the
work is RPA/automation shaped; otherwise default to test cases.

The main authoring question is not "can Robot Framework do this?" but "which
layer should own it?"

- suite file: scenario intent and visible assertions
- resource file: reusable domain flows
- Python library: external-system mechanics and complex data logic

For exact syntax rules, see `references/syntax.md`.

## Preferred Suite Shape

```robot
*** Settings ***
Library           OperatingSystem
Resource          resources/common.resource
Suite Setup       Prepare Environment
Suite Teardown    Cleanup Environment

*** Variables ***
${ROOT}           ${CURDIR}
${INPUT_FILE}     ${ROOT}/data/input.txt

*** Test Cases ***
Input File Should Exist
    File Should Exist    ${INPUT_FILE}

*** Keywords ***
Prepare Environment
    Log    Preparing test environment

Cleanup Environment
    Log    Cleaning up test environment
```

Why this shape works:

- suite-level imports are visible
- setup/teardown stays explicit
- local variables are easy to locate
- scenario intent is readable from the test case body

## Tasks Pattern

Use `*** Tasks ***` when the suite is business-process or RPA oriented:

```robot
*** Tasks ***
Process Invoice
    Read Information From PDF
    Validate Information
    Submit Information To Backend System
```

The section name changes, but the execution model does not.

## User Keyword Design

Prefer user keywords when you need to compose lower-level keywords into a
stable higher-level action.

```robot
*** Keywords ***
Login As
    [Arguments]    ${username}    ${password}
    Fill Username    ${username}
    Fill Password    ${password}
    Submit Login
```

Good pattern:

- user keywords express intent
- library keywords perform concrete operations
- test cases stay short

Move repeated higher-level flows into resource files when multiple suites need
them.

### Good keyword boundary

```robot
*** Test Cases ***
Admin Can Disable User
    Login As Admin
    Open User Details    alice
    Disable User
    User Status Should Be    disabled
```

This is better than repeating UI or API mechanics inline because the behavioral
checkpoints stay visible.

### Bad keyword boundary

```robot
*** Test Cases ***
Admin Can Disable User
    Run Full Admin Disable User Flow    alice    disabled
```

That hides too much unless the whole flow is the contract.

## Templates

Use test templates when the same keyword shape is repeated over many rows.

```robot
*** Settings ***
Test Template    Login Should Fail With

*** Test Cases ***                 USERNAME         PASSWORD
Missing Password                   demo             ${EMPTY}
Missing Username                   ${EMPTY}         secret
Wrong Password                     demo             wrong

*** Keywords ***
Login Should Fail With
    [Arguments]    ${username}    ${password}
    Attempt Login    ${username}    ${password}
    Error Message Should Be Visible
```

Use templates for matrix-like validation. Do not use them if each test row
needs different control flow.

## Variables

Use variables for:

- paths
- credentials passed in from execution
- environment-dependent values
- shared expected values

Common forms:

- scalar: `${NAME}`
- list: `@{ITEMS}`
- dictionary: `&{CONFIG}`

Prefer suite variables for local defaults. Use variable files or command-line
variables when values vary by environment or run.

### Practical variable decision

- local constant for one suite: `*** Variables ***`
- shared values for many suites: resource file or variable file
- environment-specific values: variable file or `--variable`
- runtime-generated values: assign inside keyword or library call

### Scope caution

Variable scope and priority get confusing when suites, resources, variable
files, and command-line overrides all define similar names. Do not casually
reuse names across layers.

## Resource Files

Use resource files for:

- shared imports
- shared user keywords
- shared variables

Do not turn every suite into a giant resource dependency graph. Keep resources
cohesive and domain-oriented.

Good split:

- suite file owns scenario intent
- resource file owns reusable flows
- Python library owns complex external logic

### Resource file pattern

```robot
*** Settings ***
Library    libraries/ApiLibrary.py

*** Keywords ***
Create User Via API
    [Arguments]    ${username}
    ${user}=    Create User    ${username}
    RETURN    ${user}

User Status Should Be Active
    [Arguments]    ${user}
    Should Be Equal    ${user.status}    active
```

Use resource files to define a domain vocabulary. Avoid turning them into a
dumping ground for unrelated helpers.

## BDD-Style Keywords

Robot Framework strips `Given`, `When`, `Then`, `And`, and `But` from keyword
names before lookup. That enables natural-language test cases without a plugin:

```robot
*** Test Cases ***
User Can View Profile
    Given the user is logged in
    When the user opens the profile page
    Then the profile name is visible

*** Keywords ***
The user is logged in
    Login    ${DEFAULT_USER}    ${DEFAULT_PASS}

The user opens the profile page
    Go To    ${PROFILE_URL}

The profile name is visible
    Page Should Contain Element    id=profile-name
```

BDD prefixes work with embedded arguments:

```robot
*** Keywords ***
The user has ${count} items in the cart
    ${actual}=    Get Cart Count
    Should Be Equal As Integers    ${actual}    ${count}
```

Use BDD style when suites act as living documentation or when stakeholders read
the test cases directly. Do not force it onto suites that are clearer without
it.

## Continuation Rows

Use `...` to split long lines. The continuation row starts with `...`:

```robot
Log Many
...    first value
...    second value
...    third value

Create User
...    username=alice
...    role=admin
...    department=engineering

[Documentation]    This keyword performs a multi-step
...                setup process for the test environment.
```

Use continuation for long argument lists, multi-line documentation, and
structured calls. Prefer it over cramming everything onto one line.

## Suite Initialization Files

`__init__.robot` configures a directory-level suite. One per directory:

```robot
*** Settings ***
Documentation    API integration tests
Suite Setup      Start API Server
Suite Teardown   Stop API Server
Test Tags        api    integration
Test Timeout     30 seconds
```

Use `__init__.robot` for:

- directory-wide setup/teardown
- shared tags and timeouts
- suite documentation and metadata

Child directories inherit from parent `__init__.robot` files. Keep them lean;
put reusable keywords in resource files.

## Control Structures

Robot Framework supports `FOR`, `WHILE`, `IF / ELSE IF / ELSE`,
`TRY / EXCEPT / ELSE / FINALLY`, `BREAK`, `CONTINUE`, and `GROUP`.

Use them carefully. If the control flow starts reading like general-purpose
code, move the logic into Python.

For exact syntax of all control structures, see `references/syntax.md`.

### Reasonable use

```robot
*** Keywords ***
Wait Until Status Is Ready
    [Arguments]    ${job_id}
    WHILE    True    limit=30
        ${status}=    Get Job Status    ${job_id}
        IF    '${status}' == 'ready'    BREAK
        Sleep    1s
    END
```

### Boundary to stop

If you are about to nest loops, conditionals, and exception handling around
data shaping, write or extend a Python library instead.

## TRY/EXCEPT

Use `TRY/EXCEPT` when failure handling is part of the suite contract:

- checking that an operation fails in an expected way
- cleanup that should continue after a known error
- narrowing behavior around flaky external systems

Do not use `TRY/EXCEPT` to hide broad uncertainty. That belongs in library code
or a more precise test design.

## Timeouts

Timeouts can be set for test cases and user keywords. Use them when hangs are a
real risk, especially with browser, network, or external-system operations.

```robot
*** Test Cases ***
Slow Query Should Complete
    [Timeout]    2 minutes
    Run Slow Query    ${QUERY}
```

Timeouts are part of the behavior contract. Set them deliberately, not as a
last-second bandage.

## Refactoring Rules

- keep test/task names behavior-oriented
- keep assertions visible in the test/task body unless hidden intentionally in a
  very clear higher-level keyword
- avoid duplicate low-level steps across suites
- split long suites by domain or surface, not arbitrarily by line count
- avoid mixing unrelated concerns in one resource file
- prefer templates for repeated same-shape cases
- prefer resource files over copy-pasting suite-local keywords across files
- prefer Python libraries once suite code is fighting the data model
