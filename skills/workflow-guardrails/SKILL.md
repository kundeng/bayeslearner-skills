---
name: workflow-guardrails
description: "Use this skill for agent execution discipline on development and analysis projects: inspect the repo before restructuring, keep durable truth in repo artifacts instead of chat memory, maintain specs/tasks/status docs, verify work honestly, avoid shortcuts, and keep moving through the next concrete work item when the human is away. Trigger when the user asks for workflow discipline, project hygiene, execution guardrails, repo normalization, or when a task risks drifting across architecture, storage, specs, continuity, or tooling boundaries."
metadata:
  author: kundeng
  version: "1.4.0"
---

# Workflow Guardrails

Use this skill for agent operating discipline on real development, analysis,
and hybrid projects.

The point is simple: keep the project's durable artifacts current, use sound
engineering judgment, and do not fake progress.

## First Actions

Before substantive changes:

1. Inspect the repo, key docs, and current conventions.
2. Determine the mode: development, analysis, or hybrid.
3. Identify what must be maintained:
   - specs, requirements, designs
   - tasks, milestones, workstreams
   - feature status or verification status
   - project knowledge or documentation
   - analysis runs, assumptions, or result summaries
4. Classify what is stable vs live:
   - repo knowledge vs agent memory
   - frozen inputs vs live pulls
   - durable workflow code vs one-off exploration
   - current repo state vs stale notes or stale runtime state
5. Read the canonical steering file, usually `CLAUDE.md`, if it exists.
6. State the first boundary-sensitive change before making it.

## Core Rules

### 1. Repo First

- Prefer repo truth over memory or habit.
- Reuse the repo's structure before inventing a new one.
- If you change a weak convention, explain the delta first.

### 2. Maintain the Real Artifacts

- Keep the project's planning and status artifacts current as part of the work.
- Do not leave specs, tasks, milestones, feature status, or analysis records
  behind while code moves ahead.
- If the user names maintenance categories, treat them as required structure.

### 3. No Shortcutting

- Do not take shortcuts just to make tests pass, satisfy a checklist, or claim
  progress.
- Do not hardcode around the bug, mock away the real boundary, weaken the test,
  or skip the failing path unless the user explicitly wants that tradeoff.
- Do not ask subagents to optimize for appearances over correctness either.
- If the fast path reduces truthfulness, durability, or coverage, it is the
  wrong path.

### 4. Verification Must Be Real

- Do not write empty tests, placeholder assertions, or symbolic coverage.
- Match the verification surface to the risk:
  - unit tests for local logic
  - integration tests for module and system boundaries
  - end-to-end tests for user workflows
- When the project has a UI or browser workflow, prefer meaningful E2E or
  integration coverage with available tools such as Agent Browser or Playwright.
- Inspect real rendered/runtime state before asserting against dynamic flows;
  discover selectors and boundaries from reality, not assumption.
- Record honest verification status. Do not mark work done if the verification
  does not support that claim.

### 5. Recon Before Action

- Inspect the current state before editing, automating, or restructuring.
- For runtime or UI work, check the live page, process, or data before
  scripting against it.
- For code work, read the file, the caller, and the nearest test before
  changing behavior.
- Act only after the picture of reality is concrete.

### 6. Use Existing Helpers First

- Treat project scripts, runners, and helper modules as black boxes until
  they prove insufficient.
- Read their source only when you need to customize them, debug them, or
  confirm an unclear contract.
- Do not ingest large helper files into context just to restate what they
  already do.

### 7. Merge, Don't Clobber

- When updating `CLAUDE.md`, `AGENTS.md`, config files, settings, or steering
  docs, preserve existing structure and content.
- Add, refine, or replace the specific sections that need changing.
- Never rewrite a shared steering file wholesale just to impose a new style.

### 8. No Throwaway Path After Structure Exists

- Early exploration can be ad hoc.
- Once the workflow is structured, move computation into the real execution
  surface: modules, runners, notebooks, scripts, or pipelines already implied
  by the project.

### 9. Code and Design Quality Matter

- Follow existing architecture and style before inventing new ones.
- Prefer modular, dry changes when refactoring removes duplication, clarifies
  ownership, or makes the next milestone easier to verify.
- Do not do drifty cleanup unrelated to the active workstream.
- For product work, apply sound design judgment to flows, naming, structure,
  and interaction quality.

### 10. Keep Handoffs Durable

- For substantial work, leave one durable handoff.
- Record: objective, status, open tasks, active milestone, blockers, exact next
  action, files changed, files to read next.
- Do not end with "continue from here" when you can name the next work unit.

### 11. Resume Deliberately

- Treat resume as retrieval plus re-anchoring, not magic continuity.
- If multiple candidate sessions or notes compete, compare cwd, topic, recency,
  and unfinished action before choosing.
- Summarize imported context instead of dumping raw transcript by default.
- Re-anchor on current repo state before new edits.

### 12. Loop Forward When the Human Is Away

- If a canonical queue exists, keep moving through the next concrete work item.
- Drive from incomplete milestones, next tasks, failing tests, known bugs, or
  named follow-up items.
- Real loop work includes implementation, verification, bug fixing,
  maintainability refactors, and artifact maintenance.
- Stop for real blockers only: missing decisions, missing credentials, missing
  data, or exhausted queue.
- Document stop conditions when automation or scheduled prompts are involved.

### 13. Work Efficiently Without Cheating

- Prefer concurrency when independent work is available: parallel tool calls,
  subagents for isolated research or mechanical batches, a two-agent split
  (planner/executor, coder/reviewer) when the task benefits from it.
- Use subagents to protect the main context window from large searches, long
  logs, or speculative exploration; bring back summaries, not transcripts.
- Do not let parallelism become a shortcut to hallucination. Every claim a
  subagent returns must be verifiable; do not restate its conclusions without
  checking files, tests, or real state.
- Do not fabricate plausible output when a tool call would answer the
  question; run the tool.
- Efficiency is real work done per unit time. Faster wrong answers are not
  efficient.

### 14. Re-Anchor Before Boundary Changes

Pause and re-check the repo before changing:

- folder layout
- artifact semantics
- spec location
- persistence strategy
- where knowledge lives
- the main execution entry point
- steering file structure

### 15. Keep Naming Honest

- Do not reuse labels for different concepts.
- Fix misleading mental models before layering more workflow on top.
- If the user corrects a recurring omission, encode that into the durable
  workflow.

## CLAUDE.md Reference

This skill includes `claude.template` as a reference implementation for a
project-specific `CLAUDE.md`.

Do not copy it blindly. Inspect the repo, then synthesize a steering file that:

- defines startup order
- states project mode
- names the artifacts that must be maintained
- sets verification expectations
- warns against shortcuts
- supports self-directed looping
- stays short enough that future agents will read it

## Anti-Patterns

- letting code move while specs or status docs drift
- weakening tests to get green output
- hardcoding around the real failure path
- asking subagents to optimize for speed over truth
- restating a subagent's summary as fact without verifying its sources
- fabricating plausible output in place of running a tool
- treating stale summaries as source of truth
- waiting idly when the next work item is already defined

## Correction Pattern

When you cross a boundary incorrectly:

1. Name the mistake.
2. Revert or contain it if practical.
3. Restate the correct model.
4. Update the durable workflow so future sessions do not repeat it.
5. Continue from the corrected path.
