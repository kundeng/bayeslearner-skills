---
name: analytic-workbench
description: Use this skill for analytics and data-science workflow setup, exploratory analysis, notebook-first EDA, repo normalization for analysis projects, experiment comparison, AutoML, causal analysis, and promotion from ad hoc exploration into reusable pipelines. Trigger when the user asks for analysis best practices, how to structure an analytics repo, how to organize notebooks and runs, whether to use marimo or Quarto/qmd, how to handle experiment sweeps, how to compare models, or how to make analysis reproducible. Also trigger on phrases such as analytic workbench, EDA, exploratory analysis, notebook workflow, analytics pipeline, reproducible analysis, experiment sweep, hyperparameter comparison, comparison table, marimo, Quarto, qmd, Hydra, DVC, Kedro, MLflow, AutoML, PyCaret, causal analysis, feature engineering, or model review.
metadata:
  author: kundeng
  version: "1.2.0"
---

# Analytic Workbench

Human-directed, AI-operated analysis. Use early when analysis may become a real
workflow.

## Start Here

1. Read `AGENTS.md` or `agents.md` if present
2. If neither exists, create `AGENTS.md` and update `CLAUDE.md` (see below)
3. Inspect the repo before changing structure
4. Separate repo facts from agent assumptions
5. Separate frozen inputs from live pulls

Then establish per area: current mode, likely next mode, review surface, first
boundary-sensitive change.

### Fresh Repo Bootstrap

When starting on a repo with no `AGENTS.md`, create one from the initial
prompt and project context. The file anchors all agents to the same workflow
contract.

`AGENTS.md` should contain:

- **Project purpose** — one-paragraph summary derived from the user's request
- **Workflow** — state that this project uses the analytic workbench skill
  with modes `probe → explore → experiment → operate`
- **Current mode** — the mode established in the first `plan` declaration
- **Conventions** — surface choices (marimo/qmd), module layout
  (`src/<project>/analysis/`), artifact layout (`runs/`, `rawdata/`)
- **Steering rules** — any project-specific constraints from the user's prompt
  (e.g., data sources, review expectations, domain context)

Then ensure `CLAUDE.md` exists and includes a pointer:

```text
See AGENTS.md for project workflow conventions and current mode.
```

If `CLAUDE.md` already exists, append the pointer rather than overwriting.
Update `AGENTS.md` at promote time when modes or conventions change.

## Modes

A mode is a workflow shape, not what you compute. Different areas of work can
be in different modes simultaneously.

| Mode | Use when | Read next | Common mistake |
|---|---|---|---|
| `probe` | first contact, uncertain framing | this file only | over-structuring early or treating probes as durable |
| `explore` | work worth keeping formally | `module-conventions.md`, `marimo-patterns.md` | logic in cells, hidden acquisition |
| `experiment` | reruns, comparisons, sweeps | `hydra-config.md` | adding Hydra before repeated runs exist |
| `operate` | scale, schedules, team work | `mlflow-guide.md` + orchestration docs | overbuilding early |

All references above are in `references/`.

## Operators

Five operators drive all work, firing from conversational intent. Default
rhythm: `plan -> run -> review -> summary`, with `promote` inserting when the
current mode's wiring is no longer sufficient.

Each operator must produce a visible declaration.

### plan

Set up or revise the workflow. Fires at start of substantive work or direction
change.

```text
Plan
- Area: ...          - Mode: ...
- Likely next mode: ...
- Primary surface: marimo | qmd | chat-only | other
- Review surface: ...
- First boundary-sensitive change: ...
- Steering docs read: ...
```

Add for ML/causal: `Sampling strategy: ...` and
`Target framing: binary | multiclass | regression | ranking | causal`.

For `probe`: `Area, Mode: probe, First probe, Review surface, Risk`.

### run

Execute the next planned step.

```text
Run                          Run outcome
- Area: ...                  - What ran: ...
- Step: ...                  - Output: ...
- Expected output: ...       - Anomaly or caveat: ...
```

### review

Sanity-check outputs before presenting — fires automatically, not on request.

```text
Review
- Area: ...
- Artifacts reviewed: ...
- Findings: ...
- Caveats: ...
- Verdict: proceed | revise | back up to [phase]
```

### summary

Report status at natural stopping points.

```text
EDA Update
- Area: ...       - What ran: ...
- Step: ...       - Outcome: ...
- Caveat: ...     - Next step: ...
```

### promote

Advance to a stronger mode. This is where mode transitions happen — probe to
explore when work is worth keeping, explore to experiment when reruns matter.
Transitions can also emerge from user intent (e.g., asking for comparisons).
Transitions are additive wiring, not rewrites.

```text
Promote
- Area: ...             - From mode: ...
- To mode: ...          - What survives: ...
- What changes: ...
```

## Core Workflow

The analytical spine, used within any mode:

