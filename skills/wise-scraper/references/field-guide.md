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
- **`hooks`** — deployment/resource lifecycle hooks

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
- **`type`** — `string` (default), `number`, `boolean`, `array`, `object`, `url`, `binary`
- **`required`** — `true` (default) or `false` — if true, empty/missing values are flagged during extraction

Artifact-level settings:
- **`structure`** — `"nested"` (default) or `"flat"`. Nested writes tree JSON (TreeRecord with children). Flat writes denormalized records (ExtractedRecord). CSV, markdown, and JSONL formats always flatten regardless of this setting.
- **`query`** — optional JMESPath expression applied to tree records before output. Trees are converted to clean documents (data fields at top-level, children keyed by node name). Enables downward denormalization (`[].pages[].books[].{title: title}`) and upward aggregation (`[].pages[].{titles: books[].title, count: length(books)}`). When set, takes precedence over `structure`.
- **`format`** — `"json"` (default), `"jsonl"`, `"csv"`, `"markdown"`
- **`output`** — `true` if this is a final deliverable written to disk
- **`dedupe`** — field name to deduplicate records by

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
      url: "https://example.com{url}"  # template resolved from consumed record
      root: page
    ...
```

The runner resolves execution order automatically (topological sort). Records are validated against the artifact schema as they're extracted — required fields that are missing are flagged immediately.

**Entry URL** — `entry.url` accepts two forms:
- **String template** — `"https://example.com{url}"` with `{field}` placeholders resolved from consumed records
- **Cross-resource reference** — `{ from: "resource.node.field" }` resolves to multiple visit targets by walking the named resource's tree

**Template references** — three scopes for `{...}` placeholders in URLs and navigate targets:
- `{field}` — local context (consumed record data, parent extraction)
- `{artifacts.name.field}` — cross-artifact store reference (latest record)
- `{config.key}` — input config (CLI `--set` or YAML config)

### Resource (one scraping unit)

```
entry → nodes[] → globals? → setup?
```

- **`entry`** — where to start: a URL + the name of the root node. The root node must have `parents: []`.
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
| **click** | Click a button, link, or header | `click` (Locator), `type` (real/scripted) |
| **select** | Pick a dropdown value | `select` (Locator), `value` |
| **scroll** | Scroll the page | `scroll` (down/up), `px` |
| **wait** | Pause for a condition | `wait` ({ idle: true } or { selector } or { ms }) |
| **reveal** | Show hidden content | `reveal` (Locator), `mode` (click/hover) |
| **navigate** | Go to a URL | `navigate` ({ to: URL }), supports `{field_ref}` |
| **input** | Type into a form field | `input` ({ target, value }) |

### Extraction (observation)

Fields to read from the DOM once actions are complete. Each rule produces a named field in the output record.

| Type | What it reads | Key fields |
|---|---|---|
| **text** | `.textContent.trim()` | `name`, `css`, `regex?` |
| **attr** | `.getAttribute(attr)` | `name`, `css`, `attr` |
| **html** | `.innerHTML` | `name`, `css` |
| **link** | attr shortcut: `.getAttribute(attr)` (default `"href"`) | `name`, `css`, `attr?` |
| **image** | attr shortcut: `.getAttribute('src')` | `name`, `css` |
| **table** | Header-mapped row objects | `name`, `css`, `columns?`, `header_row?` |
| **grouped** | Multiple elements → array of strings | `name`, `css`, `attr?` |
| **ai** | AI-generated structured data | `name`, `prompt`, `input?`, `schema?`, `categories?` |

**Tables:** always prefer header-based column mapping over positional index. `table` extraction works both standalone and inside `expand: { over: elements }` scope — the engine compiles it to inline JS scoped to the expanded container. When the `css` selector matches within the container, it extracts from that match; otherwise it treats the container itself as the table.

**Attr vs text:** When an element's visible text is truncated (CSS `text-overflow: ellipsis`) or cluttered by child elements, the full value often lives in the `title` or `aria-label` attribute. During exploration, compare `el.textContent` with `el.getAttribute('title')` to decide. Use `attr` extraction when the attribute is more reliable.

**Relative URLs:** The `link` extraction type uses `getAttribute('href')` which returns the raw attribute value — often a relative path like `/en/docs/page`. When a consuming resource navigates to these URLs, prepend the base URL in the `entry.url` template: `"https://example.com{url}"`. Do NOT rely on the resolved `.href` property.

**AI extraction:** operates on already-extracted text (via `input` field reference), never on live DOM. Uses the abstract `AIAdapter` interface.

**Expand scope vs extract scope:** When using `expand: { over: elements }`, the extract CSS selectors run *relative to each expanded element*. If you expand over `<a>` tags directly and try to extract `link: { css: "a" }`, the extractor looks for `<a>` *children* of the `<a>` and finds nothing. Expand over the parent wrapper instead (e.g., `.link-wrapper:has(a)`).

### Expansion (successor states)

This is the unifying concept. Instead of separate selector types, **any node can expand**:

| `expand.over` | What it does |
|---|---|
| **elements** | `querySelectorAll(scope)` — one successor per CSS match |
| **pages** | Navigate pages — one successor per page (next/numeric/infinite) |
| **combinations** | Cartesian product of filter axes — one successor per combo |

#### BFS vs DFS ordering

Each expansion supports **`order: dfs | bfs`** (default: `dfs`). This controls when children run relative to expansion:

**DFS** (default) — process each successor fully before the next:
```
Expand element 1 → extract → yield → walk children
Expand element 2 → extract → yield → walk children
...
```
Use DFS when: extracting rows from a table, paginating and extracting per page. Records stream out incrementally.

**BFS** — collect ALL successors first, then walk children across all:
```
Expand element 1 → extract → yield
Expand element 2 → extract → yield
...all done...
Walk children for element 1
Walk children for element 2
...
```
Use BFS when: discovering URLs that you'll navigate to later. **BFS is required when a node emits into an artifact that a sibling consumes** — because navigating to a discovered URL would destroy the DOM context needed to discover the next URL.

In the tree model, BFS collects all element trees first (building TreeRecords with data + children), then walks children. The DOM preservation argument is the same: collect all observations from the current page before any child navigates away.

#### BFS × emit: the discovery pattern

```yaml
nodes:
  - name: toc
    parents: [root]
    expand:
      over: elements
      scope: "nav a[href*='/docs/']"
      order: bfs                    # ← MUST be bfs: collect all URLs first
    extract:
      - link: { name: url, css: "a" }
      - text: { name: title, css: "a" }
    emit: page_urls                 # subtree snapshots go into artifact BEFORE children

  - name: pages
    parents: [root]                 # sibling of toc, runs AFTER toc completes
    consumes: page_urls             # iterates over all 80 URLs
    action:
      - navigate: { to: "{url}" }  # {url} from consumed record
    extract:
      - text: { name: title, css: "h1" }
      - html: { name: body, css: ".body" }
    emit: page_content
