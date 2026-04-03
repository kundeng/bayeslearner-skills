# wise-scraper v2 — Progress Notes

Last updated: 2026-04-03

## What Was Done (session 2 — 2026-04-03)

### Reviewed and merged `codex/wise-scraper-followups` branch

Codex branch (1 commit) addressed all code review findings from session 1 and all SKILL.md audit items:

**Code review fixes (codex):**
- Hook scoping: `beginResource()`/`endResource()` lifecycle prevents hooks leaking across resources
- CSS comma splitting: `splitSelectorList()` parser handles quotes, brackets, parens
- CSV injection: formula-prefix escaping in `assembleCsv`
- Overlay dismiss: now uses `getComputedStyle` instead of inline style matching
- Hook load errors: `loadFromModule` now re-throws instead of swallowing
- ZIP code coercion: `parseValue` uses regex to preserve leading-zero strings
- AI in element expansion: `applyAiRules` runs AI rules post-DOM-eval instead of `[ai:deferred]` placeholder
- `escapeJs`: now handles backticks, `${`, CR/LF, Unicode line separators

**Schema audit fixes (codex):**
- Removed `ClickAction.uniqueness` and `ClickAction.discard` from schema.ts, schema.cue
- Removed `Deployment.schedule` from schema.ts, schema.cue
- Implemented `ArtifactSchema.dedupe` in store.ts `put()` and run.ts output assembly
- Implemented `max_failed_pct` quality gate with per-artifact validation summaries
- Wired up `post_discover` hook invocation in engine (with targets array)
- Wired up `pre_extract` and `post_extract` node-level hooks via `invokeDefs`

### Bugs found and fixed during review (3 additional commits)

1. **hooks.ts: `fn.name` collision** — `name ?? fn.name ?? "anonymous"` used `??` but arrow functions have `fn.name === ""` (empty string, not nullish). Changed to `||`. Without this fix, all unnamed inline hook registrations silently collided on key `""`.

2. **store.ts: null accepted as valid object** — `typeMatches` for `"object"` type didn't exclude `null` (`typeof null === "object"` in JS). The quality gate in run.ts correctly rejected null but the store validation accepted it, causing inconsistent failure counts between flat and tree record paths.

3. **engine.ts: `runNodePreExtract` dropped ancestor context** — When a `pre_extract` hook returned `{ data: { ... } }`, the method returned only `result.data` instead of `{ ...context, ...result.data }`. This silently dropped all ancestor context fields (parent extractions, consumed data) from child nodes.

4. **engine.ts: `expandElementsTree` missing `runNodePostExtract`** — Node-level `post_extract` hooks fired in `walkNodeTreeOnce` and the flat walker but were missing from both BFS and DFS branches of tree element expansion. Added `runNodePostExtract` calls to both.

5. **schema.json stale** — Regenerated from Zod source of truth. Was still referencing removed `uniqueness`, `discard`, `schedule` fields.

6. **architecture.md stale** — Updated 8 sections: ClickAction table, Deployment table, hooks.ts architecture (now scoped), AI extraction (applyAiRules), quality gate (max_failed_pct), and 6 gotcha entries that described already-fixed bugs.

7. **Duplicated dedupe logic** — Extracted shared `dedupeByField()` utility from store.ts. Both `store.ts` (incremental put) and `run.ts` (output assembly) now call the same function.

### Commits (session 2)

```
c19e15b wise-scraper: fix runner hooks and harden extraction          (codex)
19676e9 wise-scraper: fix hook name bug, regenerate schema.json, sync architecture.md
9bf7df2 wise-scraper: fix null object validation, consolidate dedupe logic
8674a8d wise-scraper: fix pre_extract context drop, add missing node post_extract hooks
```

## Decisions Made

### D1: Dual nested+flat output per test profile
Update all 9 test profiles to declare both `structure: "nested"` and `structure: "flat"` output artifacts for the same subtree. No runner code changes — purely profile YAML. Validates both output paths end-to-end against live sites.

### D2: JMESPath for tree queries
Adopt `@metrichor/jmespath` (TypeScript, ~8.7M weekly npm downloads). Add an optional `query` field to ArtifactSchema. When present, the query transforms the TreeRecord before output. `flattenTree` becomes the default when no query is specified.

This unlocks **bidirectional denormalization**:
- **Downward** (current `flattenTree`): ancestor fields propagate to leaves → flat CSV/table
- **Upward** (new): child arrays aggregate into parent → nested JSON, document stores

