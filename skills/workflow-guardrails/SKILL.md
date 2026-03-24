---
name: workflow-guardrails
description: "Use this skill for cross-cutting execution discipline that applies regardless of domain: inspect the repo before restructuring, distinguish repo knowledge from agent memory, avoid changing editor or IDE config without permission, avoid throwaway scripts once a structured workflow is underway, and stop to re-anchor before changing project conventions, persistence layout, or artifact semantics. Trigger when the user asks for best practices, workflow discipline, project hygiene, execution guardrails, repo normalization, or when a task risks drifting across architecture, storage, spec, or tooling boundaries."
---

# Workflow Guardrails

Use this skill for agent operating discipline that is independent of the task domain.

This skill is not about what to build. It is about how to avoid predictable
execution mistakes while building it.

## First Actions

Before making substantive changes:

1. Inspect the existing repo structure, key docs, and current conventions.
2. Identify whether the project already has a workflow in progress: specs,
   artifact layout, notebooks, pipeline runners, or established docs.
3. Classify what is stable versus what is live:
   - repo knowledge vs agent memory
   - given inputs vs live pulls
   - durable workflow code vs one-off exploration
4. State the first boundary-sensitive change before making it.

Do not start by rewriting structure from memory or habit.

## Guardrails

### 1. Repo First

- Prefer what is already on disk over generic assumptions.
- Check whether the project already has specs, knowledge docs, runners,
  notebooks, or artifact conventions before inventing new ones.
- If an existing convention is weak, describe the delta before changing it.

### 2. Do Not Edit Local Tooling Without Permission

- Do not edit `.vscode/`, IDE settings, local editor config, or personal shell
  config unless the user asked for that explicitly.
- If a local tooling change seems necessary, propose it first and explain why it
  is not purely project code.

### 3. Separate Repo Knowledge From Agent Memory

- Project knowledge that should survive across agents belongs in repo docs.
- Agent memory is for agent-specific preferences, feedback, or user working style.
- Do not move project facts into agent memory just because they are evolving.

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

### 6. Stop and Re-Anchor Before Convention Changes

Pause and re-anchor before changing:

- folder layout
- artifact semantics
- spec location
- persistence strategy
- where knowledge lives
- the main execution entry point

When one of these changes is on the table, re-check the repo and explain the
reason for the new convention before editing files.

## Anti-Patterns

- Editing IDE config to make imports work before fixing the project packaging.
- Treating live query results as immutable source inputs by default.
- Building the real workflow with one-off inline scripts, then backfilling a runner later.
- Moving specs or docs only after the user points out the mismatch.
- Splitting project knowledge between repo docs and agent memory without a clear rule.
- Renaming directories to match a preferred framework without first checking what already exists.

## Correction Pattern

When you notice you crossed a boundary incorrectly:

1. Say exactly what boundary was crossed.
2. Revert or contain the mistake if practical.
3. Restate the correct model.
4. Continue from the corrected workflow, not from the shortcut.

Short example:

- Wrong: save live extracts into a folder meant for frozen inputs.
- Correct: save them under a run-specific artifact path, then promote only if
  the snapshot is meant to become a stable reusable input.

## Use With Other Skills

This skill should remain general. It does not replace domain or workflow
skills. It keeps execution disciplined while those skills provide the actual
task-specific workflow.