```text
Frame -> Acquire -> Profile -> Hypothesize -> Model or Analyze -> Review -> Promote
```

- **Frame**: question, decision, constraints, review surface
- **Acquire**: data access as workflow shape, not hidden setup
- **Profile**: coverage, missingness, slices, label shape
- **Hypothesize**: likely drivers before over-engineering
- **Review**: findings early enough to redirect
- **Promote**: worth-keeping work into modules, config, runs, reports, and the runbook

Backtrack when stuck:
- Unusable data → Acquire or reframe
- All hypotheses fail → Profile with fresh slices
- Suspicious metrics → check leakage before celebrating
- Wrong assumption surfaced → Frame

## Guardrails

- Prefer what is on disk over generic assumptions
- Do not silently change folder layout, artifact semantics, or execution path — breaks resumption and review
- Once structure exists, stop using throwaway snippets — they diverge from the notebook contract
- First live extraction is usually a run artifact, not a frozen input
- Do not split a phase across half-wired surfaces — hides state, blocks promotion
- Do not let AutoML choose the framing — it optimizes whatever metric you hand it
- Match sampling/CV to temporal, grouped, spatial, or event structure — naive splits leak and inflate
- Keep project knowledge in repo docs, not agent memory

## Acquisition and DAG Shape

`explore`+ should follow `references/module-conventions.md`: pure functions in
`src/<project>/analysis/`, function name = output name, parameter name =
dependency name, manual driver fine. Hamilton-style naming encouraged; the
package is optional.

- `probe`: direct fetches acceptable
- `explore`+: reusable command/tool/pipeline if the pull will be rerun or handed off
- Notebooks read saved artifacts, not embed live fetch logic

## ML and Causal Rules

Read `references/modeling-guardrails.md` before modeling. Key rules:

- Frame target before any model runs — unexamined framing wastes downstream work
- Match sampling/CV to data structure
- AutoML as comparison accelerator after framing, not as problem framing
- Predictive importance is not causal effect — keep claims separate
- Interpretability artifacts for important outputs (`references/interpretability.md`)
- Causal design discipline: `references/causal-analysis.md`

## Reference Guide

Read only what the current mode or task needs.

| Reference | When to read | Key rules |
|---|---|---|
| `environment-setup.md` | packaging, imports, deps | Use real package setup; do not patch with editor settings |
| `module-conventions.md` | before `explore` code | Pure functions, output-oriented names, manual driver; no durable logic in cells |
| `marimo-patterns.md` | marimo surface | Verify in marimo itself; explicit paths; no hidden cross-cell state |
| `hydra-config.md` | entering `experiment` | Config separate from computation; no Hydra for one-off probes |
| `review-workflow.md` | presenting results | Review before presenting; marimo for interactive, qmd for narrative |
| `artifact-strategy.md` | repeated outputs, comparisons | Materialize clearly; do not mix frozen inputs with run outputs |
| `dvc-guide.md` / `kedro-guide.md` | reproducibility, lineage | Add only when beyond ordinary experiment needs |

All references above are in `references/`.

## Runbook

The runbook (`runbook.md` at the repo root) is the human-readable reproduction
guide. It is derived from project structure — configs, scripts, notebooks,
runs — not maintained as a separate log.

Generate or update at **promote time**: milestones, handoff requests, or mode
transitions. Rewrite stale sections rather than appending.

Contents:

1. **Prerequisites** — env setup, data acquisition, external tools
2. **Pipeline overview** — ASCII diagram of data flow
3. **Numbered steps** — one per major pipeline step, each with: the exact
   command, expected runtime, and what to inspect afterward (including expected
   results so the reader knows what "correct" looks like)
4. **Configuration reference** — table of config files and what they control
5. **Key directories** — paths, contents, git-tracked or not
6. **Troubleshooting** — known failure modes and fixes

The runbook ties per-run artifacts together: `config.yaml` says what params
were used, `metrics.json` says what happened, the runbook says which command
produced the run, what results to expect, and how to open the review surface.

If `.aw/` bookkeeping is active, note the runbook's last-updated timestamp in
`.aw/status.json`.

## Bookkeeping

Maintain `.aw/` when work continues across sessions:

```text
.aw/
  status.json          # current state across all areas
  stages/
    <area-name>/       # one folder per area of work
      plan.md          # framing and plan revisions
      status.json      # machine-readable state
      review.md        # review notes and approvals
```

Create or advance a stage folder only on mode changes or user-requested
checkpoints. Plan revisions, reruns, and parameter changes belong in the
existing folder, not a new one.

Joining mid-project:
- `.aw/status.json` exists → authoritative
- `stages/` but no root status → reconstruct from folders
- Hydra `conf/`/`multirun/` without `.aw/` → likely `experiment`, confirm
- Notebook + modules, no config management → likely `explore`
- Nothing structured → `probe`
