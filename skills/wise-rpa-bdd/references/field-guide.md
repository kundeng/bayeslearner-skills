# Field Guide

Plain English explanations of every BDD step and continuation row in the keyword contract.

## Deployment

**`Given I start deployment "${DEPLOYMENT}"`** — Initialize a named extraction run. Sets the deployment identity for all artifacts and output files. Always in Suite Setup.

**`Then I finalize deployment`** — Complete the run, write output files, run quality gate checks. Always in Suite Teardown.

## Artifacts

**`Given I register artifact "${name}"`** — Declare a named data container with a field schema. Continuation rows define each field:
- `field=<name>` — field identifier
- `type=<string|number|url|array|html>` — data type
- `required=<true|false>` — whether empty values trigger quality warnings

**`And I set artifact options for "${name}"`** — Configure artifact behavior:
- `format=<jsonl|json|csv|markdown>` — output format
- `output=<true|false>` — whether to write this artifact to disk
- `structure=<nested|flat>` — tree vs denormalized output
- `dedupe=<field>` — deduplicate by this field
- `query=<jmespath>` — JMESPath transform on tree records before output
- `consumes=<artifact>` — declare input dependency for execution ordering
- `description=<text>` — human-readable purpose

## Resources

**`Given I start resource "${name}" at "${url}"`** — Begin a resource at a static entry URL.

**`Given I start resource "${name}"`** — Begin a resource without a static URL (used with consume/resolve).

**`Given I consume artifact "${name}"`** — Declare input dependency; records from this artifact are available for iteration or field binding.

**`Given I resolve entry from "${reference}"`** — Resolve entry URLs from another resource's extracted data. Reference format: `resource.node.field`.

**`Given I iterate over parent records from "${case}"`** — Loop over parent records; child resource runs once per parent record.

**`And I set resource globals`** — Per-resource configuration:
- `timeout_ms=<number>` — page load timeout
- `retries=<number>` — retry count on failure
- `page_load_delay_ms=<number>` — delay after each page load
- `user_agent=<string>` — custom user agent string

## Rules

**`And I begin rule "${name}"`** — Start a named block within a resource. Rules are the unit of state/action/expand/extract/emit.

**`And I declare parents "${names}"`** — Declare which rules this rule descends from. Comma-separated. Root rules declare empty parents.

## State Checks (Preconditions)

**`Given url contains "${pattern}"`** — Assert current URL contains the string.

**`Given url matches "${pattern}"`** — Assert current URL matches the regex.

**`But url does not contain "${pattern}"`** — Negative URL assertion.

**`And selector "${css}" exists`** — Assert a CSS selector matches at least one element on the page.

**`And table headers are "${headers}"`** — Assert table column headers match. Headers are pipe-delimited.

## Actions

**`When I open "${url}"`** — Navigate to URL.

**`When I open the bound field "${field}"`** — Navigate to URL from a consumed/parent record field.

**`When I click locator "${css}"`** — Click an element. Optional continuation rows:
- `type=<real|js>` — click method (real mouse vs JavaScript)
- `delay_ms=<number>` — wait after click
- `uniqueness=<text|css>` — how to track which elements were already clicked

**`When I type "${value}" into locator "${css}"`** — Type text into an input field.

**`When I type secret "${value}" into locator "${css}"`** — Type a secret value (redacted in logs).

**`When I select "${value}" from locator "${css}"`** — Select a dropdown option.

**`When I check locator "${css}"`** — Check a checkbox.

**`When I scroll down`** — Scroll the page down.

**`When I wait for idle`** — Wait for network and animation to settle.

**`When I wait ${ms} ms`** — Wait a fixed duration.

## Expansion

**`When I expand over elements "${scope}"`** — Find all elements matching scope selector; run child rules for each.

**`When I expand over elements "${scope}" with order "${order}"`** — Same, with explicit DFS or BFS traversal order.
- `dfs` (default) — process each element fully before next (streaming)
- `bfs` — collect ALL elements first, then process (required for URL discovery + emit)

**`When I paginate by next button "${css}" up to ${limit} pages`** — Follow next-page links.

**`When I paginate by numeric control "${css}" from ${start} up to ${limit} pages`** — Click numbered page controls.

**`When I expand over combinations`** — Cartesian product of filter axes. Continuation rows define each axis:
- `action=<type|select|checkbox>` — input method
- `control=<css>` — target element
- `values=<val1|val2|...>` or `auto` — values to try

## Extraction

**`Then I extract fields`** — Extract data from the current page/element. Continuation rows define field specs:
- `field=<name>` — output field name
- `extractor=<text|attr|link|html|image|grouped|number|ai>` — extraction method
- `locator=<css>` — target selector

Extractor types:
- **text** — `textContent` of the element
- **attr** — element attribute value (requires `attr=<name>`)
- **link** — `href` attribute of an anchor
- **html** — `innerHTML` of the element
- **image** — `src` attribute of an image
- **grouped** — `textContent` of ALL matching elements, collected into an array
- **number** — `textContent` parsed as a number
- **ai** — see AI Extraction section

**`Then I extract table "${name}" from "${css}"`** — Extract a table using header-based column mapping:
- `field=<name>` — output field name
- `header=<text>` — table header text to match
- `header_row=<number>` — which row contains headers (default 0)

## AI Extraction

**`Then I extract with AI "${name}"`** — Semantic extraction on previously captured text:
- `prompt=<text>` — instruction for the AI model
- `input=<field>` — field name containing source text (from prior extract)
- `schema=<json>` — expected output structure
- `categories=<cat1|cat2|...>` — classification categories

## Emit / Merge / Output

**`And I emit to artifact "${name}"`** — Push extracted fields to named artifact.

**`And I emit to artifact "${name}" flattened by "${field}"`** — Emit with array flattening: one record per array element.

**`And I merge into artifact "${name}" on key "${field}"`** — Merge child data into parent artifact, matching by key field.

**`Then I write artifact "${name}" to "${path}"`** — Write artifact to specific file path.

## Quality Gates

**`And I set quality gate min records to ${count}`** — Fail if fewer than N records extracted.

**`And I set filled percentage for "${field}" to ${percent}`** — Fail if field is less than N% filled.

**`And I set max failed percentage to ${percent}`** — Fail if more than N% of records failed extraction.

## Hooks

**`And I register hook "${name}" at "${point}"`** — Register a lifecycle hook:
- Lifecycle points: `post_discover`, `pre_extract`, `post_extract`, `pre_assemble`, `post_assemble`
- Continuation rows pass hook-specific config

## State Setup

**`Given I configure state setup`** — Pre-scrape setup (auth, consent):
- `skip_when=<url_pattern>` — skip if already in correct state
- `action=open url="<url>"` — navigate
- `action=input css="<selector>" value="<text>"` — fill input
- `action=password css="<selector>" value="<secret>"` — fill password
- `action=click css="<selector>"` — click button

## Interrupts

**`And I configure interrupts`** — Auto-dismiss blocking overlays:
- `dismiss=<css>` — selector for element to dismiss
