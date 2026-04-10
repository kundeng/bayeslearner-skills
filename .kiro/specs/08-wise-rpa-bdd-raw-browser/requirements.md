# spec-08: WiseRpaBDD Hardening — Resilience, Stealth, CLI Unification

Created 2026-04-09. Carries forward spec-07 items 4+5+6 plus new work.

## Goals

1. Smart selector resilience (from spec-07 #4)
2. Yelp stealth validation (from spec-07 #6 — patchright already implemented)
3. Ralph-loop 2-hat mode with #1 and #2 as workloads (from spec-07 #5)
4. Unify WiseRpaBDD.py as single CLI entry point (run/dryrun/validate/generate)
5. Raw browser action docs + golden tests (from old spec-08 draft)

---

## 1. Smart Selector Resilience

**Status:** Fallback selector chain implemented in WiseRpaBDD.py, documented
in keyword-reference.md. No golden test exercises it yet.

### Tasks
- [ ] Create golden test exercising fallback selectors (pipe-delimited chain)
- [ ] Implement sponsored item filter in `_expand_elements`
      (`skip_sponsored=true` in resource globals)
- [ ] Add content validation post-filter (field-level regex reject patterns)
- [ ] Golden test exercising sponsored filter
- [ ] E2E validation: agent generates suite using fallback selectors from
      skill docs alone (no spoon-feeding)

---

## 2. Yelp Stealth Validation

**Status:** `_StealthAdapter` implemented with patchright + playwright-stealth.
`WISE_RPA_STEALTH` env var wired up. Never validated against Yelp live.

### Known
- Client-side detection defeated (Sannysoft clean pass)
- Server-side detection remains (TLS fingerprint, HTTP/2, CDP leaks)
- Cookie injection removed (was fragile)

### Tasks
- [ ] Run yelp-interrupt-test.robot with `WISE_RPA_STEALTH=1 WISE_RPA_HEADED=1`
- [ ] If blocked: evaluate TLS/JA3 approach (rebrowser-patches, patchright)
- [ ] If blocked: implement behavior cloning basics (mouse movement, timing)
- [ ] Validate: Yelp search loads without CAPTCHA, no cookies needed
- [ ] Update golden test with stealth resource globals if needed

---

## 3. Ralph-Loop 2-Hat Mode

**Status:** 1-hat mode works. Try 2-hat mode with real workloads.

### Tasks
- [ ] Run selector resilience (#1) as ralph 2-hat plan+build task
- [ ] Run Yelp stealth (#2) as ralph 2-hat research+implement task
- [ ] Document what worked / what broke in 2-hat mode

---

## 4. CLI Unification — WiseRpaBDD.py as Single Entry Point

**Status:** AgentRunner.py has BDD validation, dryrun wrapper, and agent
generation. These should be modes of WiseRpaBDD.py.

### Target interface
```bash
python WiseRpaBDD.py run tests/golden/quotes-test.robot          # live execution
python WiseRpaBDD.py dryrun tests/golden/quotes-test.robot       # keyword check
python WiseRpaBDD.py validate tests/golden/quotes-test.robot     # BDD lint
python WiseRpaBDD.py generate "Scrape quotes from ..." -o out.robot  # agent gen
```

### Tasks
- [ ] Add CLI argument parser to WiseRpaBDD.py (argparse, subcommands)
- [ ] Move `validate_bdd()` from AgentRunner.py → WiseRpaBDD.py
- [ ] Move dryrun wrapper from AgentRunner.py → WiseRpaBDD.py
- [ ] Move `_run_agent()` from AgentRunner.py → WiseRpaBDD.py `generate` mode
- [ ] Update e2e_test robot to use WiseRpaBDD as the library (not AgentRunner)
- [ ] Delete AgentRunner.py
- [ ] Update e2e_test robot requirements to match cleaned golden Comments

---

## 5. Raw Browser Action Docs + Golden Tests

**Status:** `browser step` and `call keyword` implemented and documented.
No golden test exercises them yet.

### Tasks
- [ ] Create golden test for `And I call keyword` (auth flow against
      quotes.toscrape.com/login using RF keyword with raw Browser calls)
- [ ] Verify existing quotes-login-test.robot (uses pure action keywords)
      passes as Option 0 baseline
- [ ] Dryrun + live validation for new golden test
- [ ] Handle browser step method name case-sensitivity across backends

---

## 6. File-Backed Data Model (Future — Design Only)

**Problem:** Current runtime holds all artifact data in memory (Python dicts/lists).
For large scraping projects (10K+ pages, GB-scale body content), this won't fit on
modest laptops.

### Design considerations
- Replace in-memory `artifact_store: dict[str, list]` with a file-backed store
- Options: SQLite (single file, zero deps), JSONL append (simplest), DuckDB (analytics)
- Streaming writes: emit records to disk immediately, don't accumulate
- Quality gates scan the file rather than in-memory list
- Output step becomes a file copy/transform rather than JSON dump
- Deduplication via indexed field (SQLite UNIQUE constraint)
- Must remain transparent to .robot suite authors — no syntax changes

### Design (approved 2026-04-09)

The problem is not just the artifact store — it's the entire walk state.
Every `_walk_rule`, `_expand_pages_*`, `_expand_elements` returns `list[dict]`
up the call stack. At peak, 100K records exist twice: in the walk's return
values AND in `artifact_store`. With 60KB/record, that's 12GB.

**Approach: write-through to SQLite, return IDs not dicts.**

- `_emit_records` writes directly to SQLite, returns nothing heavy
- Walk functions return `list[int]` (record IDs) instead of `list[dict]`
- `_children` nesting reconstructed at `_write_outputs` time via parent_id
- One SQLite file per deployment (`output/{name}/{name}.db`)
- Dynamic DDL: one table per artifact, columns from `register artifact` fields
- Quality gates become SQL: `SELECT COUNT(*) WHERE field IS NOT NULL`
- BLOB columns for HTML body, screenshots, binary data
- Keyword change: `Given I start deployment "${DEPLOYMENT}"  backend=sqlite`
- `backend=memory` (default) preserves current behavior for small jobs

**What doesn't change:** keyword API, .robot syntax, rule tree structure,
expansion/extraction logic. Only the record storage layer swaps out.

### Tasks
- [ ] Implement `SQLiteRecordStore` with append/iter/len/filled_pct
- [ ] Refactor `_walk_rule` to return record IDs when backend=sqlite
- [ ] Refactor `_emit_records` to write-through
- [ ] Refactor `_write_outputs` to reconstruct nested trees from parent_id
- [ ] Add `backend=` option to deployment keyword
- [ ] Test: run quotes + splunk-itsi with backend=sqlite, compare outputs
- [ ] Test: verify memory stays flat with 1K+ records

---

## Accept When

- [x] `python WiseRpaBDD.py run|dryrun|validate|generate` all work (DONE)
- [x] AgentRunner.py deleted, e2e test uses WiseRpaBDD (DONE)
- [x] Codex backend tested — generates valid suites with agent-browser (DONE)
- [ ] At least one golden test uses fallback selectors and passes live
- [ ] Yelp stealth validated (pass or documented blocker)
- [ ] Existing 22 golden tests still pass dryrun
- [ ] File-backed data model design documented
