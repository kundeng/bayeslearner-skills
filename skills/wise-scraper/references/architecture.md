# WISE Runner — Internal Architecture & Code Reference

This document describes the runner's actual data model, runtime behavior, and design decisions. It is written for a developer maintaining or extending the code. Every claim is backed by code references.

**Part I: Architecture** — Data model, runtime flow, design analysis, simulations.
**Part II: Code Reference** — File-by-file breakdown, execution pipeline, gotchas.

---

# Part I: Architecture

---

## 1. Static Data Model

### 1.1 The Record Shape

Everything in the system produces `ExtractedRecord` objects (schema.ts:419+):

```typescript
type ExtractedRecord = {
  node: string;           // which node extracted this
  url: string;            // current page URL at extraction time
  data: Record<string, unknown>;  // the payload — flat key-value
  extracted_at: string;   // ISO timestamp
}
```

**This is always flat.** The `data` field is a `Record<string, unknown>` — a bag of named values. There are no nested record types. There is no tree structure in the output. Every extraction, regardless of how deep in the NER graph, produces a flat record with ALL accumulated context fields merged in.

### 1.2 How Context Accumulates

Context is a `Record<string, unknown>` that grows as the engine walks deeper into the graph. At `walkNodeOnce` (engine.ts:250):

```typescript
const extracted = this.extract(node, indent);
const childContext = extracted ? { ...context, ...extracted } : context;
```

The spread means: **child fields shadow parent fields with the same name.** If a parent extracts `{ price: "$base" }` and a child extracts `{ price: "$variant" }`, children see `$variant`. There is no namespacing — it's flat accumulation with last-write-wins.

When a record is created (engine.ts:253-254):

```typescript
const data = { ...context, ...extracted };
let record = this.makeRecord(node.name, data);
```

The record's `data` contains EVERYTHING from all ancestors plus the current node's extraction. This means leaf records in a deep graph can be wide (many fields), and intermediate records from parent nodes will be subsets.

### 1.3 The ArtifactStore

The store is `Map<string, ExtractedRecord[]>` (store.ts:34). Nothing more. It has:

- **`put(name, records[])`** — append + validate against declared schema
- **`get(name)`** — return all records for an artifact
- **`resolveOrder(profile)`** — Kahn's algorithm over `produces`/`consumes` edges

Validation is **advisory** — it logs warnings but still stores the records (store.ts:56). A validation failure does NOT prevent records from being written.

### 1.4 What "Declared Artifacts" Actually Are

Artifacts in the profile (schema.ts:341-348) are a contract:

```yaml
artifacts:
  page_urls:
    fields:
      url: { type: string, required: true }
    output: false     # internal plumbing
  page_content:
    fields:
      title: { type: string, required: true }
    output: true      # written to disk
    format: markdown
```

At runtime, they map to named slots in the `ArtifactStore`. Records are plain `ExtractedRecord[]` — the schema fields are only used for validation warnings, not for shaping or filtering the data. A record can have extra fields beyond what the schema declares; those are silently passed through.

---

## 2. Runtime Data Flow

### 2.1 The Two Data Paths

There are exactly two ways data moves through the system:

**Path A: Context accumulation (implicit, tree-scoped)**
```
parent.extract → { ...parentContext, ...parentExtracted }
  → child.extract → { ...parentContext, ...parentExtracted, ...childExtracted }
    → grandchild.extract → { ...all above, ...grandchildExtracted }
```
This is the call-stack path. Data flows DOWN through the tree via function arguments. It is never stored persistently. When the walk unwinds, this data is gone (except what was captured in records pushed to the `records[]` array).

**Path B: Artifact store (explicit, declared)**
```
node.emit → store.put("artifact_name", [record])
  ... later ...
otherNode.consumes → store.get("artifact_name") → iterate
```
This is the persistent path. Data is written to a named Map slot and read back later. This is the ONLY way data crosses between resources or between sibling subtrees that don't share an ancestor-descendant relationship.

### 2.2 How `records[]` Works

The `records` array is a **mutable accumulator** passed by reference through the entire walk. Every node that extracts data pushes to it (engine.ts:256, 680, 692). At the end of `runResourceOnce`, this array is returned as the resource's output.

This is a single flat list. It does NOT preserve tree structure. A record from a deeply nested node sits next to a record from a root node. The only way to tell them apart is the `node` field on the record.

**Critical implication:** The `records[]` array and the artifact store are **separate worlds**. Records are always pushed to `records[]`. They are ADDITIONALLY written to the store only if the node declares `emit`. The quality gate in `run.ts` checks the store (not `records[]`) when output artifacts exist, because `emit` with `flatten` reshapes the data (3 engine records with table arrays → 77 flat store records).

### 2.3 Simulation: BFS Element Expand + Emit

Profile fragment:
```yaml
- name: toc
  expand: { over: elements, scope: "nav a", order: bfs }
  extract:
    - link: { name: url, css: "a" }
    - text: { name: title, css: "a" }
  emit: page_urls

- name: pages
  consumes: page_urls
  action:
    - navigate: { to: "{url}" }
  extract:
    - text: { name: body, css: ".content" }
```

**Step-by-step execution:**

```
1. Engine enters toc node
2. expandElements (BFS branch, engine.ts:672)
3.   extractMultiple("nav a", [link, text]) → browser eval
     → returns [{url:"/p1", title:"P1"}, {url:"/p2", title:"P2"}, {url:"/p3", title:"P3"}]
4.   BFS COLLECT PHASE:
     for each row:
       context = { ...parentCtx, url:"/p1", title:"P1" }
       record = makeRecord("toc", context)
       records.push(record)                    ← into flat array
       emitToArtifacts → store.put("page_urls", [record])  ← into store
       batch.push({ record, childCtx: context })
     (repeat for /p2, /p3)
     
     STATE AT THIS POINT:
       records[] = [rec1, rec2, rec3]          (3 records)
       store["page_urls"] = [rec1, rec2, rec3] (3 records)
       DOM is still intact — no navigation yet

5.   BFS DESCEND PHASE:
     for each batch item:
       walkChildren("toc", ..., childCtx)
       → finds "pages" node (child of toc? NO — see below)
```

**Wait — `pages` is NOT a child of `toc`.** In the profile, `pages` has `parents: [root]` (sibling of toc), not `parents: [toc]`. The engine walks children of toc (none), then moves to the next child of root: `pages`.

```
6. Engine enters pages node (next sibling under root)
7. walkNode checks: consumes: "page_urls"
     consumed = store.get("page_urls") → [rec1, rec2, rec3]
8. For each consumed record:
     mergedContext = { ...parentCtx, url:"/p1", title:"P1" }
     walkNodeOnce(pages, ..., mergedContext)
       → executeAction: navigate { to: "{url}" }
         → resolveUrl("{url}", records, context)
         → context.url = "/p1" → open "https://base/p1"
       → extract: text { name: body, css: ".content" }
         → data = { ...context, body: "..." }
         → records.push(makeRecord("pages", data))
```

**Key insight from this simulation:** BFS matters because `extractMultiple` runs a SINGLE browser eval that returns all rows. The DOM is read once, all data collected, all records emitted. Only then do children (or later siblings) run and potentially navigate away.

With DFS, the descend phase runs INSIDE the collect loop (engine.ts:687-695): extract row 1, walk children (which consumes and navigates), extract row 2 — but row 2's DOM context may be destroyed.

### 2.4 Simulation: Flatten

Profile fragment:
```yaml
- name: results_table
  extract:
    - table: { name: salary_data, css: "table", header_row: 1,
               columns: [{name: name, header: "Name"}, {name: title, header: "Title"}] }
  emit:
    - to: salary_records
      flatten: salary_data
```

**Step-by-step:**

```
1. extract() runs domTable → returns array:
   salary_data = [{name:"Alice", title:"Prof"}, {name:"Bob", title:"Asst"}]

2. Record created: data = { ...context, salary_data: [{...}, {...}] }
   records.push(record)  ← ONE record with nested array

3. emitToArtifacts (engine.ts:286-297):
   target.flatten = "salary_data"
   arrayVal = record.data["salary_data"] = [{name:"Alice",...}, {name:"Bob",...}]
   
   For each element:
     rowData = { ...context, name:"Alice", title:"Prof" }
     → makeRecord("results_table", rowData)
   
   store.put("salary_records", [flatRec1, flatRec2])

STATE:
  records[] = [1 record with salary_data array]
  store["salary_records"] = [2 flat records]
```

