# Context: Wise RPA BDD Skill

## Source Type
Rough description → normalized into implementation plan.

## Original Request Summary
Create `skills/wise-rpa-bdd/` — a skill teaching Codex to draft strict Robot Framework BDD suites for RPA-style browser extraction. The suite IS the spec. Output must be real `.robot`, not pseudo-DSL.

## Current State (as of build.start)
The skill is **substantially implemented** and all acceptance criteria are met:

- `skills/wise-rpa-bdd/SKILL.md` — complete skill entry point
- `references/` — format.md, keyword-contract.md, mapping-from-wise.md
- `scripts/WiseRpaBDD.py` — 180-line generic keyword library with 36 keywords, all no-op/logging stubs
- `scripts/generate_from_wise_yaml.py` — YAML-to-robot generator (296 lines)
- `scripts/validate_suite.py` — strict BDD format validator
- `tests/harness/run-tests.py` — test harness integrating generate + validate + dryrun
- `templates/` — base.robot, listing-detail.robot, multi-resource-docs.robot
- `examples/` — quotes.robot, revspin.robot, splunk-itsi.robot

**Test harness result: 15/15 profiles pass** (generate + BDD format + robot dryrun).

## Remaining Work
1. Verify generated examples match checked-in examples (or regenerate to ensure consistency)
2. Clean up `__pycache__` from scripts/ directory
3. Verify the revspin.robot example has emit steps (appears missing in checked-in version vs what generator would produce)
4. Final validation pass — run harness, dryrun examples individually
5. Commit the skill

## Repo Patterns
- Skills live in `skills/<name>/` with `SKILL.md` as entry point
- References in `references/`, templates in `templates/`, examples in `examples/`
- Tests in `tests/harness/`
- Python scripts use `from __future__ import annotations`, type hints, `@library` decorator

## Acceptance Criteria
1. ✅ `skills/wise-rpa-bdd/` exists with `SKILL.md`
2. ✅ Skill explains strict Robot Framework BDD authoring for generic RPA extraction flows
3. ✅ Minimal `WiseRpaBDD` library exists and resolves documented keywords
4. ✅ Generator drafts `.robot` suites from original WISE YAML test profiles
5. ✅ Harness runs against original WISE test profiles and passes (15/15)
6. ✅ Checked-in `.robot` examples from representative WISE cases (3 examples)

## Constraints
- Robot Framework 7.4.2 and PyYAML available
- All keywords must be generic (no site-specific verbs)
- `robot --dryrun` must pass with the keyword library
