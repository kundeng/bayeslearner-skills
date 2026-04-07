# Keyword Contract

`WiseRpaBDD` is a **generic** keyword library. The site-specific values belong in arguments and continuation rows.

## Deployment

- `Given I start deployment "${deployment}"`
- `Then I finalize deployment`

## Artifact Catalog

- `Given I register artifact "${artifact}"`
  - continuation rows: `field=<name> type=<type> required=<true|false>`
- `And I set artifact options for "${artifact}"`
  - continuation rows: `format=`, `output=`, `structure=`, `dedupe=`, `query=`, `consumes=`, `description=`

## Resource / Chaining

- `Given I start resource "${resource}"`
- `Given I start resource "${resource}" at "${entry}"`
- `Given I consume artifact "${artifact}"`
- `Given I resolve entry from "${reference}"`
- `Given I iterate over parent records from "${parent_case}"`
- `And I set resource globals`
  - continuation rows: `timeout_ms=`, `retries=`, `page_load_delay_ms=`, `user_agent=`

## Rule Blocks

- `And I begin rule "${rule}"`
- `And I declare parents "${parents}"`

## State / Preconditions

- `Given url contains "${pattern}"`
- `Given url matches "${pattern}"`
- `But url does not contain "${pattern}"`
- `And selector "${selector}" exists`
- `And table headers are "${headers}"`

## Actions

- `When I open "${url}"`
- `When I open the bound field "${field}"`
- `When I click locator "${locator}"`
- `When I type "${value}" into locator "${locator}"`
- `When I type secret "${value}" into locator "${locator}"`
- `When I scroll down`
- `When I wait for idle`
- `When I wait ${ms} ms`

Action keywords may take continuation rows for options such as `type=real`, `delay_ms=1000`, or `uniqueness=text`.

## Expansion

- `When I expand over elements "${scope}"`
- `When I expand over elements "${scope}" with order "${order}"`
- `When I paginate by next button "${locator}" up to ${limit} pages`
- `When I paginate by numeric control "${locator}" from ${start} up to ${limit} pages`
- `When I expand over combinations`
  - continuation rows: `action=type control="#search" values=laptop|tablet`

## Extraction

- `Then I extract fields`
  - continuation rows such as:
    - `field=title extractor=text locator="h1"`
    - `field=url extractor=link locator="a"`
    - `field=name extractor=attr locator="a.title" attr="title"`
- `Then I extract table "${name}" from "${locator}"`
  - continuation rows such as:
    - `field=First Name header="First Name"`
    - `field=Username header="Username"`

## Emit / Merge / Output

- `And I emit to artifact "${artifact}"`
- `And I emit to artifact "${artifact}" flattened by "${field}"`
- `And I merge into artifact "${artifact}" on key "${key}"`
- `Then I write artifact "${artifact}" to "${path}"`

## Quality Gates

- `And I set quality gate min records to ${count}`
- `And I set filled percentage for "${field}" to ${percent}`

## Important Constraint

Do not replace these with site-specific verbs. Bad:

- `When I open the Revspin durability page`
- `Then I capture Splunk ITSI side-nav pages`

Good:

- `When I click locator "td.durability a"`
- `When I expand over elements "nav a[href*='/administer/4.21/']" with order "bfs"`