This is why the quality gate checks the store (run.ts:343-346): the engine produced 1 nested record, but the deliverable has 2 flat records.

---

## 3. BFS vs DFS: Internal Data Structures

You asked: "supporting dfs and bfs requires different internal data structures."

**Answer: No, they use the same structures.** The difference is purely control flow — when `walkChildren` is called relative to the extraction loop.

Both paths use:
- `records: ExtractedRecord[]` — same mutable flat array
- `context: Record<string, unknown>` — same accumulated context object
- `store: ArtifactStore` — same Map

The BFS branch (engine.ts:672-685) adds one temporary structure:
```typescript
const batch: Array<{ record: ExtractedRecord; childCtx: Record<string, unknown> }> = [];
```

This `batch` array holds the extraction results so children can be walked AFTER all elements are processed. In DFS, there is no batch — children run inline.

**The real question you're asking:** "Is the output a single nested JSON or multiple flat JSON records?"

The answer: **Always multiple flat records.** The `records[]` array is a flat list of `ExtractedRecord` objects. Each record's `data` is flat key-value. There is no nesting in the output structure. The only case where `data` contains a non-primitive is table extraction, where a field holds `Record<string, string>[]` — but `flatten` in emit unpacks that into separate records.

The intermediate output (what gets written to disk) is:
```json
[
  { "node": "rows", "url": "...", "data": { "title": "X", "price": "Y" }, "extracted_at": "..." },
  { "node": "rows", "url": "...", "data": { "title": "A", "price": "B" }, "extracted_at": "..." }
]
```

A flat JSON array of flat records. Period.

---

## 4. Extraction Types: attr vs text

You asked: "the distinction of attr vs text is weird."

Here's what each does in the engine:

**`text`** (engine.ts:506-508):
```javascript
el.textContent.trim()
```
Reads the DOM's `.textContent` — all text nodes concatenated, including child element text. Then `trim()`.

**`attr`** (engine.ts:514-515):
```javascript
el.getAttribute('title')
```
Reads a specific HTML attribute value.

**`link`** (engine.ts:520-521):
```javascript
el.getAttribute('href')   // default attr
```
Syntactic sugar for `attr` with `attr` defaulting to `"href"`.

**`image`** (engine.ts:523-524):
```javascript
el.getAttribute('src')
```
Syntactic sugar for `attr` with `attr` hardcoded to `"src"`.

**`html`** (engine.ts:517-518):
```javascript
el.innerHTML
```
Reads raw HTML content. No sanitization whatsoever.

### The Real Problem

You're right that this is weird. The issues:

1. **`text` has no sanitization option.** `textContent` can include invisible text from hidden child elements, SVG titles, aria-labels embedded in the DOM. The `regex` option lets you post-filter with a pattern, but there's no "strip whitespace", "collapse spaces", or "take only visible text" option.

2. **`attr` vs `text` is a DOM API distinction, not a data modeling distinction.** From the profile author's perspective, they want a string value for a field called "title". Whether it comes from `.textContent` or `.getAttribute('title')` is an implementation detail of where the site puts the data.

3. **No sanitization layer.** There's no concept of "this field should be cleaned" between extraction and storage. The engine reads raw DOM values and stores them as-is. Any cleanup happens either:
   - In `post_extract` hooks (but those are per-record, not per-field)
   - In `processing.ts` at assembly time (but only for HTML→markdown)

4. **`link` and `image` are just attr with defaults** — they could be collapsed into `attr` with a `default_attr` field, but they exist for profile readability.

### What Would Be Better

A unified extraction model might look like:

```yaml
extract:
  - field: title
    from: attr        # or: text, html, computed
    css: "h1 a"
    attr: title       # only when from: attr
    sanitize: trim    # trim | collapse_whitespace | strip_html | none
```

But this would be a schema-breaking change. The current model works; it's just not self-documenting about *why* you'd pick one over the other. The real issue is that the docs don't explain the DOM semantics clearly enough.

---

## 5. Sort Verification

You asked: "what do you mean sort is navigation based, or JS-based?"

Sort verification in WISE is **state-based, not action-based.** The engine doesn't verify sorting itself — it relies on the NER state machine pattern:

1. **Parent node** executes a sort action (click a column header)
2. **Child node** checks state to verify the sort took effect

Example:
```yaml
- name: sort_price
  action:
    - click: { css: "th.price" }  # JS-based: browser executes click
    - wait: { idle: true }

- name: verify_sorted
  parents: [sort_price]
  state:
    selector_exists: "th.price.sorted-asc"  # State check: is the sort indicator present?
  extract: [...]
```

The click at `sort_price` is **JS-based** — the `AgentBrowserDriver` calls `agent-browser click "css=th.price"` which uses Playwright's click method (goes through the browser event system). But the verification is a **DOM state check** — the engine evals `document.querySelector("th.price.sorted-asc")` and skips the node if it's missing.

There's no option for **DOM-based sorting** (reordering elements in JS). The sorting is always done by the site's JavaScript in response to user interaction. The engine just clicks and checks.

The `state.table_headers` check (engine.ts:376-384) is another verification pattern — you can assert that specific headers exist, which proves you're looking at the right table after a sort/filter operation.

---

## 6. URL Templates and Context Interpolation

You asked: "maybe we should allow context interpolation from previous nodes?"

**It already works.** The `resolveUrl` method (engine.ts:477-495) checks two sources:

```typescript
private resolveUrl(template: string, records: ExtractedRecord[], context?: Record<string, unknown>): string {
  return template.replace(/\{(\w+)\}/g, (_match, field: string) => {
    // 1. Accumulated context (ancestors + consumed data)
    if (context) {
      const val = context[field];
      if (val !== undefined && val !== null) return String(val);
    }
    // 2. Fall back to most recent record
    for (let i = records.length - 1; i >= 0; i--) {
      const val = records[i].data[field];
      if (val !== undefined && val !== null) return String(val);
    }
    return `{${field}}`;
  });
}
```

Source 1 is **accumulated context** — this includes all fields extracted by ancestor nodes AND all fields from consumed artifact records. If a grandparent node extracted `{ base_url: "https://example.com" }`, a grandchild's navigate action can use `{base_url}`.

Source 2 is **record history fallback** — it scans the `records[]` array in reverse (most recent first) looking for any record that has the field. This is a last resort and can be unpredictable because it depends on execution order.

The `resolveTemplate` method (engine.ts:145-149) is the same but only checks the `data` argument (used for entry URL resolution from consumed records).

### What's Actually Missing

The URL template system has one gap: **entry URLs for consumed resources.** When a resource declares `consumes: page_urls`, the entry URL template `"https://example.com{url}"` is resolved from the consumed record's data (engine.ts:96-106). But it can ONLY reference fields from the consumed record — it cannot reference other artifacts or global config values.

For example, you can't do:
```yaml
entry:
  url: "{base_url}{path}"  # base_url from one artifact, path from another
```

The workaround is to emit a combined artifact that has all needed fields, or use a hook to construct the URL.

---

## 7. Extraction Inside Element Expansion

When a node has `expand: { over: elements }`, extraction works differently than without expand.

**Without expand** (engine.ts:499-549): Each extraction rule makes a separate `driver.evalJson` call — one shell exec per field. For 5 fields on 100 rows, that's 500 shell commands.

**With expand** (engine.ts:699-728): ALL extraction rules are compiled into inline JS and run in a single `evalJson` call:

```javascript
(() => {
  const rows = [...document.querySelectorAll('scope')];
  return rows.map(container => {
    const result = {};
    result['title'] = container.querySelector('h2')?.textContent?.trim() || '';
    result['price'] = container.querySelector('.price')?.textContent?.trim() || '';
    return result;
  });
})()
```

This is the `extractMultiple` method. The `extractionToJs` method (engine.ts:975) compiles each rule to inline JS. The variable `container` scopes extraction to the matched element.

