# spec-07: wise-rpa-bdd Hardening & Tooling

Created 2026-04-09 after completing spec-06 open issues.

## Goals

1. Complete Splunk-ITSI extraction (selector tuning, AI arg-length)
2. Jinja2 template filters for URL interpolation
3. Dev → main merge workflow
4. Smart selector resilience
5. Ralph-loop reliability fix — use items 1-4 as test workloads
6. Server-side fingerprint defeat for Yelp/DataDome (research in progress)

---

## 1. Splunk-ITSI Completion

**Status**: Chaining fixed (consumes + self-selector). Selectors need tuning.

### Problems
- `article[role='article']` state check fails on some Splunk help pages
  (DOM may have changed, or section landing pages lack article element)
- AI extraction hits `OSError: Argument list too long` — HTML body too large
  for CLI arg to aichat

### Tasks
- [ ] Explore current Splunk help.splunk.com DOM for correct content selector
- [ ] Fix AI extraction to pipe body via stdin instead of CLI arg
- [ ] Re-run and validate quality gates (target: 20+ records with title+body)

---

## 2. Jinja2 Template Filters

**Status**: Not started. Spec from resume prompt.

### Motivation
Current URL template interpolation uses naive `{field}` replacement.
Need Jinja2-style filters for:
- `{field | urlencode}` — URL-encode field values
- `{field | default('fallback')}` — default values
- `{field | regex_replace('pattern', 'repl')}` — regex transforms
- `{field | relative('/base')}` — resolve relative paths

### Tasks
- [ ] Replace `str.replace()` in `_resolve_entry_urls` with Jinja2 rendering
- [ ] Add jinja2 to pyproject.toml dependencies
- [ ] Add golden test exercising at least urlencode + default filters
- [ ] Update docs

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

## 4. Smart Selector Resilience

**Status**: Not started. Motivated by Yelp's dynamic CSS hashes.

### Problem
Sites like Yelp use hashed CSS classes (`y-css-12f4fi2`) that break on
every deploy. Current golden tests use fragile selectors.

### Approach
Ranked fallback strategy per field:
1. Semantic: `[data-testid]`, `[aria-label]`, `[role]`
2. Structural: `h1`, `main > p:first-of-type`, heading hierarchy
3. Text-content: `:has-text()`, `:text-matches()`
4. Positional: `>> nth=N` relative to stable parent

### Tasks
- [ ] Research HARPA/similar selector resilience patterns
- [ ] Design selector scoring/ranking for explore phase
- [ ] Implement selector fallback in `_extract_field` (try primary, fall back)
- [ ] Document recommended selector strategies per site type

---

## 5. Ralph-Loop Reliability

**Status**: Hangs ~10 min on first activation. Workaround: manual impl.

### Investigation plan
- [ ] Check ralph logs during hang (`~/.ralph/logs/`)
- [ ] Test with minimal skill set (disable MCP servers)
- [ ] Test with Sonnet instead of Opus (faster first-token)
- [ ] Profile: is it thinking, or rate-limited, or loading context?

### Test workloads (use items 1-4)
- [ ] Splunk-ITSI selector fix as ralph single-task spec
- [ ] Jinja2 filters as ralph multi-task spec
- [ ] Dev→main merge as ralph review task
- [ ] Selector resilience as ralph design task

---

## 6. Yelp Server-Side Fingerprint Defeat

**Status**: Research in progress (subagent).

### Known
- All client-side detection defeated (Sannysoft clean pass)
- Server-side detection remains (TLS fingerprint, HTTP/2, CDP leaks)
- Cookie approach works but is fragile and ugly

### Tasks
- [ ] Evaluate research findings (TLS/JA3, HTTP/2, rebrowser/patchright)
- [ ] Prototype most promising approach
- [ ] Validate: Yelp search loads without CAPTCHA, no cookies needed
