# WiseRpaBDD Engine Parity with WISE Scraper

## Context

`WiseRpaBDD.py` (in `skills/wise-rpa-bdd/scripts/`) is a Robot Framework
keyword library whose `ExecutionEngine` runs a deferred rule tree using
`robotframework-browser`. A thorough parity audit against the WISE scraper
engine (TypeScript, in `skills/wise-scraper/`) found 6 critical gaps and
several medium ones. The library works for simple linear chains but breaks
on complex DAGs, multi-parent nodes, and production scraping patterns.

The WISE scraper source is the reference implementation. Read the engine
files in `skills/wise-scraper/` to understand the correct behavior before
implementing each fix.

## Phase 1 — DAG execution correctness (critical)

### Task 1: Topological sort for node execution
- Replace `_build_rule_tree` / `_attach_children` with proper Kahn's algorithm
- Nodes must execute in dependency order (parents before children)
- Multi-parent nodes execute ONCE, after ALL parents complete (not once per parent)
- Detect cycles at plan time and raise clear errors
- Test: create a diamond DAG (A→B, A→C, B→D, C→D) and verify D runs once

### Task 2: Resource dependency ordering
- Replace the independent/dependent bucket sort with topological sort
- Resources that consume artifacts from other resources must wait
- Chain deps (A produces for B, B produces for C) must resolve correctly
- Test: 3-resource chain where each consumes the prior's output

### Task 3: Context inheritance between nodes
- Parent node's extracted fields must flow to child nodes
- Expansion nodes pass per-element context to children
- Consumed artifact records merge into context
- `{field}` references in template URLs resolve from accumulated context
- Test: child node accesses parent-extracted field via bound reference

## Phase 2 — Missing execution features (critical)

### Task 4: Retry logic
- Add `retry` support to rules: `max` retries, `delay_ms` between
- On state check failure: wait, re-execute parent actions, re-check
- Keyword: reuse existing state/action infrastructure
- Test: mock a flaky selector that passes on 2nd try

### Task 5: Combination expansion
- Implement runtime `expand_over_combinations` (currently a stub)
- Cartesian product of axis values
- Support `auto` discovery (read select options, button text)
- Per-combo: apply action sequence, wait idle, walk children
- Test: 2-axis combo (select + click) with known values

### Task 6: AI extraction
- Implement `extract_with_ai` — call Claude API with prompt + input field
- Input field must be previously extracted text (not live DOM)
- Support: prompt, input, schema, categories
- Use `anthropic` SDK (already available via claude-agent-sdk dep)
- Test: extract categories from raw HTML via prompt

## Phase 3 — Medium gaps

### Task 7: Hook system
- Implement hook registration and invocation at lifecycle points
- Points: post_discover, pre_extract, post_extract, pre_assemble, post_assemble
- Hooks receive context and can modify data
- Test: register a post_extract hook that transforms a field

### Task 8: BFS expansion mode
- `_expand_elements` currently DFS only
- Add BFS: collect ALL element extractions first, then walk children per batch
- Controlled by `order` parameter on expansion
- Test: BFS element expansion collects URLs before navigating

### Task 9: Output format support
- Currently JSON only
- Add: JSONL (one record per line), CSV, Markdown
- Controlled by artifact `format` option
- Test: same data output as JSON, JSONL, and CSV

### Task 10: Auth/state setup and interrupts
- Implement `configure_state_setup` — run pre-scrape action sequence
- Implement `configure_interrupts` — auto-dismiss overlay selectors
- Interrupts checked after each page load and action
- Test: dismiss a cookie banner via interrupt config

## Accept when

- Diamond DAG (A→B, A→C, B→D, C→D): D executes once, after B and C
- 3-resource chain: correct artifact flow A→B→C
- Context inheritance: child accesses parent field
- Retry: flaky state recovers on 2nd attempt
- Combinations: 2-axis cartesian produces correct records
- AI extraction: prompt-based classification returns structured output
- All 6 golden baselines still pass BDD validation + dryrun
- No regressions in existing keywords
