# Flow Shape

This skill expresses structured browser extraction flows in strict Robot Framework BDD.

## Structural Correspondence

| Flow concern | Robot BDD shape |
| --- | --- |
| `name` | `${DEPLOYMENT}` variable |
| `artifacts` | `Artifact Catalog` case or reusable registration keyword |
| `resource` | one test case per resource |
| `entry.url` | resource setup / start step |
| `globals` | `And I set resource globals` continuation rows |
| `node` | `And I begin rule "<name>"` block |
| `parents` | `And I declare parents "<a, b>"` |
| `state` | `Given url ...`, `And selector ... exists`, `And table headers ...` |
| `action` | generic `When ...` steps |
| `expand` | generic expansion/pagination steps |
| `extract` | `Then I extract fields` or `Then I extract table ...` |
| `emit` | `And I emit to artifact ...` |
| `consumes` | `Given I consume artifact ...` |
| `entry.url: { from: ... }` | `Given I resolve entry from "...""` |
| `setup` | `Given I configure state setup` continuation rows |
| `hooks` | `And I register hook` at lifecycle point |
| `interrupts` | `And I configure interrupts` continuation rows |
| `ai extraction` | `Then I extract with AI` with prompt/input/schema |
| `context refs` | `{field}`, `{artifacts.name.field}`, `{config.key}` |
| quality gates | explicit quality steps at end of suite or resource |

## What Stays Visible

Do not hide the whole flow in one engine keyword. Keep these explicit:

- artifact names
- resource names
- parent relationships
- bound field usage
- merge keys
- quality expectations

## Example Shapes

Typical shapes:

- **quotes / books**:
  - resource start
  - page expansion via next button
  - element expansion over cards
  - field extraction
  - emit nested + flat artifacts

- **revspin**:
  - root click action to change sort
  - numeric pagination
  - row extraction

- **documentation crawls**:
  - discovery resources with BFS element expansion
  - extraction resources with `Given I resolve entry from "..."`
  - nested + flat output artifacts

- **ai extraction**:
  - extract raw HTML or text with normal `extract fields`
  - pass captured field to `Then I extract with AI` with prompt and schema
  - emit AI-structured output to artifact

- **matrix / combinations**:
  - `When I expand over combinations` with axis continuation rows
  - each axis defines action type, control selector, and values
  - extract results after each combination is applied

- **element click**:
  - expand over clickable elements with `When I expand over elements`
  - click each element with `When I click locator` and `uniqueness=<text|css>`
  - extract revealed content after click, emit per element

- **sort verify**:
  - click sort header via `When I click locator`
  - verify sort applied via `Given url contains` or `And selector ... exists`
  - extract sorted table rows

## AI Role

AI may:

- propose selectors
- tighten field mappings
- repair bad continuation rows
- draft resource cases from evidence

AI may not:

- replace the generic keyword contract with site-specific verbs
- hide chaining semantics inside unnamed runtime magic
- use AI extraction as a shortcut when CSS selectors would work

Additional AI guidance:

- AI may draft AI extraction prompts and schemas when deterministic extraction is insufficient
- AI may not reach for `Then I extract with AI` before proving that normal extractors cannot handle the task
