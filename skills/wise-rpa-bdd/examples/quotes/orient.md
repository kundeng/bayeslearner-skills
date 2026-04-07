# /rrpa-orient

## Goal

Collect quote text, author, and tags from `https://quotes.toscrape.com/`.

## Target

- **Site:** quotes.toscrape.com
- **Auth:** none required
- **Content type:** paginated list of quote cards

## Deliverables

- Repeatable Robot Framework BDD suite (`suite.robot`)
- Two artifacts: `quotes` (nested tree) and `quotes_flat` (flat denormalized)
- Validation outputs proving the suite resolves against the shipped harness

## Constraints

- Use the shipped `WiseRpaBDD` keyword library — no custom Python keywords
- Suite must pass `validate_suite.py` (BDD format gate) and `robot --dryrun` (execution gate)
- Minimum 25 records expected across paginated pages
