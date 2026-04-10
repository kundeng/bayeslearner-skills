# wise-rpa-bdd Live Scraping Validation (continuation)

## Context

This continues spec `03-wise-rpa-bdd-e2e` which completed Phases 1-2 and
Phase 3 browser automation (commit `38743ad`). Two tasks remain: execute
practice profiles against live sites and compare outputs to baselines.

**Already done (do NOT redo):**
- 15/15 .robot suites generated, validated, checked in (`8558723`)
- Test harness with summary tables, 14 unit tests (`be7f72a`)
- `WiseRpaBDD.py` Playwright browser automation library (`38743ad`)
- `run-tests.py` exits 0, `run-phase-tests.py` exits 0

**This is a single merged task — do NOT split into separate build/review cycles.**

## Task: Live execution + baseline comparison + report

Execute generated `.robot` suites against ALL 8 practice site targets,
compare outputs to wise-scraper baselines, and produce a gap report.

### Step 1 — Execute practice profiles

Run each generated suite against its live target:
- `quotes-test.robot` against quotes.toscrape.com
- `laptop-test.robot` against webscraper.io laptop pages
- `laptop-paginated-test.robot` against webscraper.io laptop pages (paginated)
- `revspin-test.robot` against revspin.net
- `books-mystery-test.robot` against books.toscrape.com
- `variants-test.robot` against webscraper.io variants
- `tables-test.robot` against webscraper.io tables
- `webscraper-ecommerce.robot` against webscraper.io e-commerce

Use `robot --pythonpath skills/wise-rpa-bdd/scripts/` to run each suite.
Capture output artifacts (JSON/CSV) under `skills/wise-rpa-bdd/tests/output/`.

If a site is unreachable or a suite fails at runtime, document the failure
and move on. Do not block on individual site issues.

### Step 2 — Compare to baselines

Baseline outputs are in `skills/wise-scraper/tests/output/`.
For each profile that produced output, compare:
- Record count (how many items extracted)
- Field names and coverage
- Data structure (flat vs nested)
- Any missing or extra fields

### Step 3 — Write gap report and check in

Write `skills/wise-rpa-bdd/tests/output/COMPARISON_REPORT.md` with:
- Summary table: profile | status | records (rpa) | records (scraper) | gaps
- Per-profile section with specific differences
- Known limitations of the BDD approach vs direct scraping

Check in all output artifacts and the report.

## Accept when

- At least 6 of 8 practice profiles produce live scraping output
- Output artifacts are checked in under `skills/wise-rpa-bdd/tests/output/`
- `COMPARISON_REPORT.md` exists with per-profile comparison
- All existing tests still pass (`run-tests.py` exits 0)
