# Field Guide — How WISE Profiles Work

This explains the WISE profile schema in plain English. For the formal definition see `runner/src/schema.ts`. For the full annotated example see `guide.md § Profile Schema`.

## The Core Idea

A WISE profile is a graph of **NER (Navigation/Extraction Rule) nodes**. Each node is a deterministic **(state, action) → observation** triple:

```
State  →  Action  →  Observation  →  Expand
"when"    "do"       "read"          "how many successors?"
```

| Part | Schema field | What it answers |
|---|---|---|
| **State** | `state` | "Am I where I expect to be?" — precondition check on page state |
| **Action** | `action[]` | "What do I do?" — click, select, scroll, wait, reveal, navigate, input |
| **Observation** | `extract[]` | "What do I read?" — text, attr, html, link, image, table, grouped, ai |
| **Expand** | `expand` | "How many successor states?" — elements, pages, or combinations |

A node only runs when its **state** checks pass. It executes its **actions**, reads its **observations**, then **expands** to produce successor states. Each successor runs the node's children.

## Profile Structure (top-down)

### Deployment (the whole profile)

```
name → artifacts? → resources[] → quality?
```

- **`name`** — human label for this scraping job
- **`artifacts`** — declared output schemas (exploration agent's contract)
- **`resources`** — list of scraping units, wired via `produces` / `consumes`
- **`quality`** — post-run data validation (min records, max empty %, min filled % per column)
- **`schedule`** — cron or interval-based execution
- **`hooks`** — global lifecycle hooks

### Artifact Schema (exploration agent's output contract)

After exploring a site, the agent knows what data shapes it found. The `artifacts` block declares these explicitly:

```yaml
artifacts:
  product_data:
    fields:
      title:       { type: string, required: true }
      price:       { type: string, required: true }
      description: { type: string, required: true }
      rating:      { type: number, required: false }
    description: "Product listings from the catalog page"
```

Each field has:
- **`type`** — `string` (default), `number`, `boolean`, `array`, `object`
- **`required`** — `true` (default) or `false` — if true, empty/missing values are flagged during extraction

Artifacts can declare **`consumes`** to form a dependency DAG:

```yaml
artifacts:
  page_urls:
    fields:
      url: { type: string, required: true }
  page_content:
    fields:
      title: { type: string, required: true }
      body:  { type: string, required: true }
    consumes: page_urls       # ← runs after page_urls is produced
```

Resources link to artifacts via **`produces`** and **`consumes`**:

```yaml
resources:
  - name: discover
    produces: page_urls       # writes to this artifact
    ...
  - name: extract
    consumes: page_urls       # reads from this artifact
    produces: page_content
    entry:
      url: { from: "page_urls" }   # iterate over URLs in the artifact
    ...
```

The runner resolves execution order automatically (topological sort). Records are validated against the artifact schema as they're extracted — required fields that are missing are flagged immediately.

### Resource (one scraping unit)

```
entry → nodes[] → globals? → setup?
```

- **`entry`** — where to start: a URL + the name of the root node
- **`nodes`** — the NER graph (see below)
- **`globals`** — shared settings: timeout, retries, user agent, request interval, page load delay
- **`setup`** — pre-scrape state setup (auth, locale, currency)
- **`hooks`** — resource-level lifecycle hooks

### NER Node (the core abstraction)

This is the heart of WISE. Each node answers five questions:

1. **Who am I?** → `name`, `parents[]`
2. **Am I in the right state?** → `state` (URL match, element exists, text present, table headers)
3. **What do I do?** → `action[]` (click, select, scroll, wait, reveal, navigate, input)
4. **What do I read?** → `extract[]` (text, attr, html, link, image, table, grouped, ai)
5. **How many successors?** → `expand` (elements, pages, combinations)

### State (preconditions)

State is a set of **checks on the current page**. All specified checks must pass (AND).

- **`url`** / **`url_pattern`** — current URL matches exactly or as a substring
- **`selector_exists`** — a CSS selector is present in the DOM
- **`text_in_page`** — specific text appears on the page
- **`table_headers`** — a table contains these header texts

Think of state as: "I'm on the right page, the right element exists, and the page is in the right state." If state fails, the node is skipped.

### Action (browser primitives)

An ordered list of browser actions executed **before** extraction. Each step is deterministic.

| Action | What it does | Key fields |
|---|---|---|
| **click** | Click a button, link, or header | `click` (Locator), `type` (real/scripted), `uniqueness`, `discard` |
| **select** | Pick a dropdown value | `select` (Locator), `value` |
| **scroll** | Scroll the page | `scroll` (down/up), `px` |
| **wait** | Pause for a condition | `wait` ({ idle: true } or { selector } or { ms }) |
| **reveal** | Show hidden content | `reveal` (Locator), `mode` (click/hover) |
| **navigate** | Go to a URL | `navigate` ({ to: URL }), supports `{field_ref}` |
| **input** | Type into a form field | `input` ({ target, value }) |

### Extraction (observation)

Fields to read from the DOM once actions are complete. Each rule produces a named field in the JSONL output.

| Type | What it reads | Key fields |
|---|---|---|
| **text** | `.textContent.trim()` | `name`, `css`, `regex?` |
| **attr** | `.getAttribute(attr)` | `name`, `css`, `attr` |
| **html** | `.innerHTML` | `name`, `css` |
| **link** | `.getAttribute('href')` | `name`, `css`, `attr?` |
| **image** | `.getAttribute('src')` | `name`, `css` |
| **table** | Header-mapped row objects | `name`, `css`, `columns?`, `header_row?` |
| **grouped** | Multiple elements → array | `name`, `css`, `attr?` |
| **ai** | AI-generated structured data | `name`, `prompt`, `input?`, `schema?`, `categories?` |

**Tables:** always prefer header-based column mapping over positional index.

**AI extraction:** operates on already-extracted text (via `input` field reference), never on live DOM. Uses the abstract `AIAdapter` interface.

### Expansion (successor states)

This is the unifying concept. Instead of separate selector types, **any node can expand**:

| `expand.over` | What it does | Old equivalent |
|---|---|---|
| **elements** | `querySelectorAll(scope)` — one successor per match | `multiple: true` |
| **pages** | Navigate pages — one successor per page | `type: pagination` |
| **combinations** | Cartesian product of axes — one successor per combo | `type: matrix` |

Each expansion type supports **`order: dfs | bfs`**:
- **DFS** (default): process each successor fully before the next. Streams results, uses minimal memory.
- **BFS**: collect all successors first, then process children across all. Good for URL discovery → batch extraction.

#### Element expansion

```yaml
expand:
  over: elements
  scope: "table tbody tr"    # CSS — each match = one successor
  limit: 200                  # optional cap
  order: dfs
```

#### Page expansion

```yaml
expand:
  over: pages
  strategy: next              # next | numeric | infinite
  control: "a.next-page"     # CSS for pagination element
  limit: 10
  stop: ".no-results"        # CSS for stop condition (infinite only)
```

#### Combination expansion

```yaml
expand:
  over: combinations
  axes:
    - action: select
      control: "#brand"
      values: auto            # discover from DOM, or explicit list
    - action: type
      control: "#search"
      values: ["laptop", "tablet"]
```

### Website State Setup

Pre-scrape actions for authentication, locale, currency, etc.

```yaml
setup:
  skip_when: ".logged-in"     # CSS — if found, skip setup
  actions:
    - open: "https://example.com/login"
    - input: { target: { css: "#email" }, value: "user@co.com" }
    - password: { target: { css: "#pass" }, env: "SITE_PASSWORD" }
    - click: { css: "button[type=submit]" }
```

### Quality Gate

Post-run data validation at the deployment level:

```yaml
quality:
  min_records: 50
  max_empty_pct: 5
  max_failed_pct: 10
  min_filled_pct:
    product: 95
    price: 80
```

### Hooks (per-node)

Nodes can declare their own hooks:

- **`hooks.pre_extract`** — runs before this node extracts
- **`hooks.post_extract`** — runs after this node extracts

Per-node hooks fire only when that specific node produces output.

## The NER Graph

Nodes form a **DAG via `parents[]`**. The engine walks this graph top-down:

```
root (entry point)
├── pages (expand: pages — iterates pages)
│   └── rows (expand: elements — iterates table rows)
│       └── extract: [product, price, ...]
└── sidebar (separate branch — extracts metadata)
```

- **`parents`** is explicit — you declare who a node's parent is
- **Children are inferred** — the engine walks all nodes that list a given parent
- Each node fires only when its `state` checks pass
- The graph determines execution order: parent runs first, then children
- **Graph edges are transitions**: a child runs in the state produced by its parent's action

This is what makes the NER model powerful: each node is a self-contained (state, action) → observation triple, and the graph edges encode deterministic state transitions.
