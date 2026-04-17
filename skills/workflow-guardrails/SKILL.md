---
name: workflow-guardrails
description: "Use this skill for cross-cutting execution discipline that applies regardless of domain: inspect the repo before restructuring, distinguish repo knowledge from agent memory, keep durable truth in repo artifacts instead of chat memory, maintain explicit handoffs for long-running work, avoid changing editor or IDE config without permission, avoid throwaway scripts once a structured workflow is underway, and stop to re-anchor before changing project conventions, persistence layout, or artifact semantics. Trigger when the user asks for best practices, workflow discipline, project hygiene, execution guardrails, repo normalization, or when a task risks drifting across architecture, storage, specs, continuity, or tooling boundaries."
metadata:
  author: kundeng
  version: "1.2.0"
---

# Workflow Guardrails

Use this skill for agent operating discipline on real development and analysis
projects.

This skill is not about choosing the product direction. It is about how to work
correctly once a project exists: maintain the right durable artifacts, preserve
continuity across sessions, use sound engineering practice, and keep making
progress when the human is away.

## First Actions

Before making substantive changes:

1. Inspect the existing repo structure, key docs, and current conventions.
2. Identify whether the project already has a workflow in progress: specs,
   artifact layout, notebooks, pipeline runners, steering docs, or established
   docs.
3. Determine the project mode:
   - development project: code, app, package, automation, service, or system
   - analysis project: notebooks, reports, experiments, pipelines, evaluation,
     or model comparison
4. Identify what the project expects to be maintained. This usually includes
   some subset of:
   - requirements, designs, specs
   - tasks, milestones, workstreams
   - feature status or verification status
   - documentation or project knowledge
   - analysis outputs, experiment records, or run artifacts
5. Classify what is stable versus what is live:
   - repo knowledge vs agent memory
   - given inputs vs live pulls
   - durable workflow code vs one-off exploration
   - current repo state vs stale notes or stale runtime state
6. Identify the canonical steering file. If the project uses `CLAUDE.md`, read
   it first. If it does not exist, inspect the repo before creating one.
7. State the first boundary-sensitive change before making it.

Do not start by rewriting structure from memory or habit.

## Core Stance

- Prefer repo truth over chat memory.
- Keep durable project state in repo artifacts, not only in the conversation.
- Treat resume as retrieval plus re-anchoring, not magic continuity.
- Prefer one canonical steering document over scattered duplicate guidance.
- Keep durable notes short enough that future agents will actually read them.
- Maintain the project's planning and status artifacts as part of the work, not
  as optional cleanup.
- Use good coding, design, and testing practice appropriate to the project
  mode.

## Guardrails

### 1. Repo First

- Prefer what is already on disk over generic assumptions.
- Check whether the project already has specs, knowledge docs, runners,
  notebooks, artifact conventions, or a steering file before inventing new
  ones.
- If an existing convention is weak, describe the delta before changing it.

### 2. Do Not Edit Local Tooling Without Permission

- Do not edit `.vscode/`, IDE settings, local editor config, or personal shell
  config unless the user asked for that explicitly.
- If a local tooling change seems necessary, propose it first and explain why it
  is not purely project code.

### 3. Separate Repo Knowledge From Agent Memory

- Project knowledge that should survive across agents belongs in repo docs.
- Agent memory is for agent-specific preferences, feedback, or user working
  style.
- Do not move project facts into agent memory just because they are evolving.
- If another session or machine will need the information, move it into repo
  artifacts.

### 4. Distinguish Input Classes

- User-provided or deliberately frozen snapshots are not the same as live pulls.
- The first extraction from a live system is a run artifact unless the project
  explicitly promotes it to a stable input.
- Do not silently relabel artifact classes midstream.

### 5. No Throwaway Path After Structure Exists

- Early exploration can be ad hoc.
- Once the task has crossed into a structured workflow, stop using inline
  throwaway scripts as the main execution path.
- Put computation in the project's real execution surface: modules, runners,
  notebooks, scripts, or pipelines already implied by the workflow.

### 6. Maintain the Project's Durable Artifacts

- Development projects usually require maintenance of specs, requirements,
  designs, tasks, milestones, feature status, and project knowledge docs.
- Analysis projects usually require maintenance of research questions, data
  assumptions, experiment or run records, result summaries, and decision notes.
- If the repo already has a canonical maintenance set, use it.
- If the user names required categories, treat them as mandatory structure.
- Do not treat updating these artifacts as optional polish after coding.
- Keep status honest. Do not mark work complete unless the repo state and
  verification support that claim.

### 7. Code and Design Quality Still Matter

- Follow the repo's existing architecture and style before inventing a new one.
- Prefer modular, dry changes when refactoring is justified by repeated logic,
  unclear boundaries, or high-friction maintenance.
- Keep refactors coupled to a real project need: remove duplication, clarify
  ownership, simplify testing, or support the next milestone.
- Do not perform "cleanup" refactors that drift away from the active workstream.
- For application or product work, apply sound design judgment to user-facing
  flows, structure, naming, and interaction quality.

### 8. Verification Must Be Real

- Do not write empty tests or placeholder assertions just to satisfy a testing
  checkbox.
