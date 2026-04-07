# Wise RPA BDD Skill

Create a new sibling skill at `skills/wise-rpa-bdd/`.

The skill must teach Codex to draft strict Robot Framework BDD suites for RPA-style browser extraction.
The suite is the spec. Output must be real `.robot`, not a pseudo-DSL.

Requirements:

1. The skill must preserve generality.
All executable steps must use generic BDD keywords.
Do not invent site-specific keyword names.
Site specifics belong in variables, arguments, continuation tables, selectors, URLs, and extract definitions.

2. The skill must preserve explicit extraction-flow structure without hiding it.
Keep artifacts, resources, background/setup, parent-child chaining, emits, and quality gates explicit.
Between-rule state should be visible in variables and named steps rather than hidden in opaque engine calls.

3. The skill must assume the runtime is Robot Framework with the right keyword library.
Use `Suite Setup`, `Suite Teardown`, `[Setup]`, and `[Teardown]` when helpful.
Keep the format strict enough that `robot --dryrun` can validate suites.

4. Include a minimal generic keyword library for validation and examples.
It can be a no-op or logging stub, but it must let Robot resolve the drafted keywords.

5. Include references and templates.
Keep `SKILL.md` concise and push detailed format/keyword/mapping material into `references/`.

6. Use distinct `/rrpa-*` mode verbs to mark the current action or state for the executing agent.
At minimum support:
`/rrpa-orient`, `/rrpa-explore`, `/rrpa-evidence`, `/rrpa-draft`, `/rrpa-validate`, `/rrpa-refine`, `/rrpa-ship`.

7. Include tested phase examples with checked-in outputs, not just suite files.
Each representative example should show:
   - task brief
   - exploration/evidence notes
   - drafted suite
   - validation outputs

8. Validate the new skill against the bundled regression profile corpus.
Provide a harness that drafts `.robot` suites from that corpus and runs:
   - a strict BDD format validator
   - `robot --dryrun`

Acceptance:

- A new `skills/wise-rpa-bdd/` exists with `SKILL.md`.
- The skill explains strict Robot Framework BDD authoring for generic RPA extraction flows.
- A minimal `WiseRpaBDD` library exists and resolves the documented keywords.
- A generator can draft `.robot` suites from the bundled regression profile corpus.
- A harness runs against that profile corpus and passes.
- The skill body is concise and operational rather than repeating the workflow reference.
- Checked-in phase examples exist with outputs and pass a dedicated phase harness.
