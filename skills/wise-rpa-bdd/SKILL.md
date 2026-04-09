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
/rrpa-orient → /rrpa-explore → /rrpa-draft ⇄ /rrpa-review → /rrpa-ship
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
- `/rrpa-explore` — use `agent-browser` CLI (via Bash) to visit the live site, test CSS selectors against the real DOM, map auth, pagination, and detail traversal. Every selector in the final suite must come from live exploration. `agent-browser` keeps a persistent browser session across calls — no special flags needed. **Be efficient**: confirm selectors on representative pages — do NOT crawl every page or enumerate all pagination links. Exploration should complete under 1 minute. Output: confirmed selectors, DOM notes, sample data.

### agent-browser quick reference

```bash
npx agent-browser open <url>          # navigate (persistent session)
npx agent-browser snapshot -c -d 3    # accessibility tree with CSS classes
npx agent-browser get count '<css>'   # count matching elements
npx agent-browser get text '<css>'    # get text content
npx agent-browser get html '<css>'    # get outer HTML
npx agent-browser eval '<js>'         # run JS expression
npx agent-browser click '<css>'       # click element
npx agent-browser close               # close browser session
```

Chain commands with `&&` in one Bash call. The browser session persists between calls — no need to reopen.

- `/rrpa-draft` — draft the `.robot` suite using WiseRpaBDD keywords, grounded in explore evidence
- `/rrpa-review` — run `robot --dryrun` to verify keyword resolution, tighten variables, fix issues. Loops back to `/rrpa-draft` until the suite is clean.
- `/rrpa-ship` — package the suite, WiseRpaBDD keyword library, and any custom resources into the target project with proper structure, documentation, and a ready-to-run layout

## Non-Negotiables

1. Output only valid Robot Framework syntax.
2. All executable steps in `*** Test Cases ***` and `*** Keywords ***` must use `Given`, `When`, `Then`, `And`, or `But`.
3. Use a **generic keyword library**. Never invent site-specific executable keyword names.
4. Put site specifics in variables, step arguments, continuation rows, locators, URLs, and field specs.
5. Keep artifacts, resources, setup, parent chaining, emits, and quality gates explicit.
6. AI may help author or repair locators, extract specs, and suite structure. AI must not change the fundamentals of the generic keywords.

## Agent Contract

1. Start in `/rrpa-orient`, not `/rrpa-draft`.
2. Use `/rrpa-explore` before committing to selectors or flow boundaries. No guessing.
3. `/rrpa-draft` and `/rrpa-review` loop until `robot --dryrun` passes clean.
4. Prefer shipped templates, generic keywords, and the WiseRpaBDD library.
5. Extend the library only with new **generic** capabilities.
6. `/rrpa-ship` delivers a self-contained package: suite, keyword library, docs, ready to run.

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

- `references/workflow.md` — operating loop and phases
- `references/format.md` — suite structure, patterns, and AI role
- `references/keyword-reference.md` — complete keyword API with examples
- `references/architecture.md` — runtime data model and internals
- `references/harness.md` — validation and E2E testing

## Publish Bar

Do not publish the skill until:

- the skill body is concise and operational
- the suite is grounded in evidence
- the drafting harness passes
- the regression harness passes
- examples include phase artifacts and checked-in outputs
