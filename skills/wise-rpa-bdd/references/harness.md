# Harness

This skill ships two harness layers:

## 1. Drafting Harness

Use the drafting harness while turning exploration evidence into a repeatable suite.

Core pieces:

- `templates/*.robot` — starter structures
- `scripts/WiseRpaBDD.py` — generic keyword library
- `scripts/validate_suite.py` — strict BDD validator

Typical loop:

1. `/rrpa-explore`
2. `/rrpa-evidence`
3. `/rrpa-draft`
4. `/rrpa-validate` with `validate_suite.py`
5. `/rrpa-validate` with `robot --dryrun`
6. `/rrpa-refine` until the suite is readable and executable

## 2. Regression Harness

Use the regression harness to test the skill against the bundled profile corpus.

- `tests/harness/run-tests.py`
- `tests/harness/run-phase-tests.py`

This harness drafts suites from the corpus, validates BDD structure, and runs `robot --dryrun`. It is a regression check for the skill itself, not the main authoring experience.

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