Example:
```yaml
artifacts:
  products_flat:
    query: "products[].{name: name, color: variants[].color}"  # downward
  products_nested:
    query: "products[].{name: name, variants: variants[]}"     # upward
```

### D3: Skip extraction type consolidation
The 8 extraction types (text, attr, html, link, image, table, grouped, ai) work, agents understand them, and consolidation would break every existing profile for cosmetic gain.

### D4: Context propagation (Terraform module model)
Extend template resolution beyond entry URLs. Allow `{artifacts.X.field}` and `{config.key}` references in:
- `navigate.to` templates
- Node-level field references
- Eventually: extract CSS selectors (dynamic selectors from config)

This makes NER nodes more like Terraform resources with explicit input wiring — any node can reference any artifact in the store, config inputs, and accumulated parent context.

### D5: Agent-based skill validation (testing)
Build a test harness that:
1. Spawns a subagent (or Agent SDK agent) with the SKILL.md
2. Gives it a real scraping scenario (live site + target data description)
3. The agent produces a profile from the skill docs alone
4. Harness validates: profile passes Zod, runs against live site, output matches expected shape/count

This tests **skill teachability** — does the doc actually teach an agent to scrape correctly? Live site tests are preferred over mocks. Subagents or Agent SDK are both acceptable for the test harness.

### D6: Product vision — fork Nanobrowser
WISE becomes a Chrome extension by forking Nanobrowser:
- Replace Nanobrowser's free-form agent loop with WISE's structured exploration phase
- Add WISE's deterministic NER runner as the exploitation phase
- Implement BrowserDriver on top of Nanobrowser's existing CDP wrapper
- Profile format is the contract between exploration and exploitation

**Gate:** Profile format must be product-grade before forking. D2 (JMESPath) and D4 (context propagation) must land first.

## Next Session — Execution Plan

### Priority 1: Run live tests ✅ (P1-P3 done, need re-run)

Re-run all 11 test profiles against live sites to validate:
- Dual output (nested + flat) produces correct data
- JMESPath query artifacts produce expected shapes
- No regressions from P3 schema changes

### Priority 2: Agent skill test harness (D5)

**What:** Build a test that spawns a subagent with SKILL.md and a scraping scenario, then validates the output.

**Steps:**
1. Pick 2-3 test scenarios (e.g., "scrape book titles from books.toscrape.com", "extract product variants from a known e-commerce page")
2. Write the test harness — subagent approach or Agent SDK
3. Subagent gets: SKILL.md contents, scenario description, access to agent-browser
4. Validate: produced profile passes Zod, runner executes successfully, output has expected fields/counts
5. **Doc sync:** Document the test approach in a testing section of guide.md

### Priority 3: Fork Nanobrowser (D6)

Gate: profile format is stable (JMESPath query field, context propagation syntax — DONE). Then:
1. Fork Nanobrowser repo
2. Implement `BrowserDriver` on Nanobrowser's CDP wrapper
3. Replace agent loop with WISE exploration phase
4. Add deterministic NER runner
5. Profile YAML is the shared contract

## What Was Done (session 3 — 2026-04-03)

### P1: Dual output profiles (D1)
Updated all 10 test profiles to declare both nested and flat output artifacts:
- **No-artifact profiles** (laptop, laptop-paginated, revspin, splunk): Added `artifacts` block + `produces: [X_nested, X_flat]`
- **Shorthand emit profiles** (books-mystery, quotes, variants, amazon): Added second artifact, changed `emit: "X"` → `emit: [{to: X}, {to: X_flat}]`
- **Array emit profiles** (tables, umsalary): Added nested artifact, appended `{to: X_nested}` to emit array
- Amazon renamed `products` → `products_nested` + `products_flat` (both output)
- All 11 profiles pass Zod dry-run validation

### P2: JMESPath tree queries (D2)
- Installed `@metrichor/jmespath` dependency
- Added `query: z.string().optional()` to `ArtifactSchema` in schema.ts
- Implemented `treeToDocument()` — converts TreeRecord to clean query-friendly document (data fields promoted, children keyed by node name)
- Implemented `applyTreeQuery()` — groups trees by node name, applies JMESPath, returns result
- In `writeOutputArtifact`: when `schema.query` is set, applies JMESPath to trees and writes result directly (overrides `structure`)
- Added 2 JMESPath query artifacts to books-mystery-test.yaml:
  - `mystery_books_query_down`: downward denormalization — `[].pages[].books[].{title, price, rating}`
  - `mystery_books_query_up`: upward aggregation — `[].pages[].{book_titles: books[].title, book_count: length(books)}`
