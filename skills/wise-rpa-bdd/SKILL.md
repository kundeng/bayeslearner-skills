---
name: wise-rpa-bdd
description: Structured browser extraction for AI coders: explore first, then draft repeatable Robot Framework BDD RPA suites with shipped generic keywords, templates, and validation harnesses.
metadata:
  author: kundeng
  version: "0.2.0"
---

# WISE RPA BDD

WISE RPA BDD teaches an AI coding agent **structured, repeatable browser extraction** through **real executable `.robot` suites**. The product is a **repeatable exploitation artifact**, not an exploration transcript.

> **Rule 0 — Orient before acting.** Before opening a browser or drafting a suite, read `references/workflow.md § Big Picture` so you understand the shipped harness, keyword library, and what evidence you need to gather.

```
/rrpa-orient → /rrpa-explore → /rrpa-evidence → /rrpa-draft → /rrpa-validate → /rrpa-refine → /rrpa-ship
```

Use when:
- the user wants Robot Framework syntax
- the flow should read as BDD (`Given/When/Then/And/But`)
- the task is repeatable browser extraction, navigation, pagination, table capture, or multi-step detail scraping
- the task needs generic browser-automation keywords with explicit artifacts, resources, and chaining

Do not use when:
- a stable API/export is clearly enough
- the user wants a full production browser runtime implementation right now

## Mode Verbs

Use these mode verbs in your scratchpad, notes, or progress updates so the current action is obvious:

- `/rrpa-orient` — read the workflow, keyword contract, and templates before touching the target
- `/rrpa-explore` — inspect the live site, test selectors, map auth, pagination, and detail traversal
- `/rrpa-evidence` — write down proof: selectors, DOM notes, merge keys, state markers, sample rows
- `/rrpa-draft` — draft or refine the `.robot` suite using the shipped generic harness
- `/rrpa-validate` — run `validate_suite.py` and `robot --dryrun`
- `/rrpa-refine` — tighten variables, continuation rows, resources, and setup after validation
- `/rrpa-ship` — deliver the suite plus the supporting evidence and outputs needed for reruns

## Non-Negotiables

1. Output only valid Robot Framework syntax.
2. All executable steps in `*** Test Cases ***` and `*** Keywords ***` must use `Given`, `When`, `Then`, `And`, or `But`.
3. Use a **generic keyword library**. Never invent site-specific executable keyword names.
4. Put site specifics in variables, step arguments, continuation rows, locators, URLs, and field specs.
5. Keep artifacts, resources, setup, parent chaining, emits, and quality gates explicit.
6. AI may help author or repair locators, extract specs, and suite structure. AI must not change the fundamentals of the generic keywords.

## Agent Contract

1. Start in `/rrpa-orient`, not `/rrpa-draft`.
2. Use `/rrpa-explore` before committing to selectors or flow boundaries.
3. Produce `/rrpa-evidence` before claiming the suite is ready.
4. Prefer shipped templates, generic keywords, and validation harness pieces.
5. Extend the harness only with new **generic** capabilities.
6. The final suite must be readable and rerunnable by another agent.

## Authoring Shape

Treat the Robot suite as the public exploitation spec:

- **Deployment** → suite variables and setup/teardown
- **Artifact** → named registration plus emit/merge/write steps
- **Resource** → one or more test cases
- **Background** → `Suite Setup`, `Test Setup`, or reusable generic BDD keywords
- **Rule block** → named steps inside a resource case
- **Parent-child chaining** → explicit parent iteration or artifact consumption

Avoid collapsing the flow into one opaque keyword.

## Read Next

- Operating loop and shipped harness: `references/workflow.md`
- Format and suite layout: `references/format.md`
- Allowed generic keywords: `references/keyword-contract.md`
- Flow shape and structural conventions: `references/flow-shape.md`
- Harness usage and validation loop: `references/harness.md`
- Internal architecture and data model: `references/architecture.md`
- AI extraction pattern: `references/ai-adapter.md`
- Plain English field reference: `references/field-guide.md`
- Positioning and alternatives: `references/comparisons.md`
- Starter files: `templates/*.robot`
- Tested examples and outputs: `examples/overview.md`

## Publish Bar

Do not publish the skill until:

- the skill body is concise and operational
- the suite is grounded in evidence
- the drafting harness passes
- the regression harness passes
- examples include phase artifacts and checked-in outputs
