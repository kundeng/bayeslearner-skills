# Examples Overview

These examples are organized by **phase artifacts**, not just by suite file.

Each example directory shows the same loop:

1. `/rrpa-orient` — task brief
2. `/rrpa-explore` and `/rrpa-evidence` — selector proof and traversal notes
3. `/rrpa-draft` — the checked-in `.robot` suite
4. `/rrpa-validate` — checked-in validator and dry-run outputs

## Tested Examples

- `quotes/` — simple next-page pagination plus element extraction
- `revspin/` — sort action, numeric pagination, table-like row extraction
- `splunk-itsi/` — multi-resource discovery and extraction chaining

## Validation

Use:

```bash
python skills/wise-rpa-bdd/tests/harness/run-phase-tests.py
python skills/wise-rpa-bdd/tests/harness/run-tests.py
```

The first validates the checked-in phase examples.
The second regression-tests the skill against the bundled profile corpus.