**This is why the table-in-expand fix mattered** — `extractionToJs` previously returned a stub for table rules. Now it compiles the full table extraction logic using `container` instead of `document`.

---

## 8. The Driver Abstraction

The `BrowserDriver` interface (driver.ts) defines:
```
open(url), click(locator), select(locator, value), type(locator, value),
scroll(dir, px), wait(condition), eval(js), evalJson<T>(js),
exists(selector), getUrl(), close(), hover(locator)
```

The shipped `AgentBrowserDriver` (agent-browser-driver.ts) implements this by shelling out to `agent-browser` CLI via `execSync`. Every operation is a synchronous subprocess call. There is no persistent browser connection — each call starts a process, does one thing, and exits.

Session persistence is handled by `agent-browser` itself — the `--session` flag keeps Playwright's browser context alive between calls.

**Performance implication:** Each extraction field without element expansion costs one `execSync` call (~50-100ms overhead). With element expansion, all fields are batched into one call. This is why `extractMultiple` exists — it's a 10-100x speedup for element-scoped extraction.

---

## 9. Summary of Internal Invariants

| Property | Guarantee |
|----------|-----------|
| Record shape | Always `ExtractedRecord` — flat `data: Record<string, unknown>` |
| Context flow | Ancestor fields accumulate, children shadow with same-name keys |
| BFS vs DFS | Same data structures, different control flow (batch vs inline children) |
| Store validation | Advisory only — records are stored even on validation failure |
| Extraction scope | Without expand: one eval per field. With expand: one eval for all fields×elements |
| Output format | Flat JSON array of records (default). JSONL available via flag. |
| Template resolution | Context first, then record history fallback. Unresolved = literal `{field}` left in string |
| Double-write prevention | run.ts checks if nodes already emit to an artifact before resource-level store.put |

---

# Part II: Code Reference


## 1. File-by-File Breakdown

### schema.ts — The Type System

**Purpose:** Single source of truth for every data structure in the system. All types are defined as Zod schemas that serve triple duty: runtime validation, TypeScript inference, and (potentially) JSON Schema export.

**Key schemas and line numbers:**

| Schema | Lines | Purpose |
|--------|-------|---------|
| `Locator` | 15-22 | CSS/text/role selector with refinement requiring at least one |
| `WaitCondition` | 24-28 | Union: `{idle}`, `{selector}`, `{ms}` |
| `StopCondition` | 39-49 | Sentinel/stable/limit for expansion halting |
| `ClickAction` | 53-59 | Includes `uniqueness` and `discard` fields for dedup |
| `ScrollAction` | 67-73 | `scroll: "to"` variant has `target` + `ready` sub-fields |
| `Extraction` | 190-199 | Union of 8 extraction types: text, attr, html, link, image, table, grouped, ai |
| `ElementExpand` | 203-208 | `over: "elements"`, CSS scope, optional limit |
| `PageExpand` | 210-218 | `over: "pages"`, strategy enum, control CSS, StopCondition |
| `CombinationExpand` | 226-229 | `over: "combinations"`, array of Axis |
| `Emit` | 276-279 | Union of string shorthand or `EmitTarget[]` |
| `NER` | 283-317 | The core node: state, action[], extract[], expand, emit, consumes, retry, hooks |
| `Resource` | 352-372 | Groups nodes with entry URL, globals, setup, hooks |
| `Deployment` | 385-403 | Top-level: artifacts, resources[], quality gate, schedule |
| `ExtractedRecord` | 429-434 | Interface (not Zod): `{node, url, data, extracted_at}` |

**Data structure shapes worth memorizing:**

```ts
// ExtractedRecord — the universal intermediate format
{
  node: string;           // which NER node produced this
  url: string;            // page URL at extraction time
  data: Record<string, unknown>;  // the actual extracted fields
  extracted_at: string;   // ISO timestamp
}

// Emit — the two forms
emit: "artifact_name"                        // string shorthand
emit: [{ to: "artifact", flatten: "field" }] // full form

// StopCondition — all optional, first trigger wins
{
  sentinel?: string;       // CSS — stop when appears
  sentinel_gone?: string;  // CSS — stop when disappears
  stable?: { css: string; after: number };  // stop when count plateaus
  limit?: number;          // hard cap (default 50)
}
```

**Connections:** Imported by every other file. No imports from other project files.

**Tricky parts:**
- `Locator` has a `.refine()` (line 22) that requires at least one of `css`, `text`, or `role`. This means empty locators fail Zod validation, not TypeScript type-checking.
- `ClickAction.discard` (line 57) has three modes but the engine never references it. It appears to be a future/unused schema field.
- `ClickAction.uniqueness` (line 56) is similarly declared but not consumed by engine code.
- `TableColumn` (lines 157-161) allows either `header` or `index` — the engine handles both in the generated JS, but the Zod schema does not enforce that at least one is present.

---

### driver.ts — The Abstract Interface

**Purpose:** Defines the `BrowserDriver` interface and two helper functions. The engine never touches browser internals — everything goes through this interface.

**Key exports (lines 1-75):**

| Export | Line | Purpose |
|--------|------|---------|
| `DriverWait` type | 18-20 | Union: `{idle}`, `{selector}`, `{ms}` |
| `BrowserDriver` interface | 25-55 | 13 methods: lifecycle, DOM eval, interaction, observation |
| `locatorToSelector()` | 60-68 | Converts `Locator` → string. CSS passes through, text/role get prefixed |
| `escapeJs()` | 72-74 | Escapes `\`, `'`, and `\n` for single-quoted JS strings |

**Connections:** Imported by `engine.ts`, `agent-browser-driver.ts`, `interrupts.ts`.

**Key design decision:** All methods are **synchronous**. The doc comment (lines 7-12) explains: the underlying impl handles async internally, the NER walk is sequential within a resource, parallelism is at the resource level.

