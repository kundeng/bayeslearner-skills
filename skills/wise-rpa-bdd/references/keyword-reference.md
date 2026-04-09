# Keyword Reference

`WiseRpaBDD` is a **generic** keyword library. Site-specific values belong in arguments and continuation rows — never in keyword names.

## Starter Template

```robot
*** Settings ***
Documentation     Minimal strict BDD suite
Library           Browser
Library           WiseRpaBDD
Suite Setup       Given I start deployment "${DEPLOYMENT}"
Suite Teardown    Then I finalize deployment

*** Variables ***
${DEPLOYMENT}        example-deployment
${ENTRY_URL}         https://example.com
${ARTIFACT_RECORDS}  records

*** Test Cases ***
Artifact Catalog
    Given I register artifact "${ARTIFACT_RECORDS}"
    ...    field=title    type=string    required=true
    ...    field=url      type=url       required=true
    And I set artifact options for "${ARTIFACT_RECORDS}"
    ...    output=true

Primary Resource
    [Setup]    Given I start resource "primary" at "${ENTRY_URL}"
    Given url contains "/"
    And selector ".row" exists
    When I expand over elements ".row"
    Then I extract fields
    ...    field=title    extractor=text    locator=".title"
    ...    field=url      extractor=link    locator="a"
    And I emit to artifact "${ARTIFACT_RECORDS}"

Quality Gates
    And I set quality gate min records to 10
    And I set filled percentage for "title" to 95
```

## Deployment

**`Given I start deployment "${DEPLOYMENT}"`** — Initialize a named extraction run. Always in Suite Setup.

**`Then I finalize deployment`** — Execute the rule tree, write outputs, run quality gates. Always in Suite Teardown.

## Artifacts

**`Given I register artifact "${name}"`** — Declare a named data container. Continuation rows:
- `field=<name> type=<string|number|url|array|html> required=<true|false>`

**`And I set artifact options for "${name}"`** — Configure behavior:
- `output=<true|false>` — write to disk
- `structure=<nested|flat>` — tree vs denormalized
- `dedupe=<field>` — deduplicate by field
- `query=<jmespath>` — transform before output
- `consumes=<artifact>` — input dependency for execution ordering
- `description=<text>` — human-readable purpose

## Resources

**`Given I start resource "${name}" at "${url}"`** — Begin a resource at a static entry URL.

**`Given I start resource "${name}"`** — Begin without a static URL (used with consume/resolve).

**`Given I consume artifact "${name}"`** — Declare input dependency.

**`Given I resolve entry from "${reference}"`** — Resolve entry URLs from another resource's data.

**`Given I iterate over parent records from "${case}"`** — Loop over parent records; child runs once per parent.

**`And I set resource globals`** — Per-resource config:
- `timeout_ms=`, `retries=`, `page_load_delay_ms=`, `user_agent=`

### Multi-resource chaining example

```robot
Discovery Resource
    [Setup]    Given I start resource "discover" at "${ENTRY_URL}"
    When I expand over elements "nav a" with order "bfs"
    Then I extract fields
    ...    field=page_url    extractor=link    locator="."
    And I emit to artifact "${ARTIFACT_URLS}"

Detail Resource
    [Setup]    Given I start resource "detail"
    Given I consume artifact "${ARTIFACT_URLS}"
    When I open the bound field "page_url"
    Then I extract fields
    ...    field=title    extractor=text    locator="h1"
    ...    field=body     extractor=html    locator="article"
    And I emit to artifact "${ARTIFACT_PAGES}"
```

## Rules

**`And I begin rule "${name}"`** — Start a named block within a resource. Rules are the unit of state/action/expand/extract/emit.

**`And I declare parents "${names}"`** — Declare parent rules (comma-separated). Root rules have no parents.

## State Checks

**`Given url contains "${pattern}"`** — Assert current URL contains the string.

**`Given url matches "${pattern}"`** — Assert URL matches regex.

**`But url does not contain "${pattern}"`** — Negative URL assertion.

**`And selector "${css}" exists`** — Assert selector matches at least one element.

**`And table headers are "${headers}"`** — Assert table column headers (pipe-delimited).

## Actions

