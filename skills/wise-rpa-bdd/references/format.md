# Format

Author strict Robot Framework suites. Do not invent a parallel DSL.

## Required Shape

```robot
*** Settings ***
Documentation     Short suite summary
Library           WiseRpaBDD
Suite Setup       Given I start deployment "${DEPLOYMENT}"
Suite Teardown    Then I finalize deployment

*** Variables ***
${DEPLOYMENT}     example-deployment
${ARTIFACT_ROWS}  rows
${ENTRY_URL}      https://example.com

*** Test Cases ***
Artifact Catalog
    Given I register artifact "${ARTIFACT_ROWS}"
    ...    field=name    type=string    required=true
    ...    field=url     type=url       required=true
    And I set artifact options for "${ARTIFACT_ROWS}"
    ...    format=jsonl
    ...    output=true

Listing Resource
    [Setup]    Given I start resource "listing" at "${ENTRY_URL}"
    Given url contains "/browse"
    And selector ".card" exists
    When I expand over elements ".card" with order "bfs"
    Then I extract fields
    ...    field=name    extractor=text    locator=".title"
    ...    field=url     extractor=link    locator="a"
    And I emit to artifact "${ARTIFACT_ROWS}"

Detail Resource
    [Setup]    Given I iterate over parent records from "Listing Resource"
    When I open the bound field "url"
    Then I extract fields
    ...    field=description    extractor=text    locator=".description"
    And I merge into artifact "${ARTIFACT_ROWS}" on key "url"

*** Keywords ***
Given I am authenticated
    Given I open "${LOGIN_URL}"
    But url does not contain "/dashboard"
    When I type "${USERNAME}" into locator "#username"
    And I type secret "${PASSWORD}" into locator "#password"
    And I click locator "#login-btn"
    Then url contains "/dashboard"
```

## Rules

- Every executable step starts with `Given`, `When`, `Then`, `And`, or `But`.
- Keep strings quoted.
- Use continuation rows for structured specs.
- Use `*** Keywords ***` only for reusable generic flow fragments.
- Keep artifact and quality declarations visible in the suite.

## Continuation Rows

Use continuation rows for:

- field specs
- artifact field schemas
- resource globals
- table column mappings
- quality gates
- action options
- expansion axes/options

Examples:

```robot
Then I extract fields
...    field=title    extractor=text    locator="h1"
...    field=body     extractor=html    locator="article"

Given I register artifact "${ARTIFACT_DOCS}"
...    field=title    type=string    required=true
...    field=body     type=string    required=true
```

## Setup Placement

- **Suite Setup**: deployment/bootstrap/auth that applies broadly
- **Test Setup**: per-resource entry navigation or parent binding
- **Keyword setup flow**: when setup itself needs multiple BDD steps

Use `Suite Setup` / `Test Setup` when it genuinely improves readability. Do not hide the whole extraction flow inside setup.
