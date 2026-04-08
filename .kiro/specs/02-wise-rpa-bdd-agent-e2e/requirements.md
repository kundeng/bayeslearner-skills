# Wise RPA BDD Agent E2E

Build one bounded, real agent-through-phases E2E slice for `skills/wise-rpa-bdd/`.

This spec is intentionally narrower than the original skill draft. The goal is not to publish everything. The goal is to prove that an AI agent given a task prompt can move through the skill's `/rrpa-*` phases and leave behind clear, inspectable artifacts.

Scope:

- Focus on the `quotes` example only.
- Reuse the existing `skills/wise-rpa-bdd/` structure instead of redesigning the whole skill.
- Do not try to implement a production browser backend.
- Do not widen the scope to all regression profiles.

Required outcome:

Given a task brief for the quotes target, the shipped harness must support an agent workflow that clearly produces artifacts for:

1. `/rrpa-orient`
2. `/rrpa-explore`
3. `/rrpa-evidence`
4. `/rrpa-draft`
5. `/rrpa-validate`
6. `/rrpa-refine`
7. `/rrpa-ship`

Deliverables:

1. A small agent-E2E harness under `skills/wise-rpa-bdd/tests/harness/` that validates the phase flow for the quotes example.
2. A quotes example layout that contains explicit per-phase artifacts, not just a suite and a dryrun log.
3. Skill docs updated only as needed so the agent workflow is concise and executable rather than repetitive.
4. Checked-in outputs from the new agent-E2E harness.

Artifact contract for the quotes example:

- `task.md` or equivalent task brief
- `orient.md`
- `explore.md`
- `evidence.md`
- `suite.robot`
- `output/validate.txt`
- `output/dryrun.txt`
- `refine.md`
- `ship.md`

Acceptance criteria:

1. The quotes example contains all required phase artifacts above.
2. A dedicated harness command exists and passes for the quotes example.
3. The harness must fail if a required phase artifact is missing or empty.
4. The harness must verify that `suite.robot` passes:
   - `python skills/wise-rpa-bdd/scripts/validate_suite.py ...`
   - `python -m robot --dryrun --output NONE --log NONE --report NONE --pythonpath skills/wise-rpa-bdd/scripts ...`
5. `skills/wise-rpa-bdd/SKILL.md` stays concise; detailed workflow material belongs in references or examples.
6. The loop should end only after the reviewer has verified the agent-phase artifacts and the quotes harness output.

Execution guidance for the hats:

- Break the work into a few bounded tasks, not one giant rewrite.
- Prefer 2-4 concrete tasks with explicit acceptance criteria.
- Do not spend time on commit/publish cleanup outside this scope.
- If the loop fails, write the real reason into the scratchpad and memories so we can improve the Ralph process later.
