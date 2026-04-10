# wise-rpa-bdd E2E Test Suite

## Context

Commit 6f68a0c achieved formal feature parity between wise-rpa-bdd and
wise-scraper (keyword contract, templates, generator, reference docs).
Now we need a full E2E test suite proving every capability works.

The generator lives at `skills/wise-rpa-bdd/scripts/generate_from_wise_yaml.py`.
Validation tooling lives at `skills/wise-rpa-bdd/scripts/validate_suite.py`.
All 15 wise-scraper test profiles are the inputs — 8 practice, 7 production.

## Phase 1 — Robot file generation accuracy (all 15 profiles)

- Run `generate_from_wise_yaml.py` against EVERY wise-scraper test profile:
  - Practice (8 in `skills/wise-scraper/tests/profiles/practice/`):
    quotes-test, laptop-test, laptop-paginated-test, revspin-test,
    books-mystery-test, variants-test, tables-test, webscraper-ecommerce
  - Production (7 in `skills/wise-scraper/tests/profiles/production/`):
    splunk-itsi-test, splunk-itsi-focused-test, splunk-spl2-test,
    splunk-spl2-overview-test, hamilton-doc-test, amazon-plumbing-test,
    umsalary-test
- Validate EVERY generated `.robot` with `validate_suite.py` — 0 errors
- Validate EVERY generated `.robot` with `robot --dryrun` — 0 failures
- Fix generator bugs until 15/15 pass both gates
- Check in generated `.robot` suites under:
  - `skills/wise-rpa-bdd/tests/profiles/practice/`
  - `skills/wise-rpa-bdd/tests/profiles/production/`

## Phase 2 — Test harness with clear output

- Update `tests/harness/run-tests.py` to:
  - Generate + validate all 15 profiles automatically
  - Print a summary table: profile name | generate | BDD validate | dryrun
  - Exit 0 only when ALL pass, exit 1 on ANY failure
  - Show diffs or error details for failures, not just pass/fail
- Update `tests/harness/run-phase-tests.py` to validate the 3 checked-in
  examples (quotes, revspin, splunk-itsi) with the same output format
- Add `tests/test_emit_synthesis.py` coverage for new AI extraction and
  hook rendering paths in the generator

## Phase 3 — Live scraping validation (all practice profiles)

- Execute generated suites against ALL practice site targets:
  - quotes.toscrape.com (pagination + element expansion)
  - webscraper.io laptop pages (element + paginated variants)
  - revspin.net (sort + numeric pagination + table)
  - books.toscrape.com (nested expansion + JMESPath)
  - webscraper.io variants (matrix/click expansion)
  - webscraper.io tables (table extraction)
- Compare output artifacts against wise-scraper baseline outputs in
  `skills/wise-scraper/tests/output/`
- Document behavioral gaps in a test report
- Check in sample outputs under `skills/wise-rpa-bdd/tests/output/`

## Accept when

- 15/15 profiles generate valid `.robot` suites
- `validate_suite.py` passes on all 15 (0 BDD errors)
- `robot --dryrun` passes on all 15 (0 keyword resolution failures)
- `run-tests.py` exits 0 with a clean summary table
- `run-phase-tests.py` exits 0 for all 3 examples
- At least 6 practice profiles produce live scraping output
- Test outputs are checked in and comparable to wise-scraper baselines
