# WISE Design Notes — Artifact Model & MDP State

## The MDP Framing

The entire execution is a Markov Decision Process where:

```
State  = (current_page_DOM, artifact_store, accumulated_context, hook_state)
Action = node's action[] (browser primitives)
Observation = node's extract[] (DOM reads)
Transition = expand + walk children (successor states)
```

Artifacts are part of the state. Hook outputs are part of the state. The accumulated context from ancestor nodes is part of the state. A node's policy (what to do) is conditioned on all of this.

### Key insight: artifacts are saved transition options from unreachable states

You need an artifact when an action both **discovers options** and **navigates away** from them. Clicking a link reveals where to go but also leaves the current page. Selecting a dropdown transforms the page in place — no artifact needed.

| Action | Destroys current DOM? | Need artifact? |
|---|---|---|
| Click link / navigate | Yes | Yes — save URLs before leaving |
| Click pagination "next" | Yes, but children run per page | No — DFS handles it |
| Select dropdown | No — AJAX on same page | No |
| Scroll to load more | No — appends elements | No |

## Issue: Forced BFS/DFS

Currently BFS is "required" on a producer node so consumers see the full artifact. This is our limitation, not the site's.

**Better model:** The consumption mode should be on the consumer, not the producer:

```yaml
# Consumer declares how it reads the artifact
consumes: product_urls
consume_mode: complete    # wait for producer to finish (default, safe)
# OR
consume_mode: eager       # start as soon as first record appears (streaming)
```

With `eager`, the consumer starts iterating records as they appear. The producer keeps yielding. This is the natural streaming model and eliminates forced BFS on the producer.

**When `eager` matters:** Large catalogs where discovery takes minutes. You don't want to wait for all 10,000 URLs before starting extraction.

**When `complete` matters:** When the consumer needs the full set (e.g., counting totals, building a TOC, deduplication).

For now, `complete` is the default and the only implemented mode.

## Issue: Accumulating Context Through the Tree

webscraper.io builds rows by accumulating fields through parent-child descent:

```
category node extracts: { category: "Computers" }
  └── product node extracts: { title: "Lenovo", price: "$299" }
        └── variant node extracts: { color: "Black", hdd: "512GB" }
```

Final row: `{ category: "Computers", title: "Lenovo", price: "$299", color: "Black", hdd: "512GB" }`

This is the **incomplete row** pattern — each node contributes fields to a context that flows down the tree. The final row is emitted by the leaf node and includes all ancestor contributions.

### Current implementation

The engine already does this partially:
- `walkNodeOnce` receives `consumedData` and merges it into extracted records
- `resolveUrl` checks `consumedData` for `{field_ref}` resolution

But this only works for consumed artifact records, not for parent-extracted context.

### What should change

Each node should receive an **accumulated context** from its ancestors:

```typescript
walkNodeOnce(node, allNodes, records, depth, context: Record<string, unknown>)
  // context starts as {} for root node
  // each node's extraction is merged into context before passing to children
  extracted = this.extract(node, indent)
  childContext = { ...context, ...extracted }
  // children receive childContext
```

This means:
- Root extracts `{category}` → context = `{category}`
- Product child extracts `{title, price}` → context = `{category, title, price}`
- Variant grandchild extracts `{color, price}` → context = `{category, title, color, price}` (price overwritten by variant-specific price)
- The JSONL record at each level contains the FULL accumulated context, not just what that node extracted

**This is how "incomplete rows" work.** They're not incomplete — they're accumulating. The leaf node's record has everything.

## Issue: Dimensional Tables (Multiple Concurrent Artifacts)

A user might want:

```
products table:    { id, title, category, base_price }
variants table:    { product_id, color, hdd, variant_price, stock }
images table:      { product_id, image_url }
```

This requires multiple artifacts written from different tree depths in the same walk:

```yaml
nodes:
  - name: product
    emit: products             # writes {id, title, category, base_price}
    extract: [...]

  - name: variants
    parents: [product]
    emit: variants             # writes {product_id, color, hdd, price, stock}
    expand: { over: combinations, ... }
    extract: [...]

  - name: images
    parents: [product]
    emit: images               # writes {product_id, image_url}
    expand: { over: elements, scope: ".gallery img" }
    extract: [...]
```

