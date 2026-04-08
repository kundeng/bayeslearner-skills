# Harness

This skill ships two harness layers:

## 1. Drafting Harness

Use the drafting harness while turning exploration evidence into a repeatable suite.

Core pieces:

- `templates/*.robot` — starter structures
- `scripts/WiseRpaBDD.py` — generic keyword library
- `scripts/validate_suite.py` — strict BDD validator

Typical loop:

1. `/rrpa-explore` — visit live site, confirm selectors, collect evidence
2. `/rrpa-draft` — write the `.robot` suite grounded in explore evidence
3. `/rrpa-review` — run `robot --dryrun`, fix issues, loop back to draft until clean

## 2. E2E Test

`tests/e2e_test_agent_generates_valid_suites.robot` — sends requirement strings to the AI agent via Claude Agent SDK, validates the generated `.robot` suite passes BDD validation and dryrun, and compares against vetted golden baselines in `tests/golden/`.

## Explorer-Driven Usage

When an AI agent is given a task:

1. read `SKILL.md`
2. read `references/workflow.md`
3. inspect the target with a browser tool
4. gather evidence
5. draft a suite using the templates and keyword contract
6. validate with the drafting harness

The harness exists to make exploitation repeatable after exploration, not to replace exploration.

## Minimum Validation Commands

```bash
python skills/wise-rpa-bdd/scripts/validate_suite.py path/to/suite.robot
python -m robot --dryrun --output NONE --log NONE --report NONE \
  --pythonpath skills/wise-rpa-bdd/scripts \
  path/to/suite.robot
```

## When To Extend The Harness

Extend the harness only when the task truly exceeds the current generic contract.

Examples:

- a generic keyword for a missing browser action
- a generic artifact merge helper
- a reusable continuation-row parser

Do not extend the harness just to encode one site's names or business nouns.
