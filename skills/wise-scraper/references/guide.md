# WISE Usage Guide

Read this after SKILL.md. This is the essential reference — it gives you the big picture, then the schema, extraction rules, hooks, config, and CLI.

## Big Picture

You are building a **working scraping project** for a JS-rendered site. Here is what's shipped and how the pieces fit:

```
YAML profile  ──→  Zod validation  ──→  Engine  ──→  BrowserDriver  ──→  TreeRecord → Assembly
  (what)            (gate)              (walk)       (browser)          (intermediate)     (final)
```

**Profile** — a declarative YAML file that describes *what* to scrape: which URLs, which NER nodes, what actions, what to extract, how to expand. You build this by assembling composable template fragments from `templates/*.yaml`.

**Schema** — Zod is the single source of truth (`references/runner/src/schema.ts`). It validates profiles at load time, infers TypeScript types, and can export JSON Schema for cross-language use.

**Engine** — walks the NER node graph. For each node: check state → execute actions → extract → expand → recurse children. One unified code path handles all expansion types.

**BrowserDriver** — abstract interface for browser interaction. The shipped `AgentBrowserDriver` uses the `agent-browser` CLI. For production, use `PlaywrightDriver` (import agent-browser's internal Node.js API).

**AIAdapter** — abstract interface for exploitation-phase NLP. The shipped `AIChatAdapter` wraps the `aichat` CLI. AI only operates on already-extracted text, never on the live DOM.

**Templates** — composable fragments in `templates/*.yaml`. They are **not** a menu to pick from. Combine pieces: pagination + table-extract + sort-verify + element-click, etc.

**Hooks** — 5 extension points (post_discover, pre_extract, post_extract, pre_assemble, post_assemble) for site-specific logic the profile can't express declaratively.

**JSON** — the default intermediate output format. A pretty-printed JSON array of records. JSONL (one object per line) is also available via `--output-format jsonl`. Assembly into markdown/CSV is a separate step.

### Decisions you need to make

1. **Runtime** — shipped `agent-browser` driver (default) or alternative?
2. **Tier** — declarative (Tier 1), adapted (Tier 2), bespoke (Tier 3), or alternative runtime (Tier 4)?
3. **AI adapter** — is AI needed for semantic extraction, or are selectors + hooks sufficient?
4. **Hooks** — does the site need custom logic at any of the 5 hook points?

### What to read when

| You need to... | Read |
|---|---|
| Understand the NER model | `references/field-guide.md` |
| See the formal schema | `references/runner/src/schema.ts` |
| See template fragments | `templates/*.yaml` |
| Add AI extraction | `references/ai-adapter.md` |
| Compare runtimes | `references/comparisons.md` |
| See worked examples | `examples/overview.md` |

---

## Profile Schema

A profile is a declarative YAML file. The canonical schema is `references/runner/src/schema.ts` (Zod). See `references/field-guide.md` for plain-English field descriptions.

### Full Schema Structure

```yaml
name: my-scrape-job
resources:
  - name: product_data
    entry:
      url: https://example.com/products
      root: root
    globals:
      timeout_ms: 20000
      retries: 2
    setup:                                  # optional: auth, locale, etc.
      skip_when: ".logged-in"
      actions:
        - open: "https://example.com/login"
        - input: { target: { css: "#user" }, value: "me@co.com" }
        - password: { target: { css: "#pass" }, env: "SITE_PASSWORD" }
        - click: { css: "button[type=submit]" }
    nodes:
      - name: root
        parents: []
        state:
          url_pattern: example.com/products
          selector_exists: table
        action:
          - click:
              css: th.sort-price
            type: real
          - wait: { idle: true }

      - name: pages
        parents: [root]
        expand:
          over: pages
          strategy: numeric
          control: "a.page-link"
          limit: 5

      - name: rows
        parents: [pages]
        expand:
          over: elements
          scope: "table tbody tr"
        extract:
          - text: { name: product, css: "td.name" }
          - text: { name: price, css: "td.price" }
quality:
  min_records: 10
  min_filled_pct:
    product: 90
    price: 80
```

## Data Flow: Tree Records, Artifacts, Emit, Consumes

The engine builds **TreeRecord** objects as it walks the NER graph. Each node's extraction lands in `data`; descendant nodes nest in `children`. Nodes with their own `emit` snip themselves off the parent tree and snapshot into a separate artifact bucket.

```typescript
interface TreeRecord {
  node: string;
  url: string;
  data: Record<string, unknown>;
  children: Record<string, TreeRecord[]>;  // child node name → records
  extracted_at: string;
}
```

Context accumulates top-down: child fields shadow parent fields with the same name. Without `emit`, data flows to children via context but is NOT written to any artifact.

**Artifacts** are named, typed buckets. They serve three purposes:
1. **Validation** — each record checked against declared fields at extraction time
2. **Chaining** — nodes and resources wire together via `emit`/`consumes`
3. **Output** — artifacts marked `output: true` are written as deliverables

### Declaring artifacts

```yaml
artifacts:
  page_urls:
    fields:
      url:   { type: string, required: true }
      title: { type: string, required: true }

  page_content:
    fields:
      title: { type: string, required: true }
      body:  { type: string, required: true }
    consumes: page_urls           # DAG edge: depends on page_urls
    output: true                  # written to disk as final output
    format: markdown              # in this format
```

### Node-level data flow (within a resource)

```yaml
nodes:
  - name: toc
    emit: page_urls               # records go into this artifact
    expand: { over: elements, scope: "nav a", order: bfs }
    extract:
      - link: { name: url, css: "a" }

  - name: pages
    consumes: page_urls           # iterates over artifact records
    action:
      - navigate: { to: "{url}" }
    extract:
      - text: { name: title, css: "h1" }
    emit: page_content
```

### Resource-level data flow (cross-resource)

```yaml
resources:
  - name: discover
    produces: page_urls
    ...
  - name: extract
    consumes: page_urls
    entry:
      url: "https://example.com{url}"   # template resolved from consumed record
      root: page
    produces: page_content
    ...
```

### BFS is required for discovery + emit

When a node discovers URLs on a page and emits them into an artifact, it **must use `order: bfs`**. DFS would navigate away after the first URL, destroying the DOM context for further discovery. BFS collects all records into the artifact first, then children (or sibling consumers) process them.

See `references/field-guide.md § BFS × emit` for a detailed example.

## Extraction Rules

- **DOM eval for live-page extraction.** The driver evaluates JavaScript in the browser context. Do not use HTML parsing libraries for extracting data from the live page.
- **Post-extraction processing is fine.** Once HTML is captured in JSONL, use `cheerio` and `turndown` for transformation, cleanup, and assembly.
- **Header-based mapping for tables.** Map columns by header text, not index.
- **Sort verification** via child node's `state` check — verify the sort applied before extracting.

## Exploration with agent-browser

`agent-browser` is used for both interactive exploration and deterministic execution.

```bash
agent-browser open "https://example.com" --wait networkidle
agent-browser eval "document.querySelector('article')?.tagName"
agent-browser eval -b <base64-encoded-js>    # cross-platform safe
agent-browser click "css=button.next"
agent-browser snapshot --json
agent-browser close
```

**Rule: show exploration evidence before writing any profile.** Evidence means selector output, DOM structure, or snapshots that prove selectors work.

## Hook System

Hooks allow site-specific customization. They run at two levels:

### Global hooks (per-resource)

| Hook Point | When | Use For |
|---|---|---|
| `post_discover` | After URL list is built | Filtering, reordering, manual URL injection |
| `pre_extract` | Before opening a page | Authentication, cookie injection, rate limiting |
| `post_extract` | After raw data captured | AI enrichment, content classification, quality checks |
| `pre_assemble` | Before final assembly | Cross-page link resolution, TOC generation |
| `post_assemble` | After output is built | Format conversion, publishing, validation |

### Per-node hooks

Declared on a specific node. Fire only when that node produces output.

```yaml
nodes:
  - name: rows
    expand:
      over: elements
      scope: "tr"
    extract: [...]
    hooks:
      post_extract:
        - name: ai_adapter.normalize_review
          config:
            schema: { reviewer: string, pros: string[], cons: string[] }
```

### Register via module

```typescript
import type { HookRegistry } from "./hooks.js";

export function registerHooks(registry: HookRegistry) {
  registry.register("post_extract", (record) => {
    record.data.custom_field = "enriched";
    return record;
  }, "my-enrichment");
}
```

## Config Composition

The runner supports Hydra-like config composition via `convict` + `deepmerge`.

Resolution order (later wins):
0. Canonical config (`wise.config.yaml` or `.wiserc.yaml` — auto-loaded if present)
1. Schema defaults (convict)
2. Base profile YAML
3. Override YAML files (`--config extra.yaml`)
4. Environment variables (`WISE_*`)
5. CLI `--set key=value`

## Intermediate Output Format

The engine produces **TreeRecord** objects. The on-disk format depends on the artifact's `structure` setting:

**Nested (default, `structure: "nested"`)** — tree JSON preserving parent/child relationships:

```json
[
  {
    "node": "pages",
    "url": "https://example.com/products?p=1",
    "data": { "page_title": "Products" },
    "children": {
      "rows": [
        {
          "node": "rows",
          "url": "https://example.com/products?p=1",
          "data": { "product": "Widget Pro", "price": "$29.99" },
          "children": {},
          "extracted_at": "2026-03-15T17:00:00.000Z"
        }
      ]
    },
    "extracted_at": "2026-03-15T17:00:00.000Z"
  }
]
```

**Flat (`structure: "flat"`)** — denormalized records. Interior node data spreads as context into leaf records:

```json
[
  {
    "node": "rows",
    "url": "https://example.com/products?p=1",
    "data": { "page_title": "Products", "product": "Widget Pro", "price": "$29.99" },
    "extracted_at": "2026-03-15T17:00:00.000Z"
  }
]
```

CSV, markdown, and JSONL formats always flatten automatically. Use `--output-format jsonl` for streaming/append scenarios.

## Runner CLI Reference

```
node dist/run.js <profile.yaml> [options]

Options:
  --output-dir, -o    Output directory (default: ./output)
  --output-format     json | jsonl | csv | markdown | md  (default: json)
  --hooks             Path to hooks module (.js)
  --set, -s           Override: --set key=value
  --config, -c        Extra config file to merge
  --verbose, -v       Verbose logging
  --dry-run           Parse and validate without executing
  --timeout           Browser timeout in ms (default: 60000)
  --retries           Browser retry count (default: 2)
  --concurrency       Max browser sessions (default: 1)
```

---

## Troubleshooting

Common pitfalls observed during testing, and how to resolve them.

### Text extraction returns truncated values

**Symptom:** `text` extraction on `<a>` or `<span>` tags returns truncated names or labels.

**Cause:** The element's `textContent` is visually truncated via CSS (`text-overflow: ellipsis`), or child elements add noise. The full value often lives in the `title` attribute.

**Fix:** Switch from `text` to `attr` extraction:
```yaml
- attr: { name: full_name, css: "a.item-link", attr: "title" }
```

### Wrong URL variant loaded

**Symptom:** Page structure differs from what exploration found; pagination or filters are missing.

**Cause:** Many sites expose multiple URL variants (e.g., `/products/more/` vs `/products/static/`) with different interaction patterns. The variant you land on depends on the exact URL.

**Fix:** During exploration, verify the exact URL that produces the expected DOM. Record the full URL (including path suffixes) in the profile's `entry.url`.

### Double records in output

**Symptom:** Every record appears twice in the output.

**Cause:** A node declares `emit: "my_data"` AND the resource declares `produces: my_data`. Both write to the same artifact, duplicating records.

**Fix:** The runner now detects and prevents double-writes when `emit` and `produces` overlap for the same artifact. If you still see duplicates, check for multiple emit targets pointing to the same artifact name.

### Expand over leaf elements breaks extraction

**Symptom:** `link` or `text` extraction returns empty/null despite the element being visible on the page.

**Cause:** `expand: { over: elements, scope: "a.link" }` makes each `<a>` the expansion root. Then `extract: [link: { css: "a" }]` looks for an `<a>` child inside that `<a>` and finds nothing.

**Fix:** Expand over the parent wrapper element instead. See SKILL.md "Common Patterns" for the correct pattern.

### Relative URLs cause navigation failures

**Symptom:** Navigate action fails with an invalid URL like `/docs/page` instead of `https://example.com/docs/page`.

**Cause:** `link` extraction uses `getAttribute('href')` which returns the raw relative path.

**Fix:** Prepend the base URL in the entry template or navigate action: `"https://example.com{url}"`.

### Combination expansion does not cover all interaction types

**Symptom:** `expand: { over: combinations }` only supports `select`, `type`, `checkbox`, and `click` axis actions. Some button patterns (e.g., toggle button groups) are not supported.

**Fix:** Use separate click action nodes as a workaround. Define one node per button-group option with explicit click actions, rather than trying to fit them into a combination axis.

### Interrupt handler fires on non-blocking overlays

**Symptom:** The interrupt system detects a dialog or overlay (e.g., Splunk's informational dialog) and pauses execution, even though the overlay does not block scraping.

**Cause:** The trigger selector matches a non-blocking element that appears transiently.

**Fix:** Narrow the interrupt trigger selector to match only truly blocking elements. Add a `skip_when` condition if the overlay auto-dismisses, or use `resolve: click` to dismiss it immediately rather than `resolve: pause`.

### Templates are mental composition, not literal merge

**Symptom:** Agent tries to concatenate YAML files or copy-paste template blocks verbatim.

**Cause:** Templates in `templates/*.yaml` are composable **patterns**, not literal files to merge. They demonstrate idiomatic node structures for common scenarios.

**Fix:** Read template fragments to understand the pattern, then write your profile by composing the relevant patterns. Think of templates as recipes, not ingredients to concatenate.

---

For competitive positioning (vs Crawlee, vs Scrapy+Playwright) and alternative runner backend designs, see `references/comparisons.md`.