**All three artifacts are being written to during the same resource execution.** There is no "only one artifact active" constraint. The store is a Map — multiple keys can be appended to concurrently.

The `product_id` in variants and images comes from **accumulated context** — the product node extracted it, and its children inherit it.

## Issue: Deduplication, Revisit, and Loop Guards

### URL deduplication

The engine should track visited URLs per resource:

```typescript
private visited = new Set<string>();

// In runResourceOnce:
if (this.visited.has(url)) {
  console.log(`[engine] Skipping already visited: ${url}`);
  return [];
}
this.visited.add(url);
```

### Artifact deduplication

The store should optionally deduplicate records by a key field:

```yaml
artifacts:
  product_urls:
    fields:
      url: { type: string, required: true }
    dedupe: url              # ← deduplicate by this field
```

### Loop guards

The node-level topological sort already detects static cycles. For dynamic loops (a page links back to itself), the URL dedup handles it. For expansion loops (infinite scroll that never stops), the `stop` condition and `limit` field are the guards.

## Issue: produces/consumes as arrays and glob patterns

```yaml
# A node that emits to two artifact streams
- name: product_page
  emit:
    - { to: product_data }
    - { to: product_images }

# A resource that consumes all section artifacts
- name: assembler
  consumes: "section_*"           # glob: match section_overview, section_manual, etc.
```

When consuming a glob, the runner resolves matching artifact names at execution time and merges their records in artifact-creation order.

## Issue: Default emit inference

If a node has `extract` but no `emit`, and the resource has `produces`:
- The node's records go into the resource's `produces` artifact
- This is the common case — one flat table per resource

If a node has explicit `emit`, it overrides the default:
- The node writes to its specified artifact instead
- The resource's `produces` may still receive records from other nodes

## Issue: Noop extraction

A node with no `extract` is a pure state transition (action only). This is already valid — no change needed. But it should be clearly documented: "A node without `extract` contributes its action to the MDP state but produces no records."

If a node has `extract: []` (empty array), treat it the same as no extract.

## Issue: CAPTCHA / interrupts as MDP hooks

Interrupts are reactive policies that fire on state predicates, orthogonal to the main node graph:

```yaml
interrupts:
  - name: cookie_consent
    trigger: "[class*='cookie'] button[class*='accept']"
    resolve: click_trigger       # click the trigger element itself
    scope: global                # fires for any resource

  - name: recaptcha
    trigger: ".g-recaptcha"
    resolve: ai                  # screenshot → AI adapter → solve
    scope: resource              # only for this resource

  - name: hard_captcha
    trigger: ".captcha-drag"
    resolve: pause               # stop, require human intervention
    scope: resource
```

Resolution strategies:
- `click_trigger` — click the matched element (cookie dismiss)
- `click: "css"` — click a specific element
- `script: "js"` — run JS
- `ai` — send screenshot to AI adapter for solving
- `wait: ms` — wait and hope it auto-resolves (Cloudflare)
- `pause` — stop execution, wait for human

Scope:
- `global` — checked after every action in every resource
- `resource` — checked only during this resource's execution

## Test Results Summary

### Emit semantics validation (v2.0 — 2026-04-02)

Eight test runs validated the emit/flatten rewrite and end-to-end skill workflow.

**Runner-only tests (pre-written profiles):**

| # | Test | Records | Result | Bugs found |
|---|------|---------|--------|------------|
| 1 | Laptop simple | 117 | PASS | — |
| 2 | Laptop paginated | 117 / 20pp | PASS | — |
| 3 | Revspin sort+paginate | 200 / 2pp | PASS | — |
| 4 | Variants AJAX (chaining) | 24 (6×4) | PASS | Quality gate checked raw engine records instead of artifact store |
| 5 | Splunk docs (chaining) | 9pp / 86KB | PASS | Stale DOM selector (`div.toc` → `.toc-item-wrapper`) |
| 6 | UM Salary (flatten) | 77 flat | PASS | Same quality gate bug as #4 |
| 7 | Amazon matrix (brand filters) | 288 (3×2×48) | PASS | Brand context not propagated to child resource walk |

**End-to-end skill tests (agent explores + generates + validates + runs):**

