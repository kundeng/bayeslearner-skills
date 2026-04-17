# AI Artifact Update

Reference for `workflow-guardrails`: how an agent should keep project artifacts
— specs, design docs, steering docs, user docs, analysis records — honest as
the code evolves. This is the failure mode individual workflow skills do not
catch because each skill focuses on its own flow; drift happens *between* them.

Use this when code has just landed or is about to land, and one or more of
these artifacts may need to move too. Keep updates surgical. Merge, don't
clobber.

## Artifact Taxonomy

Typical layers an AI-authored project maintains:

- **Spec artifacts** — `requirements.md`, `design.md`, `tasks.md` under
  `.kiro/specs/NN-name/`, or a single `spec.md` for fast-track. Owned by the
  `spec-driven-dev` skill. Each spec has a lifecycle state (DRAFT → ACTIVE →
  SHIPPED → SUPERSEDED / OBSOLETE).
- **Feature ledger** — project-level living inventory of features across all
  specs, by status. Answers *what exists now*. Structure should be
  hierarchy-graphable. Owned by `spec-driven-dev`; file typically at
  `.kiro/FEATURES.md`.
- **Snapshots** — dated, frozen copies of the feature ledger + architecture
  state at release boundaries. Typically at `.kiro/snapshots/YYYY-MM-NN.md`.
  Not edited after creation.
- **Steering docs** — `.kiro/steering/product.md`, `structure.md`, `tech.md`.
  Read-only during a task; updated deliberately when the project mode changes.
- **Project steering file** — `CLAUDE.md`, `AGENTS.md`. Tells future agents how
  to work in this repo.
- **Design records / ADRs** — decisions with rationale, living next to the
  spec's `design.md` Decisions section or as standalone files.
- **User-facing docs** — READMEs, tutorials, user guides, reference pages. Owned
  by the `doc-coauthoring` skill when substantial.
- **Analysis records** — question, assumptions, runs, findings. Owned by the
  `analytic-workbench` skill.
- **Handoff state** — the session-handoff section of `CLAUDE.md` or a dedicated
  handoff file.

## Core Principles

- **Co-evolve, do not catch up later.** Update artifacts in the same working
  session as the code change. The agent that made the change has the context;
  a future session will not.
- **Surgical edits, not rewrites.** Touch the specific section that changed.
  Do not rewrite a whole document to reflect a small delta.
- **Describe what the code does now, not what you hoped for.** Aspirational
  prose rots fastest.
- **Route through the owning skill.** When a user-doc rewrite is substantial,
  hand off to `doc-coauthoring`. When a spec changes shape, hand off to
  `spec-driven-dev`. The umbrella rule is to keep artifacts honest; the owning
  skill knows the specific protocol.

## Per-Artifact Update Rules

### Spec artifacts (spec-driven-dev)

- When a task is implemented: mark its checkbox `[x]` in `tasks.md`, append to
  the Log (fast-track) or note in Decisions (full ceremony), and verify that
  `design.md` still matches the shape of what shipped. Do not mark `[x]`
  without re-reading design.
- When the design actually changes: add a new Decision entry with Context,
  Options, Chosen, Rationale. Do not silently edit an earlier decision.
- When requirements shift: add or revise an EARS clause in `requirements.md`,
  then trace downward — does any existing property or task become obsolete?
- Never uncheck a completed task to "re-do" it. Add a new task with a
  reference back.
- **Freeze on ship.** Once a spec's status is `SHIPPED`, stop editing it except
  to add forward links to supersedes/superseded-by entries or correct factual
  errors. Retroactively rewriting shipped specs destroys the record of why
  decisions were made. New reality goes in the feature ledger and in new specs.

### Feature ledger (spec-driven-dev, typically .kiro/FEATURES.md)

- **Update on every state change.** When a task ships, deprecates, or removes
  a feature, update the feature's row in the ledger in the same session.
- **Append, don't rewrite.** Status transitions are edits in place; entries
  for obsolete or superseded features stay in the ledger so future readers see
  what existed and why it's gone.
- **Cross-link to specs.** Every feature entry points to the spec that owns it.
  Supersession and dependency edges point by stable feature id.
