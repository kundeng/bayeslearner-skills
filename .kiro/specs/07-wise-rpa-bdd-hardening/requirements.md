# spec-07: wise-rpa-bdd Hardening & Tooling

Created 2026-04-09 after completing spec-06 open issues.

## Goals

1. ~~Complete Splunk-ITSI extraction (selector tuning, AI arg-length)~~ RESOLVED
2. ~~Jinja2 template filters for URL interpolation~~ DEFERRED (0/21 tests need it)
3. Dev → main merge workflow (after all tests green)
4. Smart selector resilience (HARPA-style fallback chain + sponsored filter)
5. Ralph-loop — try 2-hat mode with items 1+6 as workloads
6. Server-side fingerprint defeat for Yelp/DataDome (active research)

---

## 1. Splunk-ITSI Completion — RESOLVED

Selectors fixed to `main article` + `h1` (commit 96d712c). AI extraction
pipes via stdin (commit a80a40a). 18 records with 100% fill achieved (fefc04e).
Dryrun: 6/6 tests pass.

---

## 2. Jinja2 Template Filters — DEFERRED

**Decision**: 0/21 golden tests would benefit today. All 4 tests using URL
templates interpolate URL-type fields that are already safe. Simple str.replace()
works correctly. Revisit when search-query-in-URL patterns arise.

---

## 3. Dev → Main Merge

**Status**: dev branch has pyproject.toml, tests/, AgentRunner.py, .gitignore.
Main has only shippable files.

### Strategy
- Promote only: `scripts/WiseRpaBDD.py`, `docs/`, golden tests (as examples)
- Keep on dev: pyproject.toml, .venv, tests/fixtures/, .coverage
- Create `.gitattributes` or merge script for selective promotion

### Tasks
- [ ] Define shippable file list
- [ ] Cherry-pick or merge --no-commit + selective staging
- [ ] Verify main branch passes smoke test without dev tooling

---

## 4. Smart Selector Resilience — REINSTATED

**Evidence**: MDN incident was NOT a DOM change — it was a bad explore-phase
guess (`div.section-content` vs actual `.content-section`) compounded by
framework bugs. Sponsored items at top of listings also get scraped.

### Approach (HARPA-inspired, incremental)

**A. Fallback selector chain** (low effort, high value):
- Pipe-delimited: `a.title | h2.title | [data-field="title"]`
- Try each, return first match. Backward-compatible with plain selectors.

**B. Sponsored item filter** (low effort):
- Skip items matching text patterns ("Sponsored", "Ad", "Promoted")
- Skip items matching CSS markers (`[data-ad]`, `[class*="sponsor"]`)
- Configurable via resource globals: `skip_sponsored=true`

**C. Content validation post-filter** (low effort):
- Field-level regex patterns reject false positives after extraction
- e.g., price must match `\$\d+\.\d{2}`, rating must match `\d(\.\d)?`

**D. HARPA-style $matches** (medium effort, future):
- Multi-attribute fuzzy matching with min threshold
- Describe element by 5 attributes, require 3+ to match

### Tasks
- [ ] Implement fallback selector chain in `_extract_field`
- [ ] Implement sponsored item filter in `_expand_elements`
- [ ] Add golden test exercising fallback + sponsored filter
- [ ] Document selector strategies in references

---

## 5. Ralph-Loop — 2-Hat Mode Test

**Status**: 1-hat mode works fine. Try 2-hat mode with real workloads.

### Test workloads
- [ ] Splunk-ITSI live run verification as ralph 2-hat task
- [ ] Stealth mode prototype as ralph 2-hat design+build task

---

## 6. Yelp Server-Side Fingerprint Defeat

**Status**: Research in progress (subagent).

### Known
- All client-side detection defeated (Sannysoft clean pass)
- Server-side detection remains (TLS fingerprint, HTTP/2, CDP leaks)
- Cookie injection hack REMOVED (was fragile and wrong approach)

### Approach
Must use stealth mode with behavior cloning — NO cookie theft/injection.
Research active on: real Edge subprocess+CDP, patchright, rebrowser-patches,
behavior cloning (ghost-cursor, dwell-time, scroll patterns).

### Tasks
- [x] Remove cookie injection code and fixtures from codebase
- [ ] Evaluate research findings (TLS/JA3, HTTP/2, rebrowser/patchright)
- [ ] Implement behavior cloning basics (mouse movement, timing jitter)
- [ ] Prototype most promising TLS approach
- [ ] Validate: Yelp search loads without CAPTCHA, no cookies needed