| # | Test | Agent A (explore) | Hard gate (dry-run) | Agent B (run) | Notes |
|---|------|-------------------|--------------------|----|-------|
| 8 | Books to Scrape (Mystery) | PASS | PASS | PASS (32 records) | Agent correctly chose attr for title (truncation) and rating (CSS class) |
| 9 | Tables | PASS | PASS | FAIL | Hit table-in-expand limitation; doc gap found and fixed |

**Bugs fixed:**
1. Quality gate checked raw engine records instead of artifact store for output artifacts — flatten produced 77 flat records in the store but quality saw 3 nested engine records. Fixed in run.ts.
2. Consumed data context not propagated into resource walk — `runResourceOnce` passed `{}` instead of `consumedData` to `walkNode`. Fixed in engine.ts.

**Doc gaps found and fixed:**
1. `table` extraction inside `expand: elements` scope returns stub — documented in field-guide and troubleshooting.
2. Splunk help site changed DOM — `div.toc` → `.toc-item-wrapper`.

### Original test runs (v2.0 development — 2026-03)

Five end-to-end test runs validated the WISE framework against real scraping targets. Each tested a different capability surface.

### Test 1: Simple extract (117 records)

**What it tested:** Basic element expansion and extraction from a single page.

**Findings:**
- Agent needed guidance on `attr` vs `text` extraction. Text on `<a>` tags was truncated; the `title` attribute had the full name. Added attr-vs-text tip to field-guide and SKILL.md common patterns.
- Template paths in SKILL.md were relative and confusing when the agent's working directory differed from the skill directory. (Addressed by using consistent reference paths.)

### Test 2: Paginated extract (117 records across 20 pages)

**What it tested:** Page expansion with numeric pagination strategy.

**Findings:**
- Agent initially opened the wrong URL variant (`/more/` vs `/static/`). Different URL variants expose different interaction patterns (JS-heavy vs static). Added troubleshooting entry about URL variant selection.
- Templates are "mental composition" not literal file merging. Agent tried to concatenate YAML files. Clarified in troubleshooting that templates are composable patterns.

### Test 3: Sort-then-extract (200 records)

**What it tested:** Navigation-based sorting followed by paginated extraction.

**Findings:**
- Sort was navigation-based (clicking a sort link changes the URL, e.g., `?sort=price`), not JS-based. The child node's `state.url_pattern` check on the new URL implicitly verified the sort. Documented as a common pattern in SKILL.md.
- No issues with the pagination or extraction phases.

### Test 4: Variant combinations (18 records)

**What it tested:** Combination expansion across filter axes, plus cross-resource artifact chaining.

**Findings:**
- Combination expansion only supports `select`/`type`/`checkbox`/`click` axis actions. Agent needed 3 separate click nodes as a workaround for unsupported button-group patterns. Now documented; click axis support addresses this.
- Relative URLs from `link` extraction required prepending the base URL in the entry template. Confirmed as a recurring pattern (also in Test 5). Added to common patterns.
- Using both `emit` and `produces` for the same artifact caused double records. Already documented in field-guide; added to troubleshooting for discoverability.

### Test 5: Multi-page documentation scrape (9 pages, 86KB markdown)

**What it tested:** BFS URL discovery, cross-resource artifact chaining, HTML-to-markdown assembly.

**Findings:**
- Expanding over `<a>` tags directly broke extraction (extractor looked for `<a>` inside `<a>`). Must expand over parent wrapper. Already documented in field-guide; reinforced in SKILL.md common patterns.
- Relative URL issue confirmed (same as Test 4).
- Interrupt handler false-positive: Splunk's informational dialog overlay triggered the interrupt system even though it did not block scraping. Added troubleshooting entry about narrowing interrupt trigger selectors.

### Cross-cutting lessons

1. **Attr vs text** is a recurring decision — always check attributes during exploration.
2. **Relative URLs** from `link` extraction are the default; always template with base URL.
3. **Expand over wrappers** not leaves is a firm rule, not a suggestion.
4. **URL variant selection** matters — verify the exact URL during exploration.
5. **Templates are patterns** to compose mentally, not files to concatenate.

## Worked Example: Multi-Level Catalog

See the e-commerce full catalog example in this directory for a complete
profile with 3 resources (categories → products → variants), artifact
chaining, combination expansion, and accumulated context flow.

The MDP state trace shows how artifacts grow at each phase and how the
runner conditions its policy on accumulated state.