- Match the test surface to the risk: unit tests for local logic, integration
  tests for module boundaries, and end-to-end tests for user workflows and app
  behavior.
- When the project has a UI, browser workflow, or integrated system behavior,
  prefer meaningful end-to-end or integration coverage using the tools already
  available in the environment, such as Agent Browser or Playwright.
- Verify that tests exercise real behavior and would fail if the feature were
  broken.
- Record honest verification status in the project's durable status artifacts.

### 9. Keep Handoffs Durable and Mechanical

- For substantial work, update a durable handoff before ending the session.
- Record what changed, what remains, and the exact next action in one place.
- Keep open tasks, milestones, blockers, and current status distinct.
- Prefer concrete file paths and still-valid commands over vague narrative.
- Do not end with "continue from here" when you can name the next work unit.

Minimal handoff checklist:

- objective
- current status
- open tasks
- active milestone or workstream
- known blockers or decisions
- exact next action
- files changed
- files to read first next time

### 10. Resume Deliberately

- When resuming prior work, search using the user's wording and current repo
  context.
- If multiple candidate sessions or notes compete, compare cwd, topic, recency,
  and last unfinished action before choosing.
- Summarize imported context instead of dumping raw transcripts by default.
- Preserve accepted decisions, unresolved issues, and the stopping point when
  transferring context.
- Re-anchor on current repo state before making new changes.

### 11. Loop Forward When the Human Is Away

- If the project has a spec, milestone list, task queue, or handoff backlog,
  the agent should keep moving through the next concrete work unit when the
  human is away.
- Drive from the canonical queue: incomplete milestone, next task, known bug,
  failing test, or explicitly named follow-up item.
- The loop should produce real progress: implementation, verification, refactor
  for maintainability, bug fixing, or artifact maintenance.
- Stop only when blocked by a real human decision, missing external input, or
  an exhausted queue.
- Document loop stop conditions when automation or scheduled prompting is used.

### 12. Watch for Stale State and Stale Automation

- Distinguish stale runtime state from current repo state before acting.
- Do not trust stale task headers, dashboards, or old summaries without
  verification.
- When loops, scheduled prompts, or automation are involved, document their stop
  conditions explicitly.
- Disable or redirect recurring automation when the objective or target has gone
  stale.

### 13. Stop and Re-Anchor Before Convention Changes

Pause and re-anchor before changing:

- folder layout
- artifact semantics
- spec location
- persistence strategy
- where knowledge lives
- the main execution entry point
- the canonical steering file structure

When one of these changes is on the table, re-check the repo and explain the
reason for the new convention before editing files.

### 14. Keep Naming Honest

- Keep naming precise; do not reuse labels for different concepts.
- Fix misleading labels or mental models before layering more workflow on top.
- If the user corrects a recurring omission or naming problem, encode that into
  the durable workflow rather than treating it as a one-off reminder.

## CLAUDE.md Reference Implementation

This skill includes `claude.template` as a reference implementation for a
project-specific `CLAUDE.md`.

Use it to infer:

- which sections belong in a steering file
- how specific the file should be
- what should live in `CLAUDE.md` versus deeper docs

Do not copy it blindly. Inspect the current repo first, then synthesize a
`CLAUDE.md` that fits the project's actual commands, docs, architecture, and
workflow.

A good `CLAUDE.md` should:

- be the first file the agent reads at session start
- point to canonical docs instead of duplicating them
- define startup order, work discipline, and update rules
- make clear whether the project is primarily development, analysis, or hybrid
- state what artifacts must be maintained during the work
- require real verification, not symbolic testing
- carry a compact handoff section for long-running work
- support self-directed looping on the next concrete task when appropriate
- stay concise enough that future sessions will read it

## Anti-Patterns

- Editing IDE config to make imports work before fixing the project packaging.
- Treating live query results as immutable source inputs by default.
- Building the real workflow with one-off inline scripts, then backfilling a
  runner later.
- Moving specs or docs only after the user points out the mismatch.
- Splitting project knowledge between repo docs and agent memory without a clear
  rule.
- Renaming directories to match a preferred framework without first checking
  what already exists.
- Assuming the next session will remember important state without durable notes.
- Resuming from an ambiguous "continue" request without identifying the target
  context.
- Letting stale automation continue on an outdated objective.
- Marking milestones or feature status complete without real verification.
- Writing tests that do not exercise meaningful behavior.
- Waiting idly for the human when the next work item is already defined.

## Correction Pattern

When you notice you crossed a boundary incorrectly:

1. Say exactly what boundary was crossed.
2. Revert or contain the mistake if practical.
3. Restate the correct model.
4. Update the durable workflow artifact if future sessions would repeat the
   mistake.
5. Continue from the corrected workflow, not from the shortcut.

Short example:

- Wrong: save live extracts into a folder meant for frozen inputs.
- Correct: save them under a run-specific artifact path, then promote only if
  the snapshot is meant to become a stable reusable input.

## Use With Other Skills

This skill should remain general. It does not replace domain or workflow
skills. It keeps execution disciplined while those skills provide the actual
task-specific workflow.