```

**Ordering rule:** A consuming node must run after its emitting node. For siblings (same parent), this is guaranteed by **YAML declaration order** — nodes listed first are walked first. For cross-resource chaining, the runner resolves order via topological sort on `produces`/`consumes`.

#### Element expansion

```yaml
expand:
  over: elements
  scope: "table tbody tr"    # CSS — each match = one successor
  limit: 200                  # optional cap
  order: dfs                  # process each row fully (default)
```

#### Page expansion

```yaml
expand:
  over: pages
  strategy: next              # next | numeric | infinite
  control: "a.next-page"     # CSS for pagination element
  limit: 25                   # safety cap
  stop:                       # observable completion strategies
    sentinel: ".no-results"   # stop when this element appears
    stable:                   # OR stop when item count stabilizes
      css: ".product-card"
      after: 2                # unchanged for 2 consecutive scrolls
```

**Stop conditions** (composable — first one that triggers wins):

| Strategy | What the exploration agent observed | Map entry |
|---|---|---|
| `sentinel` | "A `.no-results` div appeared" | `sentinel: ".no-results"` |
| `sentinel_gone` | "The loading spinner disappeared" | `sentinel_gone: ".spinner"` |
| `stable` | "Item count stopped changing" | `stable: { css: ".item", after: 2 }` |
| `limit` | Safety net — always present | `limit: 50` |

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

### Emit and Consumes (data flow)

`extract` captures data locally into the node's TreeRecord. `emit` snapshots the node's subtree (its `data` + nested `children`) into named artifact bucket(s). Children without their own `emit` nest inside the parent's tree. Children WITH their own `emit` snip off — they do not appear in the parent's children.

- **`emit: "artifact_name"`** — shorthand: snapshot nested subtree to this artifact
- **`emit: [{ to: "artifact", flatten: ... }]`** — full form: multiple targets with per-target shaping (see Flatten below)
- **`consumes: artifact_name`** — the node runs once per record in the artifact, with that record's fields available as `{field_ref}` in actions

Without `emit`, extracted data flows to children via accumulated context but is NOT written to any artifact.

These work at the **node level** (within a resource) and at the **resource level** (cross-resource):

| Scope | Emit/produces | Consumes | Ordering |
|---|---|---|---|
| Node (intra-resource) | `node.emit` | `node.consumes` | YAML declaration order |
| Resource (cross-resource) | `resource.produces` | `resource.consumes` | Topological sort |

**Key rule:** An artifact that is emitted into with BFS expansion will have ALL records before any consumer reads it. An artifact emitted into with DFS expansion will have records appear incrementally — but sibling consumers still see the full set because they run after the emitting node completes.

**Double-write prevention:** The runner detects when `emit` and `produces` overlap for the same artifact and prevents duplicates automatically.

#### Flatten (three modes)

`flatten` on an emit target controls how the subtree is denormalized into flat records. Three modes:

**`flatten: true`** — denormalize the entire subtree. Interior nodes spread their data as context into leaf records. Only leaves produce output records.

```yaml
emit:
  - to: full_data
    flatten: true               # all leaf records with ancestor context merged in
```

**`flatten: "child_name"`** — flatten only the named child node's records, merging parent context.

```yaml
emit:
  - to: row_data
    flatten: "rows"             # flatten records from the "rows" child node
```

**`flatten: "field_name"`** — unpack an array data field into separate records (the table extraction pattern).

```yaml
extract:
  - table:
      name: salary_data
      css: "table.results"
      columns:
        - name: name
          header: "Name"
        - name: title
          header: "Title"
emit:
  - to: salary_records
    flatten: salary_data        # each row object → one record in salary_records
```

Without `flatten`, the subtree is written as nested TreeRecord JSON. With `flatten`, each leaf or array element becomes its own flat record, merged with accumulated context from ancestors.

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
Deployment/resource hooks use the same hook point names and run around URL discovery and page opening.

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