All actions are **deferred** — they record during test case definition and execute during the rule walk when the browser is live. Never use raw Browser library keywords directly in test cases (see "Deferred Execution Model" below).

### Navigation

**`When I open "${url}"`** — Navigate to URL.

**`When I open the bound field "${field}"`** — Navigate to URL from consumed/parent record.

### Interaction

**`When I click locator "${css}"`** — Click an element. Optional: `delay_ms=<number>`

**`When I double click locator "${css}"`** — Double-click an element.

**`When I type "${value}" into locator "${css}"`** — Type into input (clears first).

**`When I type secret "${value}" into locator "${css}"`** — Type secret (redacted in logs).

**`When I select "${value}" from locator "${css}"`** — Select dropdown option.

**`When I check locator "${css}"`** — Check a checkbox.

**`When I hover locator "${css}"`** — Hover over an element (triggers menus, tooltips).

**`When I focus locator "${css}"`** — Focus an element (for keyboard interaction).

**`When I press keys "${css}"`** — Press keyboard keys on a focused element. Keys as continuation args:
- `When I press keys "#search"    Enter`
- `When I press keys "#input"    Control+a    Delete`

**`When I upload file "${path}" to locator "${css}"`** — Upload a file to a file input.

### Timing

**`When I scroll down`** — Scroll one viewport height.

**`When I wait for idle`** — Wait for network idle.

**`When I wait ${ms} ms`** — Wait a fixed duration.

### Debugging

**`When I take screenshot`** — Capture the current page. Optional: `filename=<path>`

### Sort + verify example

```robot
Sort By Durability
    And I begin rule "sort_action"
    When I click locator "th.durability a"
    ...    delay_ms=1000
    Given url contains "durability"
```

### Auth flow example (pure action rule)

```robot
Resource protected_content
    [Setup]    Given I start resource "content" at "${LOGIN_URL}"
    And I begin rule "login"
    When I type "${USERNAME}" into locator "#username"
    When I type secret "${PASSWORD}" into locator "#password"
    When I click locator "#submit"
    When I wait for idle
    And I begin rule "scrape"
    And I declare parents "login"
    When I expand over elements ".result"
    Then I extract fields
    ...    field=title    extractor=text    locator="h1"
    And I emit to artifact "${ARTIFACT}"
```

## Expansion

**`When I expand over elements "${scope}"`** — Match elements; run child rules for each.

**`When I expand over elements "${scope}" with order "${order}"`** — `dfs` (default, streaming) or `bfs` (collect all first).

**`When I paginate by next button "${css}" up to ${limit} pages`** — Follow next-page links.

**`When I paginate by numeric control "${css}" from ${start} up to ${limit} pages`** — Click numbered page controls.

**`When I expand over combinations`** — Cartesian product of filter axes:
- `action=<type|select|checkbox> control=<css> values=<val1|val2|...>`

### Variant click expansion example

```robot
Variant Prices
    And I begin rule "variants"
    And I declare parents "products"
    When I expand over combinations
    ...    action=type    control="#hdd-select"    values=128|256|512|1024
    Then I extract fields
    ...    field=hdd_size    extractor=text    locator=".hdd-selected"
    ...    field=price       extractor=text    locator=".price"
    And I emit to artifact "${ARTIFACT_VARIANTS}"
```

## Extraction

**`Then I extract fields`** — Extract from current page/element. Continuation rows:
- `field=<name> extractor=<type> locator=<css>`
- Extractors: `text`, `attr` (needs `attr=`), `link`, `html`, `image`, `grouped` (array), `number`

**`Then I extract table "${name}" from "${css}"`** — Table extraction via header mapping:
- `field=<name> header=<text>` / `header_row=<number>`

## AI Extraction

**`Then I extract with AI "${name}"`** — Semantic extraction on already-captured text:
- `prompt=<text>`, `input=<field>`, `schema=<json>`, `categories=<cat1|cat2|...>`

AI operates on previously extracted text, never on the live DOM. Capture with `html` or `text` first, then reference via `input=`.

### AI classification example

```robot
    Then I extract fields
    ...    field=body    extractor=html    locator="article"
    Then I extract with AI "classify"
    ...    input=body
    ...    categories=tutorial|reference|api|changelog
```

