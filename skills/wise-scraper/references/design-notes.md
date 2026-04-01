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
    yields: products           # writes {id, title, category, base_price}
    extract: [...]

  - name: variants
    parents: [product]
    yields: variants           # writes {product_id, color, hdd, price, stock}
    expand: { over: combinations, ... }
    extract: [...]

  - name: images
    parents: [product]
    yields: images             # writes {product_id, image_url}
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
# A node that produces two artifact streams
- name: product_page
  yields: [product_data, product_images]

# A resource that consumes all section artifacts
- name: assembler
  consumes: "section_*"           # glob: match section_overview, section_manual, etc.
```

When consuming a glob, the runner resolves matching artifact names at execution time and merges their records in artifact-creation order.

## Issue: Default yields inference

If a node has `extract` but no `yields`, and the resource has `produces`:
- The node's records go into the resource's `produces` artifact
- This is the common case — one flat table per resource

If a node has explicit `yields`, it overrides the default:
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

## Worked Example: Multi-Level Catalog

See the e-commerce full catalog example in this directory for a complete
profile with 3 resources (categories → products → variants), artifact
chaining, combination expansion, and accumulated context flow.

The MDP state trace shows how artifacts grow at each phase and how the
runner conditions its policy on accumulated state.
