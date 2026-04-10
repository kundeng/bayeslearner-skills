# Suite Format and Structure

## Required Shape

Every suite follows this layout:

```robot
*** Settings ***
Documentation     Short summary
Library           Browser
Library           WiseRpaBDD
Suite Setup       Given I start deployment "${DEPLOYMENT}"
Suite Teardown    Then I finalize deployment

*** Variables ***
${DEPLOYMENT}     ...
${ARTIFACT_...}   ...
${ENTRY_...}      ...

*** Test Cases ***
Artifact Catalog          # artifact registrations + quality gates
Resource Name             # one test case per resource
```

## Rules

- Every executable step starts with `Given`, `When`, `Then`, `And`, or `But`.
- Use continuation rows (`...`) for field specs, schemas, globals, options.
- Use `*** Keywords ***` only for reusable generic flow fragments.
- Keep artifact names, resource names, parent relationships, merge keys, and quality gates **visible** — never hide the flow in one opaque keyword.

## Structural Mapping

| Concept | Robot BDD shape |
| --- | --- |
| deployment name | `${DEPLOYMENT}` variable |
| artifacts | `Artifact Catalog` test case |
| resource | one test case per resource |
| entry URL | `[Setup] Given I start resource "name" at "${ENTRY}"` |
| node | `I define rule "name"` block (body indented) |
| parent chain | `And I declare parents "a, b"` |
| state check | `Given url ...` / `And selector ... exists` |
| action | `When I click/type/hover/focus/press keys/...` |
| passthrough | `And I browser step ...` / `And I call keyword ...` |
| expansion | `When I expand ...` / `When I paginate ...` |
| extraction | `Then I extract fields` / `Then I extract table ...` |
| emit | `And I emit to artifact ...` |
| quality | `And I set quality gate ...` |

## Common Patterns

**Pagination + element extraction** (quotes, books):
resource start → paginate by next button → expand over elements → extract fields → emit

**Sort + table extraction** (revspin):
click sort header → verify state → numeric pagination → extract table → emit

**Discovery + detail chaining** (docs):
resource 1: BFS expand nav links → emit URLs → resource 2: consume URLs → open each → extract → emit

**Matrix / combinations** (variants):
expand over combinations (axis values) → extract after each combo → emit

**AI extraction** (when CSS isn't enough):
extract raw HTML → pass to `Then I extract with AI` with prompt/schema → emit

**Auth flow** (protected content):
pure action rule (type creds, click submit) → child rule scrapes after login

**Observation gates** (async inter-action dependencies):
Option 1: split rules — action rule → state-gate rule → next action rule (pure MDP)
Option 2: `await=` — inline `await=<selector>` on the action that triggers async content

**Dismiss scoping** (interactive sites):
Only dismiss known popup patterns — never use broad selectors (`[role="dialog"]`) that match
interactive panels the flow depends on (search bars, calendars, pickers)

**Complex setup via call keyword** (multi-step interactions):
define RF keyword with raw Browser calls → `And I call keyword` defers it to walk time

## Setup Placement

- **Suite Setup**: deployment init
- **Test Setup** (`[Setup]`): per-resource entry navigation
- **Pure action rule**: deferred browser actions (login, auth) — runs during walk
- **`And I call keyword`**: defer a `*** Keywords ***` block with raw Browser calls
- **Keywords section**: reusable multi-step flows for `And I call keyword`

## AI Role

AI may propose selectors, draft suites from evidence, and author AI extraction prompts. AI must not replace generic keywords with site-specific verbs or use AI extraction as a shortcut when CSS selectors work.