**Tricky parts:**
- `locatorToSelector` produces `text=...` and `role=...` prefixed strings (lines 63-66). These are Playwright-style selectors, but `agent-browser-driver.ts` passes them directly to the CLI — compatibility depends on the CLI understanding this format.
- `escapeJs` (line 72-74) only handles single quotes, backslashes, and newlines. See [Gotchas](#6-known-gotchas-and-sharp-edges).

---

### config.ts — Configuration Composition

**Purpose:** Hydra-like config composition layer. Composes configuration from 5 sources in priority order (lines 16-21):

```
0. Canonical config (wise.config.yaml or .wiserc.yaml)
1. Schema defaults (convict)
2. Base profile YAML
3. Override YAML files (--config)
4. Environment variables
5. CLI --set overrides
```

**Key functions:**

| Function | Lines | Purpose |
|----------|-------|---------|
| `loadConfig()` | 133-214 | Main entry: parses argv, builds convict, deep-merges, validates |
| `parseCustomArgs()` | 227-266 | Pre-convict arg parser for `--set`, `--config`, `-o` aliases |
| `parseValue()` | 276-289 | String → typed value: `[a,b,c]` → array, `true` → boolean, numeric strings → number |
| `setNestedValue()` | 295-306 | Dot-notation setter: `inputs.queries` → nested object path |

**The convict schema** (lines 34-95) defines 9 runner-level settings: `profile`, `outputDir`, `outputFormat`, `hooks`, `verbose`, `dryRun`, `concurrency`, `timeout`, `retries`.

**ResolvedConfig shape** (lines 117-121):
```ts
{
  runner: RunnerConfig;   // convict-validated settings
  inputs: InputConfig;    // user-facing params from profile.inputs or profile._inputs
  profile: Record<string, unknown>;  // raw merged profile data
}
```

**Connections:** Imported only by `run.ts`. No downstream imports.

**Tricky parts:**
- `parseCustomArgs` (lines 227-266) handles short aliases (`-o`, `-v`, `-s`, `-c`) **before** convict sees the args. Convict only processes long-form flags like `--output-dir`. The short alias `-o` is handled manually at line 248-249 by stuffing into `cliOverrides`.
- Lines 251-258 skip `i++` for long-form flags that convict will handle — but this means the custom parser must be kept in sync with convict's known flags, or it will eat unknown flags' values.
- The canonical config auto-load (lines 147-156) uses `resolve(cp)` relative to CWD, and takes the **first** found file, not both.
- `parseValue` (line 278-279) splits arrays on commas with no escape mechanism. A value like `[hello, world]` gives `["hello", " world"]` — note the leading space (`.trim()` is called, so actually `["hello", "world"]`).
- The profile's runner settings come from either `_runner` or `runner_config` key (line 173). Two names, same purpose.

---

### store.ts — Artifact Store

**Purpose:** In-memory `Map<string, ExtractedRecord[]>` for inter-resource data flow. Validates records against declared artifact schemas, manages dependency DAGs.

**Key exports:**

| Export | Lines | Purpose |
|--------|-------|---------|
| `toArray()` | 14-17 | `string \| string[] \| undefined` → `string[]` |
| `emitTargetNames()` | 20-24 | Extracts artifact names from emit declarations |
| `ArtifactStore` class | 33-284 | The store itself |
| `ArtifactStore.resolveOrder()` static | 89-159 | Topological sort of **resources** (Kahn's algorithm) |
| `ArtifactStore.resolveNodeOrder()` static | 168-231 | Topological sort of **nodes** within a resource |

**ArtifactStore instance methods:**

| Method | Lines | Purpose |
|--------|-------|---------|
| `put()` | 44-69 | Append records to an artifact. Validates against schema. |
| `get()` | 74-76 | Retrieve all records for an artifact. |
| `has()` | 79-81 | Check if an artifact has records. |

**resolveOrder** (lines 89-159) — Resource-level topological sort:
1. Builds `artifactProducer` map: artifact name → resource name (lines 97-101)
2. Adds edges: resource A produces X, resource B consumes X → A must run before B (lines 121-134)
3. Also follows artifact-level `consumes` declarations in the schema (lines 128-133)
4. Runs Kahn's algorithm (lines 137-158)

**resolveNodeOrder** (lines 168-231) — Node-level topological sort:
1. Builds emitter map: artifact → node name (lines 170-174)
2. Adds parent edges from the NER DAG (lines 184-190)
3. Adds artifact edges: emitter node → consumer node (lines 194-206)
4. Kahn's with stable ordering (preserves YAML order for ties) (lines 209-231)

**Validation** (lines 235-283):
- Required fields: checks `undefined`, `null`, and `""` (line 248-249)
- Type matching (lines 274-283): `number` type accepts numeric strings (`typeof val === "string" && !isNaN(Number(val))` at line 277). This is intentional — DOM extraction produces strings.

**Connections:** Imported by `run.ts` and `engine.ts`.

---

### hooks.ts — Hook System

**Purpose:** Extension points at 5 lifecycle moments.

**Hook points** (lines 19-24): `post_discover`, `pre_extract`, `post_extract`, `pre_assemble`, `post_assemble`.

**HookRegistry class** (lines 39-95):

| Method | Lines | Purpose |
|--------|-------|---------|
| `register()` | 47-52 | Add a hook function to a point |
| `invoke()` | 54-65 | Run all hooks at a point, threading context through |
| `loadFromConfig()` | 67-74 | Register placeholder no-ops from YAML config |
| `loadFromModule()` | 76-86 | Dynamic import a JS module, call `registerHooks(registry)` |

**invoke semantics** (lines 54-65):
- Hooks are called in registration order
- If a hook returns a non-null value, it replaces the context for the next hook
- If a hook throws, the error is caught and logged, execution continues (line 59-61)
- This means **one broken hook does not stop execution**

**loadFromConfig** (lines 67-74) only registers **placeholder no-ops** (line 91: `fn: (ctx) => ctx`). Config-declared hooks appear in logs but do nothing unless overridden by a module.

**Connections:** Imported by `run.ts` and `engine.ts`.

---

### ai.ts — AI Adapter Interface

**Purpose:** Abstract interface for post-extraction NLP (entity recognition, classification, normalization).

**AIAdapter interface** (lines 12-29): Three methods:
- `extract(prompt, context, schema?)` → structured JSON
- `classify(prompt, text, categories)` → single category string
- `transform(prompt, input)` → free-form text

**NullAIAdapter** (lines 35-47): Returns `{_ai_error: "no AI adapter configured"}` for extract, first category for classify, input passthrough for transform.

**Key constraint** (line 8-9): AI only operates on already-extracted text, never on the live DOM.

**Connections:** Imported by `engine.ts`, `aichat-adapter.ts`, and `run.ts`.

---

### aichat-adapter.ts — aichat CLI Adapter

**Purpose:** Shells out to the `aichat` CLI (a multi-provider LLM wrapper) synchronously.

**AIChatAdapter class** (lines 14-98):

| Method | Lines | Purpose |
|--------|-------|---------|
| `extract()` | 23-36 | Builds prompt with context + optional schema, calls `aichat`, parses JSON |
| `classify()` | 38-53 | Builds prompt asking for exactly one category, best-effort matches result |
| `transform()` | 55-58 | Free-form text-to-text |
| `call()` | 62-84 | Actual `execSync` call to `aichat --no-stream` |
| `parseJson()` | 86-97 | Strips markdown fences, parses JSON, returns `{_raw, _parse_error}` on failure |

**Notable details:**
- Prompt is passed via **stdin** (`input` option to execSync at line 68), avoiding shell escaping
- Model selection via `-m` flag (line 64)
- `classify` does case-insensitive matching against categories (line 52), falling back to raw response if no match
- `parseJson` strips ````json` fences (lines 89-91) — a common LLM output quirk

**Connections:** Imported by `run.ts`.

---

### processing.ts — Output Formatting

**Purpose:** Converts raw `ExtractedRecord[]` into final output formats (Markdown, CSV). Uses cheerio for HTML parsing and turndown for HTML-to-Markdown.

**Key functions:**

| Function | Lines | Purpose |
|----------|-------|---------|
| `htmlToMarkdown()` | 38-45 | Strips script/style/noscript, then turndown |
| `htmlTableToMarkdown()` | 51-78 | Cheerio-based HTML table → pipe-delimited Markdown table |
| `extractRefs()` | 90-118 | Extract links from HTML, classify as internal/external |
| `cleanHtml()` | 124-131 | Remove elements matching given selectors |
| `assembleMarkdown()` | 137-180 | Multi-record → single Markdown document |
| `assembleCsv()` | 186-212 | Multi-record → CSV string |

**assembleMarkdown** field priority (lines 152-160): looks for `body_md` → `body` → `content` → `body_html`, auto-converting HTML to Markdown when the value starts with `<`.

**assembleCsv** (lines 186-212): Dynamically discovers columns from all records' keys (preserving insertion order). Proper CSV escaping with double-quote wrapping (lines 200-204).

**Connections:** Imported by `run.ts`.

---

### interrupts.ts — Interrupt Handler

**Purpose:** Deterministic side-MDP for dismissing common page blockers (cookie banners, popups, etc.).

**COMMON_RULES** (lines 36-107): 6 shipped rules:

| Rule | Lines | Pattern |
|------|-------|---------|
| cookie-consent | 38-51 | 7 selector variants, `once: true` |
| gdpr-consent | 52-62 | 4 selectors |
| newsletter-popup | 63-73 | 4 selectors targeting close buttons |
| notification-prompt | 74-84 | 4 selectors targeting deny/close |
| age-gate | 85-94 | 3 selectors targeting yes/enter/confirm |
| generic-overlay-close | 95-107 | Only `aria-modal` or `.modal.show`, `once: false`, `max_fires: 3` |

**InterruptHandler class** (lines 111-212):

| Method | Lines | Purpose |
|--------|-------|---------|
| `addRules()` | 123-125 | Append custom rules |
| `check()` | 132-181 | Scan all rules, dismiss active ones, return count handled |
| `findTrigger()` | 188-211 | Visibility-aware element check via evalJson |

**Dismiss modes** (lines 158-173):
- `{click: "SELF"}` — clicks the trigger element itself (line 159)
- `{click: "css"}` — clicks a different element
- `{script: "js"}` — eval arbitrary JS
- `{close_overlay: true}` — dispatches Escape keydown, waits 300ms, removes large fixed-position elements
- `"pause"` — logs and disables the rule (no actual pause mechanism, line 151-153)

**Connections:** Imported by `engine.ts`.

---

### agent-browser-driver.ts — CLI-Based Browser Driver

**Purpose:** `BrowserDriver` implementation that shells out to the `agent-browser` CLI via `execSync`.

**AgentBrowserDriver class** (lines 20-203):

| Method | Lines | Purpose |
|--------|-------|---------|
| `run()` | 33-58 | Raw `execSync` call with session args |
| `runRetry()` | 60-71 | Retry wrapper with exponential-ish backoff |
| `sleep()` | 73-75 | Blocks thread via `Atomics.wait` on SharedArrayBuffer |
| `open()` | 79-86 | `agent-browser open <url>` with wait/timeout flags |
| `getUrl()` | 88-91 | `agent-browser get url` |
| `close()` | 93-95 | `agent-browser close` |
| `eval()` | 99-108 | Writes JS to temp file, passes via `$(cat tmpfile)` |
| `evalJson()` | 110-114 | `eval()` + `parseOutput()` |
| `parseOutput()` | 116-135 | Double-parse: JSON.parse → if string result looks like JSON, parse again |
| `click()` | 139-145 | CSS click via CLI or scripted `.click()` |
| `select()` | 147-150 | `agent-browser select` |
| `scroll()` | 152-155 | `window.scrollBy` via eval |
| `wait()` | 157-166 | networkidle, selector wait, or sleep |
| `hover()` | 168-171 | `agent-browser hover` |
| `type()` | 173-181 | Scripted: clears value, sets value, dispatches `input` event |
| `exists()` | 185-189 | `querySelector !== null` |
| `textContent()` | 191-198 | `querySelector.textContent.trim()` |
| `snapshot()` | 200-202 | `agent-browser snapshot --json` |

**Connections:** Imported by `run.ts`.

---

### run.ts — CLI Entry Point

**Purpose:** Orchestrates everything: loads config, validates profile, wires up components, executes resources in order, writes output.

**Key functions:**

| Function | Lines | Purpose |
|----------|-------|---------|
| `loadProfile()` | 78-94 | Read YAML → Zod parse → `Deployment` |
| `validateSemantics()` | 98-164 | Check references, detect cycles |
| `checkQuality()` | 169-205 | Post-run quality gate |
| `main()` | 209-362 | The main pipeline |

**Output writers** (lines 44-74): `writeJsonl`, `writeCsv`, `writeJson`, `writeMarkdown` — simple dispatch via `WRITERS` map.

**Connections:** Imports from all other files. This is the top of the dependency tree.

---

## 2. The Execution Pipeline in Detail

### Step 1: Config Loading (run.ts:210, config.ts:133-214)

```
process.argv → parseCustomArgs() → convict schema → canonical YAML → profile YAML → deepmerge → CLI overrides → validate
```

1. `main()` calls `loadConfig(process.argv.slice(2))` (run.ts:210)
2. `parseCustomArgs` (config.ts:227) splits argv into: positional args, `--set` pairs, `--config` extras, and short-alias overrides
3. Convict schema built with defaults (config.ts:139)
4. Positional arg[0] becomes the profile path (config.ts:142)
5. Auto-loads `wise.config.yaml` or `.wiserc.yaml` from CWD if present (config.ts:147-156)
6. Loads profile YAML (config.ts:160-164)
7. `deepmerge(canonical, profile)` — profile wins (config.ts:168-170)
8. Profile's `_runner` or `runner_config` keys applied to convict (config.ts:173-180)
9. Extra config files merged on top (config.ts:183-193)
10. `--set` overrides applied via dot-notation (config.ts:196-198)
11. `inputs` extracted from `profile.inputs` or `profile._inputs` (config.ts:201)
12. Convict validates (config.ts:209)

### Step 2: Profile Loading + Validation (run.ts:218-225)

```ts
const profile = loadProfile(profilePath);  // Zod parse
validateSemantics(profile);                 // reference + cycle checks
```

**loadProfile** (run.ts:78-94):
- Reads YAML, parses with `js-yaml`
- `DeploymentSchema.safeParse(raw)` — Zod validates the entire structure
- On failure: prints each issue's path and message, throws

**validateSemantics** (run.ts:98-164):
1. Collects artifact names from `profile.artifacts` (line 99)
2. For each resource:
   - `entry.root` must reference an existing node (line 106-110)
   - `produces` must reference declared artifacts (if any declared) (lines 114-119)
   - `consumes` must reference declared artifacts (if any declared) (lines 122-129)
   - Each node's `parents` must reference existing nodes (lines 132-139)
3. Cycle detection via DFS (lines 145-163):
   - Builds adjacency list from parent→child edges
   - Standard recursive DFS with `visited` + `stack` sets
   - Throws on cycle with the offending node name

### Step 3: Execution Order — Kahn's Algorithm (run.ts:254, store.ts:89-159)

```ts
const executionOrder = ArtifactStore.resolveOrder(profile);
```

This determines which resources run first based on produces/consumes dependencies.

**Algorithm (store.ts:89-159):**
1. Build `artifactProducer` map: for each resource's `produces`, record `artifact → resource_name`
2. Build adjacency list + in-degree map for all resources
3. `addEdge(from, to)` (line 111-119): adds edge only if not self-loop and not duplicate
4. Two sources of edges:
   - Resource-level: resource B consumes artifact X → producer of X must run before B (lines 122-125)
   - Artifact-level: resource B produces artifact Y, and Y's schema declares `consumes: X` → producer of X must run before B (lines 127-133)
5. Kahn's: seed queue with in-degree 0, process, decrement neighbors (lines 137-151)
6. If `order.length !== resources.length`, there's a cycle (line 153)

### Step 4: Resource Loop (run.ts:263-299)

For each resource in `executionOrder`:

```ts
// 1. Create a new driver session per resource
const driver = new AgentBrowserDriver({
  session: `${profile.name}-${resource.name}`.replace(/\s+/g, "-"),
  timeoutMs: runner.timeout,
  retries: runner.retries,
});

// 2. Load resource-level hooks (CAUTION: accumulates, see gotchas)
if (resource.hooks) hookRegistry.loadFromConfig(resource.hooks);

// 3. Create engine with driver + AI + hooks + store
const engine = new Engine(driver, ai, hookRegistry, store);

// 4. Run the resource
const records = engine.runResource(resource);

// 5. Store in artifact(s), skipping node-emitted artifacts
for (const name of toArray(resource.produces)) {
  if (nodeEmits.has(name)) {
    // Double-write prevention: skip if nodes already emit to this artifact
  } else {
    store.put(name, records);
  }
}
```

The `nodeEmits` check (run.ts:284-295) prevents double-writing: if any node in the resource has `emit: "some_artifact"`, the resource-level `produces` skip for that artifact. This is because `emitToArtifacts` in the engine already wrote those records.

### Step 5: Engine.runResource (engine.ts:52-80)

```ts
runResource(resource: Resource): ExtractedRecord[]
```

1. Build `nodeMap`: name → NER node (line 53-54)
2. Apply resource globals: timeout, retries (lines 56-58)
3. Run state setup if declared (line 61)
4. Find root node (line 63-64)
5. **Branch point:**
   - If resource has `consumes` and store exists → `runResourceOverRecords()` (line 68-76)
   - Otherwise → `runResourceOnce()` with the literal entry URL (line 79)

**runResourceOverRecords** (engine.ts:83-105): Iterates over consumed records, resolves `{field_ref}` in entry URL via `resolveTemplate`, calls `runResourceOnce` per record. Respects `request_interval_ms` between iterations.

**runResourceOnce** (engine.ts:108-142):
1. Validates URL starts with `http` (line 117-119)
2. Checks URL dedup via `this.visited` set (line 122-125)
3. Opens URL with `wait: {idle: true}` (line 128)
4. Applies `page_load_delay_ms` (line 133-135)
5. Runs interrupt check (line 137)
6. Calls `walkNode` on root with empty or consumed context (line 140)

### Step 6: walkNode → walkNodeOnce — The 4-Step NER Loop

**walkNode** (engine.ts:178-206) is the entry point for processing any node. Its primary job: check if the node has `consumes`, and if so, iterate over consumed records.

```
walkNode(node, allNodes, records, depth, context)
  ├─ if node.consumes → for each consumed record:
  │    merge consumed.data into context
  │    call walkNodeOnce
  └─ else → call walkNodeOnce directly
```

**walkNodeOnce** (engine.ts:213-267) is the actual NER execution. The 4 steps:

**Step 1: State check** (lines 224-235)
```ts
if (node.state && !this.checkState(node.state)) {
  if (node.retry) {
    // Re-execute parent's actions, then re-check
    const ok = this.retryNode(node, allNodes, indent);
    if (!ok) return;  // skip this node entirely
  } else {
    return;  // skip this node entirely
  }
}
```

`checkState` (engine.ts:360-389) checks **all** conditions (AND logic):
- `state.url`: substring match against current URL (line 364)
- `state.url_pattern`: **also** substring match, NOT regex (line 365)
- `state.selector_exists`: CSS selector existence (line 367)
- `state.text_in_page`: `document.body.innerText.includes(...)` (lines 369-374)
- `state.table_headers`: all listed headers must be present in `<th>` elements (lines 376-387)

**Step 2: Execute actions** (lines 238-240)
```ts
for (const action of node.action ?? []) {
  this.executeAction(action, records, indent, context);
}
```
Then interrupts are checked again (line 243).

`executeAction` (engine.ts:393-442) dispatches on action type:
- `click`: calls `driver.click()` with type option
- `select`: calls `driver.select()`
- `scroll`: special case for `scroll: "to"` → `scrollToTarget()` loop
- `wait`: calls `driver.wait()`
- `reveal`: hover or click
- `navigate`: resolves `{field_ref}` templates, opens URL
- `input`: calls `driver.type()`

**Step 3: Extract** (only if no expand) (lines 248-261)
```ts
if (!node.expand) {
  const extracted = this.extract(node, indent);
  const childContext = extracted ? { ...context, ...extracted } : context;
  if (extracted) {
    const data = { ...context, ...extracted };
    let record = this.makeRecord(node.name, data);
    record = this.hooks.invoke("post_extract", record);
    records.push(record);
    this.emitToArtifacts(node, record, context);
  }
  this.walkChildren(node.name, allNodes, records, depth, childContext);
}
```

Key detail: `data = { ...context, ...extracted }` means **extracted fields shadow context fields**. The `childContext` is the same merge, so children see both ancestor and current node's fields.

**Step 4: Expand** (if expand present) (lines 262-266)
```ts
else {
  this.expandAndDescend(node, allNodes, records, depth, context);
}
```

When a node has `expand`, **node-level extraction is skipped** entirely at the walkNodeOnce level. Extraction happens inside `expandElements` at the per-element level. This prevents double-counting.

### Step 7: expandAndDescend — Three Expansion Types

**expandAndDescend** (engine.ts:638-655) dispatches to one of three methods:

#### Elements Expansion (engine.ts:659-697)

```ts
expandElements(node, expand, allNodes, records, depth, indent, context)
```

1. Calls `extractMultiple(expand.scope, node.extract, expand.limit)` (line 669)
2. Gets back an array of `Record<string, unknown>` — one per matched element
3. For each row:
   - Merges with context: `{ ...context, ...row }`
   - Creates record, invokes `post_extract` hook
   - Emits to artifacts
   - Walks children (DFS: immediately; BFS: after all rows collected)

**extractMultiple** (engine.ts:699-728) — The core multi-element extractor:

If no extraction rules: just counts elements and returns empty objects (lines 704-709).

Otherwise: compiles each extraction rule to inline JS via `extractionToJs()`, then runs a single `evalJson` that iterates over all `scope` elements, executing the compiled JS per element:

```js
// Generated browser JS (simplified)
(() => {
  const rows = [...document.querySelectorAll('scope_css')].slice(0, limit);
  return rows.map(container => {
    const result = {};
    // ... compiled extraction JS lines (relative to `container`) ...
    return result;
  });
})()
```

This is a **single browser roundtrip** for all elements, which is efficient.

#### Pages Expansion (engine.ts:732-862)

Three strategies:

**numeric** (engine.ts:760-786): Discovers all pagination URLs via `document.querySelectorAll(control)`, deduplicates with current URL, opens each in sequence. Calls `walkChildren` on each page.

**next** (engine.ts:788-817): Click-and-walk loop:
```
for page in 0..limit:
  walkChildren()
  if control doesn't exist → break
  if sentinel found → break
  if sentinel_gone missing → break
  click(control), wait(idle)
```

**infinite** (engine.ts:819-862): Scroll-and-walk loop:
```
for page in 0..maxIter:
  walkChildren()
  scroll(down, 2000px)
  wait(1500ms)
  check sentinel/sentinel_gone/stable conditions
```

The `stable` condition (lines 846-860) counts elements matching `stop.stable.css`, tracks consecutive unchanged counts, breaks when `stableCount >= after`.

#### Combinations Expansion (engine.ts:866-916)

1. For each axis with `values: "auto"`, calls `discoverAxisValues()` (lines 879-885)
2. Computes Cartesian product via `cartesian()` helper (line 887)
3. For each combination:
   - Applies each axis's action (select/type/checkbox/click) with its value
   - Waits for idle
   - Walks children

`discoverAxisValues` (engine.ts:918-937):
- `select`: reads all `<option>` values from the control
- `click`: reads textContent of all non-disabled matching elements
- Other actions: returns empty array

`cartesian` (engine.ts:1046-1052): Standard reduce-based Cartesian product.

### Step 8: extractMultiple Compilation — extractionToJs (engine.ts:975-1041)

Each extraction rule compiles to a JS statement that writes to a `result` object, reading from a `container` element:

| Rule type | Generated JS pattern |
|-----------|---------------------|
| `text` | `container.querySelector(css)?.textContent?.trim()` + optional regex match |
| `attr` | `container.querySelector(css)?.getAttribute(attr)` |
| `html` | `container.querySelector(css)?.innerHTML` |
| `link` | `container.querySelector(css)?.getAttribute(attr)` (default: href) |
| `image` | `container.querySelector(css)?.getAttribute('src')` |
| `grouped` | `[...container.querySelectorAll(css)].map(el => ...)` |
| `table` | Full table extraction with header mapping or raw cells |
| `ai` | `'[ai:deferred]'` placeholder |

### Step 9: emitToArtifacts (engine.ts:274-306)

```ts
emitToArtifacts(node, record, context)
```

Two code paths:

1. **String shorthand** (`emit: "name"`): `store.put(name, [record])` (lines 279-281)
2. **Full form** (`emit: [{to, flatten?}]`): For each target (lines 285-305):
   - If `flatten` specified and the field is an array: unpack each element into a separate record, merging with context (lines 289-296)
   - If `flatten` specified but field isn't an array: emit as-is (lines 299-300)
   - If no `flatten`: emit as-is (line 303)

Flatten mechanics (line 291-294):
```ts
const rowData = typeof row === "object" && row !== null
  ? { ...context, ...(row as Record<string, unknown>) }
  : { ...context, [target.flatten!]: row };
```
If the array element is an object, spread it over context. If it's a primitive, wrap it with the flatten field name as key.

### Step 10: Quality Gate (run.ts:169-205, 343-348)

```ts
let qualityRecords = finalRecords;
if (outputArtifacts.length > 0) {
  qualityRecords = outputArtifacts.flatMap(([name]) => store.get(name));
}
const qualityOk = checkQuality(qualityRecords, profile);
```

**Why check store records, not engine records:** When `emit` + `flatten` is used, 3 nested engine records might become 77 flat artifact records. The quality gate needs to check the final shape, not the intermediate one.

Quality checks (run.ts:169-205):
- `min_records`: simple count (line 177)
- `max_empty_pct`: records with empty `data` object (lines 181-186)
- `min_filled_pct`: per-column fill rate (lines 190-203)

### Step 11: Output Writing (run.ts:310-339)

Two output paths:

1. **Artifact-specific output** (lines 312-325): For artifacts with `output: true`, uses the artifact's declared `format` or falls back to runner config.
2. **All-records dump** (lines 328-332): Always writes all records in the runner's format.

---

## 3. The Browser Driver Abstraction

### The execSync-Based CLI Pattern (agent-browser-driver.ts)

Every browser operation is a synchronous `execSync` call to the `agent-browser` CLI:

```ts
// Line 36-37
const cmd = `agent-browser ${sessionArgs.join(" ")}`;
execSync(cmd, { encoding: "utf-8", timeout, ... });
```

**Session management** (line 25-28, 35): Every call includes `--session <name>`. The session name is `${profile.name}-${resource.name}` with spaces replaced by hyphens (run.ts:269). This lets agent-browser maintain browser state across calls.

### Temp File Approach for JS Eval (agent-browser-driver.ts:99-108)

```ts
eval(js: string): string | null {
  const tmpFile = join(tmpdir(), `wise-eval-${process.pid}.js`);
  try {
    writeFileSync(tmpFile, js, "utf-8");
    return this.runRetry(["eval", `"$(cat ${tmpFile})"`]);
  } finally {
    try { unlinkSync(tmpFile); } catch { /* ignore */ }
  }
}
```

JS is written to a temp file, then passed via shell command substitution `$(cat tmpfile)`. This avoids shell escaping nightmares with complex JS. The file is cleaned up in a `finally` block.

**Note:** The temp file name uses `process.pid` but not a unique counter — if two evals somehow ran concurrently (they can't in this synchronous design, but hypothetically), they'd clobber each other.

### Double JSON Parse (agent-browser-driver.ts:116-135)

`parseOutput` handles agent-browser's output wrapping:

```ts
private parseOutput(raw: string): unknown {
  const first = JSON.parse(raw);           // First parse: agent-browser may JSON-encode the output
  if (typeof first === "string") {
    const trimmed = first.trim();
    if (trimmed.startsWith("{") || trimmed.startsWith("[")) {
      try { return JSON.parse(first); }    // Second parse: only for objects/arrays
      catch { /* fall through */ }
    }
    return first;                           // String that doesn't look like JSON: return as-is
  }
  return first;
}
```

The critical guard (lines 126-127): **only second-parse if it looks like an object or array**. Without this, numeric strings like `"128"` would silently convert to `128`, breaking schema validation.

### Retry Logic (agent-browser-driver.ts:60-71)

```ts
private runRetry(args: string[], timeoutS?: number): string | null {
  for (let attempt = 0; attempt <= this.retries; attempt++) {
    const result = this.run(args, timeoutS);
    if (result !== null) return result;
    if (attempt < this.retries) {
      const wait = 2 * (attempt + 1);  // 2s, 4s, 6s ...
      this.sleep(wait * 1000);
    }
  }
  return null;
}
```

Linear backoff: 2s, 4s, 6s. Default retries = 2, so max 3 attempts total. Only `runRetry` uses retries — `run` itself does not retry. Methods like `getUrl()` and `close()` call `run` directly (no retries).

### Sleep via Atomics (agent-browser-driver.ts:73-75)

```ts
private sleep(ms: number): void {
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);
}
```

This is a **blocking sleep** that doesn't spin the CPU. It uses `Atomics.wait` on a never-notified SharedArrayBuffer. This is the standard Node.js trick for synchronous sleep without busy-waiting.

---

## 4. The Interrupt System

### Default Rules (interrupts.ts:36-107)

Six rules ship by default, covering the most common website interruptions:

1. **cookie-consent**: 7 CSS selectors covering OneTrust, CookieConsent, aria-label patterns
2. **gdpr-consent**: GDPR-specific selectors including Didomi
3. **newsletter-popup**: Generic close buttons in newsletter/popup/modal/subscribe containers
4. **notification-prompt**: Push notification deny/close buttons
5. **age-gate**: Yes/enter/confirm buttons in age verification
6. **generic-overlay-close**: Only matches `aria-modal="true"` or `.modal.show` — the only rule with `once: false` and `max_fires: 3`

All rules except generic-overlay-close use `dismiss: { click: "SELF" }`, meaning they click the trigger element itself.

### The Check/Dismiss Cycle (interrupts.ts:132-181)

`check()` is called:
- After opening a page (engine.ts:137)
- After executing a node's actions (engine.ts:243)

The cycle for each rule:
1. Skip if disabled (line 135)
2. Check fire count against max (lines 137-141)
3. Call `findTrigger` to check visibility (line 145)
4. If triggered, dispatch dismiss action (lines 158-173)
5. Wait 500ms after dismissal (line 175)
6. Increment fire count (line 176)

### max_fires and Cooldown (interrupts.ts:137-141)

```ts
const maxFires = rule.max_fires ?? (rule.once !== false ? 1 : 3);
if (count >= maxFires) {
  this.disabled.add(rule.name);
  continue;
}
```

The logic for determining max fires:
- If `max_fires` is set explicitly, use it
- If `once` is `true` (or not explicitly `false`), max is 1
- Otherwise, max is 3

Once a rule hits its max, it goes into `this.disabled` and is never checked again for the life of the handler.

There is **no time-based cooldown** — the `cooldown_ms` concept mentioned in the interface comment doesn't exist in the code. The only "cooldown" is the 500ms wait after each dismissal (line 175).

### Visibility-Aware Trigger Detection (interrupts.ts:188-211)

`findTrigger` doesn't just check `querySelector` — it evaluates visibility in the browser:

```js
const style = window.getComputedStyle(el);
if (style.display === 'none' || style.visibility === 'hidden') continue;
if (rect.width === 0 || rect.height === 0) continue;
if (style.opacity === '0') continue;
```

It splits the trigger's compound selector on commas (line 189), checks each sub-selector independently, and returns the first visible match's selector string.

### Integration with Engine

The engine calls `this.interrupts.check()` at two points:
1. After `runResourceOnce` opens the page (engine.ts:137)
2. After executing a node's actions (engine.ts:243)

The InterruptHandler is created per-Engine (engine.ts:46), and Engine is created per-resource (run.ts:278). So interrupt state (fire counts, disabled set) is **per-resource**, not global.

---

## 5. Data Flow Internals

### Context Accumulation

Context flows down the node tree via the `context` parameter:

```
root: context = consumedData ?? {}
  → walkNodeOnce: childContext = { ...context, ...extracted }
    → walkChildren: passes childContext
      → child walkNodeOnce: childContext = { ...context, ...childExtracted }
```

**Spread ordering matters:** `{ ...context, ...extracted }` means **extracted fields shadow ancestor context**. If a parent extracts `{title: "Parent"}` and a child extracts `{title: "Child"}`, the child's record will have `title: "Child"`.

When a node consumes artifacts (engine.ts:196-200):
```ts
const mergedContext = { ...context, ...rec.data };
```
Consumed record data shadows any existing context.

### Template Resolution

Two template resolution functions exist:

1. **resolveTemplate** (engine.ts:145-149): Used for resource entry URLs with consumed data. Simple `{field}` replacement from a data record.

2. **resolveUrl** (engine.ts:477-495): Used for navigate actions. Two-level fallback:
   - First tries accumulated context
   - Falls back to scanning records array in reverse (most recent first)
   - Unreplaced templates remain as `{field}` literal

Both use the same regex: `/\{(\w+)\}/g` — only matches word characters inside braces.

### ArtifactStore: put/get and Validation

**put** (store.ts:44-69):
- Appends to existing records (`[...existing, ...records]` at line 56)
- Validates each record against schema if declared
- Logs first 5 validation errors, mentions count of remaining
- **Always stores records even if validation fails** — validation is advisory

**get** (store.ts:74-76): Returns stored records or empty array. No copy — returns the actual array reference.

### The Double-Write Prevention (run.ts:284-295)

```ts
const nodeEmits = new Set(resource.nodes.flatMap((n) => {
  if (!n.emit) return [];
  if (typeof n.emit === "string") return [n.emit];
  return n.emit.map((e) => e.to);
}));

for (const name of toArray(resource.produces)) {
  if (nodeEmits.has(name)) {
    console.log(`[main] Skipping resource-level store for '${name}' (nodes already emit)`);
  } else {
    store.put(name, records);
  }
}
```

**The problem this solves:** If a resource `produces: ["listings"]` and a node has `emit: "listings"`, without this check the engine would emit records into the store (via `emitToArtifacts`), and then `run.ts` would **also** `store.put("listings", records)`, duplicating everything.

**The detection:** Scans all nodes in the resource for emit targets. If any node emits to an artifact that the resource also produces, the resource-level store.put is skipped for that artifact.

**Edge case:** This check uses node declarations, not runtime state. If a node has `emit: "X"` but never actually runs (e.g., its state check fails), the artifact won't get the resource-level write either.

---

## 6. Known Gotchas and Sharp Edges

### 1. escapeJs Only Handles Single Quotes (driver.ts:72-74)

```ts
export function escapeJs(s: string): string {
  return s.replace(/\\/g, "\\\\").replace(/'/g, "\\'").replace(/\n/g, "\\n");
}
```

This escapes for single-quoted JS strings **only**. It does NOT escape:
- **Backticks** — if the value contains `` ` ``, it will break any template literal context
- **Template literal expressions** `${...}` — could cause code injection
- **Double quotes** — safe in single-quoted context, but the agent-browser CLI wraps args in double quotes (agent-browser-driver.ts:81, 144), creating a mismatch

The engine uses single-quoted strings in generated JS (e.g., `'${escapeJs(css)}'`), so backtick and `${}` injection are real risks if user-controlled CSS selectors contain these characters.

### 2. Hooks Accumulate Across Resources (run.ts:276-277)

```ts
// Inside the resource loop:
if (resource.hooks) hookRegistry.loadFromConfig(resource.hooks);
```

The `hookRegistry` is created once (run.ts:237), and `loadFromConfig` **appends** hooks. So if resource A registers `post_extract: [dedupe]` and resource B registers `post_extract: [normalize]`, resource B's engine will fire **both** dedupe and normalize hooks. This is almost certainly a bug for resource-scoped hooks.

### 3. url_pattern Is Substring Match, Not Regex (engine.ts:365)

```ts
if (state.url_pattern && !url.includes(state.url_pattern)) return false;
```

Despite the name `url_pattern`, this is a plain substring match via `String.includes()`, identical to `state.url` (line 364). There is no regex support. A profile author seeing `url_pattern` would reasonably expect regex behavior.

### 4. The AI Placeholder '[ai:deferred]' Is Never Resolved (engine.ts:1036-1037)

```ts
} else if ("ai" in rule) {
  return `result['${escapeJs(rule.ai.name)}'] = '[ai:deferred]';`;
}
```

When `ai` extraction rules appear inside an `expand.over: "elements"` node, `extractionToJs` compiles them to a placeholder string `'[ai:deferred]'`. This placeholder is **never post-processed** — it ends up as a literal string in the final output. The `extract()` method (engine.ts:499-549) handles AI rules properly, but `extractMultiple` (used by element expansion) does not.

### 5. domTable Return Type Mismatch (engine.ts:624-634)

When no columns are defined, `domTable` returns `string[][]` (arrays of cell strings), not `Record<string, string>[]`:

```ts
// No columns defined — return all cells as arrays
return this.driver.evalJson<Record<string, string>[]>(`
  ...rows.map(row =>
    [...row.querySelectorAll('td, th')].map(c => c.textContent.trim())
  );
`) ?? [];
```

The TypeScript generic says `Record<string, string>[]` but the actual browser JS produces `string[][]`. The generic is a lie — callers will get arrays, not objects.

### 6. expandInfiniteScroll Re-Extracts Entire DOM (engine.ts:819-862)

```ts
for (let page = 0; page < maxIter; page++) {
  this.walkChildren(node.name, allNodes, records, depth, context);  // <-- extracts EVERYTHING
  this.driver.scroll("down", 2000);
  this.driver.wait({ ms: 1500 });
}
```

Each iteration calls `walkChildren`, which walks the child nodes. If a child has `expand.over: "elements"`, it re-queries the entire DOM with `querySelectorAll`. This means:
- On iteration 1: extracts elements 1-10
- On iteration 2 (after scroll loads more): extracts elements 1-20 (including 1-10 again)
- Records accumulate duplicates

There is no deduplication mechanism in the engine. The `ArtifactSchema.dedupe` field exists in the schema but is never enforced at the engine level.

### 7. click "SELF" in Interrupts Uses Trigger Selector (interrupts.ts:159)

```ts
const target = rule.dismiss.click === "SELF" ? match : rule.dismiss.click;
```

`match` is the specific sub-selector returned by `findTrigger` (not the compound selector). If the trigger is `"[class*='cookie'] button, #onetrust-accept-btn-handler"` and the second selector matched, `match` will be `"#onetrust-accept-btn-handler"`. This is correct behavior, but non-obvious — it clicks the **specific matching sub-selector**, not the first one in the list.

### 8. parseOutput Double-Parse Can Silently Transform Data (agent-browser-driver.ts:116-135)

The double-parse logic is guarded (only re-parses strings that start with `{` or `[`), but there's a subtle issue: a string value of `"{\"foo\": \"bar\"}"` will be double-parsed into an object. If the intended result was the string itself, you lose it. The guard mitigates most cases but can't distinguish "this is a JSON string that should stay a string" from "this is a JSON string that should be parsed."

### 9. State Setup Runs Before First URL Load (engine.ts:61)

```ts
if (resource.setup) this.runSetup(resource.setup);
```

`runSetup` calls `driver.exists(setup.skip_when)` (engine.ts:155), but at this point no URL has been loaded yet (that happens in `runResourceOnce`). The `exists` check runs against whatever page the browser session currently shows (likely `about:blank` for a new session). The setup actions include `{open: url}`, so it works if the first action opens a page, but the `skip_when` check is meaningless for a fresh session.

### 10. resolveUrl Fallback to Records Array (engine.ts:488-492)

```ts
// Fall back to most recent record
for (let i = records.length - 1; i >= 0; i--) {
  const val = records[i].data[field];
  if (val !== undefined && val !== null) return String(val);
}
```

This scans **all records ever collected in the current resource** in reverse order. For a large scrape, this could resolve `{url}` to a URL from a completely unrelated node's extraction. The context-first check mitigates this, but the fallback is fragile.

### 11. Numeric Page Strategy Includes Current URL (engine.ts:773)

```ts
const urls = [current, ...links.map(a => a.href)].filter((v,i,s) => s.indexOf(v) === i);
```

The current page URL is prepended to the list and deduped. Then on line 783: `if (i > 0) driver.open(limited[i])`. So the current page's children are walked without a page open, and subsequent pages get opened. This works correctly but means the first "page" is whatever is currently loaded.

### 12. walkChildren Finds Children by Linear Scan (engine.ts:948-949)

```ts
const children = Object.values(allNodes).filter(
  (n) => (n.parents ?? []).includes(parentName),
);
```

This scans all nodes in the resource every time `walkChildren` is called. For a resource with many nodes and deep expansion, this is O(n) per call. Not a correctness issue, but a performance consideration for large profiles.

### 13. Hooks loadFromConfig Registers No-Ops (hooks.ts:88-94)

```ts
private _registerPlaceholder(point: HookPoint, hookDef: HookDef): void {
  console.log(`[hook] Registered '${hookDef.name}' at ${point} (from config)`);
  this._hooks[point].push({
    fn: (ctx: unknown) => ctx,    // <-- does nothing
    name: hookDef.name ?? "config-hook",
  });
}
```

Config-declared hooks are **placeholders only**. They log registration but pass through unchanged. The actual implementation must come from `loadFromModule`. This means declaring hooks in YAML without providing a module creates a false sense of security.

### 14. Combination Expand Click Action Uses escapeJs (engine.ts:907)

```ts
const target = btns.find(b => b.textContent.trim() === '${escapeJs(val)}' || b.value === '${escapeJs(val)}');
```

If a button's text content or value contains characters not handled by `escapeJs` (backticks, `${}`), this match will break or create injection. Since axis values can come from `auto` discovery (which reads from the DOM), this is a realistic risk if a page has unusual button labels.

### 15. The visited Set Is Engine-Scoped (engine.ts:41)

```ts
private visited = new Set<string>();
```

URL deduplication is per-Engine instance, and each resource gets a new Engine (run.ts:278). So if two resources visit the same URL, both will process it. Within a resource, URLs are deduped, which matters for consumed-record iteration where multiple records might reference the same URL.