- **Drift sweep.** Periodically (release, milestone, or quarterly) audit the
  ledger against code: flag orphans (in code, not in ledger) and ghosts (in
  ledger, not in code). Produce a dated snapshot after each sweep.

### Snapshots (.kiro/snapshots/)

- **Write once, never edit.** A snapshot is a frozen copy of reality at a
  point in time. Edits defeat its purpose.
- Include: feature ledger state, shipped-spec index, architectural summary,
  date.
- Reference the snapshot from the next release's planning docs, not the
  other way around.

### Steering docs (.kiro/steering/)

- `structure.md`: update when repo layout changes (new top-level directory,
  moved package, renamed convention). Do not update for routine file moves.
- `tech.md`: update when a framework, language version, or tooling decision
  changes. Include the reason.
- `product.md`: update only when the product's mission or scope actually shifts,
  not for tactical changes. If you are editing it weekly, something is wrong.

### Steering file (CLAUDE.md / AGENTS.md)

- Merge, don't clobber. Preserve existing structure and only replace or add the
  section that needs changing.
- Update the session handoff after substantial work. Next session reads this
  first.
- Keep it short enough that future agents will actually read it. If it grows
  past the length a real human would read in two minutes, move detail into a
  reference file.

### Design records / ADRs

- Written once, not revised. If a decision is superseded, add a new record and
  mark the old one Superseded-by.
- Reference the code: file paths, function names, endpoint paths. A decision
  that cannot be traced to code is not actionable.

### User-facing docs

- Verify behavior before editing — run the code path, check the current output,
  read the tests. Do not trust an earlier draft of the doc as a source of truth
  for current behavior.
- For substantial work, hand off to `doc-coauthoring`: its Context Gathering →
  Refinement → Reader Testing flow catches more than a one-shot edit.
- Images without alt-text are invisible to the next agent that reads the doc
  through an LLM. Add alt-text or flag for the user.

### Analysis records (analytic-workbench)

- Keep each notebook tied to a question. An orphan notebook with no stated
  question is a liability.
- Promote reusable logic out of notebooks into modules before the notebook
  count gets unwieldy. Record the promotion in the analytic log.
- When a run produces a finding, record the finding alongside the run — not
  only in chat.

### Handoff

- Exact next action, not "continue from here". Name the file and the unit of
  work.
- Files changed recently + files to read first next time. These are the two
  lists that actually save the next session time.

## Common Failure Modes

- **Wholesale rewrite.** Agent rewrites the entire document to reflect a small
  change, destroying prior structure, voice, and cross-references.
- **Aspirational prose.** Doc describes what the agent intends to build rather
  than what exists. Gets worse every iteration.
- **Silent obsolescence.** Code removed, but the section of the doc that
  describes it is left behind. The next reader assumes it still works.
- **Ledger drift.** Feature ships but `.kiro/FEATURES.md` isn't updated, or
  a feature stays as ACTIVE in the ledger after its code was removed.
- **Spec zombie editing.** Agent edits a shipped spec to match new reality
  rather than creating a successor and marking the old one SUPERSEDED.
- **Taskfile drift.** Code lands but `tasks.md` never gets the checkbox, or
  checkboxes are flipped without the code actually landing.
- **Design-as-docs.** Agent edits `design.md` to match the code instead of
  adding a Decision, erasing the history of why the change happened.
- **Doc generated from stale summary.** Agent writes user-facing docs from a
  subagent summary rather than from reading the code. Summary was plausible;
  the code has moved.
- **Steering file bloat.** Every session adds a paragraph to `CLAUDE.md`. Six
  months later no one reads it.
- **Broken cross-links.** File renamed, references in other docs not updated.

## Cross-Skill Routing

When an artifact update is substantial, route to the skill that owns it:

- Spec wave work → `spec-driven-dev` (`/spec-plan refine`, `/spec-audit`)
- User-facing docs → `doc-coauthoring`
- Analysis artifacts → `analytic-workbench`
- Design handoff from a visual / mockup → `design2spec`

This reference covers the *cross-cutting* discipline: co-evolution, surgical
edits, honest descriptions. The per-skill protocols handle the specifics.