### AI structured extraction example

```robot
    Then I extract with AI "parse_specs"
    ...    input=body
    ...    prompt="Extract product specifications"
    ...    schema={"type":"array","items":{"type":"object","properties":{"spec":"string","value":"string"}}}
```

## Emit / Merge / Output

**`And I emit to artifact "${name}"`** — Push extracted fields to artifact.

**`And I emit to artifact "${name}" flattened by "${field}"`** — One record per array element.

**`And I merge into artifact "${name}" on key "${field}"`** — Merge child data into parent by key.

**`Then I write artifact "${name}" to "${path}"`** — Write to specific path.

## Quality Gates

**`And I set quality gate min records to ${count}`** — Fail if fewer than N records.

**`And I set filled percentage for "${field}" to ${percent}`** — Fail if field < N% filled.

**`And I set max failed percentage to ${percent}`** — Fail if > N% records failed.

## Hooks

**`And I register hook "${name}" at "${point}"`** — Lifecycle hook:
- Points: `post_discover`, `pre_extract`, `post_extract`, `pre_assemble`, `post_assemble`

## State Setup / Auth

**`Given I configure state setup`** — Pre-scrape setup:
- `skip_when=<url>`, `action=open url=<url>`, `action=input css=<sel> value=<val>`, `action=password css=<sel> value=<secret>`, `action=click css=<sel>`

**`And I configure interrupts`** — Auto-dismiss overlays: `dismiss=<css>`

## Browser Step & Call Keyword (passthrough)

For Browser library methods not covered by the action keywords above, two passthrough mechanisms let you call any method at the right time during the rule walk.

**`And I browser step "${method}"`** — Defer a single Browser library method call. The method name must match the adapter interface (e.g. `click`, `fill_text`, `hover`).

```robot
And I browser step "Press Keys" "#search" "Enter"
And I browser step "Hover" ".menu-trigger"
And I browser step "Take Screenshot" "filename=debug.png"
```

**`And I call keyword "${name}"`** — Defer an arbitrary Robot Framework keyword. The keyword runs during the rule walk when the browser is live, so it can use raw Browser library keywords.

```robot
*** Keywords ***
Accept Terms And Login
    Click    #accept-terms
    Fill Text    #email    ${EMAIL}
    Fill Text    #password    ${PASSWORD}
    Click    #login-submit

*** Test Cases ***
Resource dashboard
    [Setup]    Given I start resource "dashboard" at "${ENTRY_URL}"
    And I begin rule "auth"
    And I call keyword "Accept Terms And Login"
    And I begin rule "data"
    And I declare parents "auth"
    When I expand over elements ".widget"
    Then I extract fields
    ...    field=metric    extractor=text    locator=".value"
    And I emit to artifact "${ARTIFACT}"
```

## Fallback Selectors

Selectors support pipe-delimited fallback chains. The engine tries each selector in order and uses the first that matches:

```robot
Then I extract fields
...    field=title    extractor=text    locator="h1.title | h1 | [data-field='title']"
```

If none match, the first selector is used (preserving error messages). Plain selectors (no `|`) have zero overhead.

## Deferred Execution Model

**All WiseRpaBDD keywords are deferred.** They record instructions during test case definition. The browser only opens when `finalize deployment` runs in Suite Teardown. The ExecutionEngine then walks the rule tree and executes everything.

**Raw Browser library keywords (`Click`, `Fill Text`, `Get Text`, etc.) placed directly in test cases will crash** with "No browser context open" because no browser exists during test definition.

Three ways to run browser actions at the right time:

| Option | Use when | Example |
|--------|----------|---------|
| **Action keywords** | Standard interactions (click, type, hover, etc.) | `When I click locator "#btn"` |
| **`And I browser step`** | One-off Browser method not covered above | `And I browser step "Drag And Drop" ".src" ".dst"` |
| **`And I call keyword`** | Complex multi-step flows (auth, setup) | `And I call keyword "Login To Site"` |

All three record during definition and execute during the rule walk when the browser is live.

## Important Constraint

Never replace generic keywords with site-specific verbs.

Bad: `When I open the Revspin durability page`
Good: `When I click locator "td.durability a"`