- Updated schema.cue and regenerated schema.json

### P3: Context propagation (D4)
- Extended `resolveTemplate()` in engine.ts with three-tier reference resolution:
  - `{field}` — local context (unchanged)
  - `{artifacts.name.field}` — cross-artifact store reference
  - `{config.key}` — input config reference
- Added `EntryUrl` union type in schema.ts: `string | { from: string }`
- Implemented `{ from: "resource.node.field" }` entry URL resolution:
  - `store.putResourceTree(name, trees)` stores resource trees under `__res:{name}`
  - `store.resolveFrom(ref)` walks stored trees to find matching nodes and extract fields
  - Engine resolves `{ from: }` to multiple visit targets
- Fixed splunk-spl2-test.yaml validation (was failing due to `{ from: }` syntax not in Zod schema)
- Engine constructor now accepts optional `config` parameter, wired from `config.inputs` in run.ts
- Updated schema.cue and regenerated schema.json

### Doc sync
Updated all 4 documentation files:
- **SKILL.md**: Added `query` to field list, new sections for JMESPath queries, template references, `{ from: }` entry URLs
- **field-guide.md**: Added `query` artifact setting, template references section, entry URL cross-resource reference
- **guide.md**: Added `{ from: }` example, template references table, JMESPath tree queries section
- **architecture.md**: Updated ArtifactStore API, template resolution section, added `{ from: }` and JMESPath sections

## Decisions Made (session 3)

### D7: Clean document shape for JMESPath
JMESPath queries operate on a cleaned tree shape: data fields promoted to top-level, children keyed by node name. NOT the raw TreeRecord with `node`, `url`, `data`, `children` scaffolding. This makes queries natural for profile authors: `[].pages[].books[].{title: title}` instead of `[].children.pages[].children.books[].data.title`.

### D8: Three-tier template resolution
Template references follow the Terraform module model:
- `{field}` = local (like Terraform `self.attr`)
- `{artifacts.name.field}` = cross-module (like `module.vpc.subnet_id`)
- `{config.key}` = variable (like `var.region`)
The `{ from: }` entry URL is a separate mechanism for multi-target expansion (not interpolation).

## Known remaining issues (not addressed yet)

- Hook errors silently swallowed in `runDefs` — hooks that throw are caught and logged but execution continues. Terminal hooks (`post_assemble`) should probably re-throw or accumulate errors.
- `max_failed_pct` is effectively a no-op for schema-less artifacts (no schema = nothing to validate = 0% failure always).
- `extractionToJs` AI branch (line ~1625) is now dead code — AI rules are filtered before reaching it. Can be removed for clarity.
- Hook name collisions: `namedHooks` registry is global (not per-resource). Two modules registering the same hook name at the same point silently overwrite. Not triggered in production but a design footgun.

## Test Results Summary (2026-04-02, before session 2 changes)

| Test | Tree | Flat | Status |
|------|------|------|--------|
| laptop | 1 | 117 | PASS |
| laptop-paginated | 1 | 117 | PASS |
| revspin | 1 | 200 | PASS |
| variants | 7 | 24 | PASS |
| splunk | 18 | 9 (md) | PASS |
| umsalary | 1 | 77 | PASS |
| tables | 1 | 6 | PASS |
| books-mystery | 1 | 32 | PASS |
| amazon | 4 | 240 | PASS |

**Note:** Tests need re-running after session 2 changes to verify no regressions.

## All Commits (both sessions)

```
# Session 1 (2026-04-02)
ba048e8 wise-scraper: json default, emit rename, bug fixes
fe019d3 wise-scraper: implement table extraction inside element expansion
7e7def1 wise-scraper: tree record model, security fixes, architecture doc
b055de4 wise-scraper: sync all docs with tree record model and audit fixes
31686ad wise-scraper: fix two stale references in guide.md

# Session 2 (2026-04-03)
c19e15b wise-scraper: fix runner hooks and harden extraction
19676e9 wise-scraper: fix hook name bug, regenerate schema.json, sync architecture.md
9bf7df2 wise-scraper: fix null object validation, consolidate dedupe logic
8674a8d wise-scraper: fix pre_extract context drop, add missing node post_extract hooks
```
