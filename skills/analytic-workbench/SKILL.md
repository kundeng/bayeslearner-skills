---
name: analytic-workbench
description: Use this skill for analytics and data-science workflow setup, exploratory analysis, notebook-first EDA, repo normalization for analysis projects, experiment comparison, AutoML, causal analysis, and promotion from ad hoc exploration into reusable pipelines. Trigger when the user asks for analysis best practices, how to structure an analytics repo, how to organize notebooks and runs, whether to use marimo or Quarto/qmd, how to handle experiment sweeps, how to compare models, or how to make analysis reproducible. Also trigger on phrases such as analytic workbench, EDA, exploratory analysis, notebook workflow, analytics pipeline, reproducible analysis, experiment sweep, hyperparameter comparison, comparison table, marimo, Quarto, qmd, Hydra, DVC, Kedro, MLflow, AutoML, PyCaret, causal analysis, feature engineering, or model review.
metadata:
  author: kundeng
  version: "1.0.0"
---

# Analytic Workbench

Human-directed, AI-operated analysis. Use early, before work drifts into ad hoc
scripts, mixed review surfaces, or weak run structure.

## Early Guardrails

Before deep exploration or code changes:

- read `AGENTS.md` or `agents.md` first when the repo has one
- pair with `workflow-guardrails` when the work may restructure the repo or set conventions
- do not stay silent at the start of the turn; make the operating plan visible
- do not use throwaway inline analysis code from Stage 1 onward — throwaway code silently diverges from the notebook contract and cannot be reviewed or rerun
- do not split one analysis phase across several half-wired surfaces — split surfaces hide state, break review flow, and make promotion impossible
- do not let AutoML choose the problem framing — AutoML optimizes whatever metric you hand it, so an unexamined framing produces a model that answers the wrong question
- do not use naive random row sampling for temporal, spatial, grouped, or event-style data unless justified — random rows break time ordering, leak future data, and produce misleadingly optimistic metrics

Use `spec-driven-dev` only when the work needs durable requirements, design,
tasks, or multi-session implementation tracking. Do not require it for ordinary
analytics execution.

## Lightweight Bookkeeping

When the work is likely to continue across sessions, create `.aw/stages/` and
keep stage-scoped artifacts there.

Preferred layout:

```text
.aw/
  status.json
  stages/
    stage-0-ad-hoc-eda/
    stage-1-notebook-eda/
    stage-2-workbench/
```

Use `.aw/status.json` as the current machine-readable state. For each active
stage folder, keep only the artifacts needed to resume cleanly, such as:

- `plan.md` for human-readable framing and plan revisions
- `status.json` for machine-readable state
- `review.md` for review notes and approval outcomes

Do not create a new folder for every small update. Create or advance a stage
folder when the stage changes or when the user wants a durable checkpoint.

## First-Turn Contract

At the start of substantive analytics work, report:

- stage
- primary surface
- fallback surface
- run manager
- sampling strategy
- target framing if ML or causal work is in scope
- first reusable artifacts
- steering docs read

Use this format:

```text
Plan
- Stage: ...
- Primary surface: marimo | qmd | chat-only | other
- Fallback surface: ...
- Run manager: plain config | Hydra | DVC | Kedro | other
- Sampling strategy: ...
- Target framing: binary | multiclass | regression | ranking | causal | n/a
- First reusable artifacts:
  - ...
  - ...
- Steering docs read:
  - ...
```

For ongoing work, use compact progress updates:

```text
EDA Update
- Step: ...
- What ran: ...
- Outcome: ...
- Risk or caveat: ...
- Next step: ...
```

If bookkeeping is active, treat the first-turn contract as the seed for
`.aw/status.json` and the current stage's `plan.md`.

## Default Loop

Use this unless the user explicitly wants another process:

```text
Frame -> Acquire -> Profile -> Hypothesize -> Model or Analyze -> Review -> Promote
```

Meaning:

- **Frame**: define the question, decision, constraints, and review surface
- **Acquire**: get data through reusable steps, not throwaway shell snippets
- **Profile**: inspect coverage, missingness, slices, and label shape
- **Hypothesize**: state likely drivers before over-engineering
- **Model or Analyze**: run the next sensible baseline, test, or comparison
- **Review**: present findings early for correction
- **Promote**: move worth-keeping work into reusable modules, config, runs, and review surfaces

If a phase stalls, back up rather than push through:

- Profile reveals unusable data -> return to Acquire or reframe
- Hypotheses all fail -> return to Profile with fresh slices
- Model produces suspicious metrics -> check for leakage before celebrating
- Review surfaces a wrong assumption -> return to Frame

## Operator Vocabulary

Four operators keep planning, execution, and review aligned:

- `aw-plan create|update|advance` — create, revise, or advance the stage plan
- `aw-run` — execute the next planned step and produce artifacts
- `aw-review` — self-review artifacts, summarize outcomes, decide whether to revise or promote
- `aw-status` — report current stage, latest artifacts, open risks, next step

When `.aw/stages/` exists, operators update the stage folder and
`.aw/status.json` rather than inventing separate bookkeeping.

## Detecting the Current Stage

When joining mid-project:

- `.aw/status.json` exists -> read it; the `stage` field is authoritative
- `.aw/stages/` exists but no `status.json` -> use the highest stage folder name
- Hydra `conf/` or `multirun/` present but no `.aw/` -> likely Stage 2, confirm with user
- Notebook and modules present but no config management -> likely Stage 1
- Nothing structured -> Stage 0

## What a Stage Means

A stage is both:

- a **temporal checkpoint** in the life of the analysis
- a **workflow wiring level** describing how the work is structured and managed

It is not a new computation stack. Moving to a later stage preserves
earlier-stage modules and notebook surfaces; what changes is config injection,
run management, caching, orchestration, and review rigor. Promote when the need
for repeatability, comparison, or reproducibility increases.

Stage model:

- **Stage 0 — Ad Hoc EDA**: first contact with unfamiliar data. Minimal wiring, quick probes. Do not load any references yet.
- **Stage 1 — Notebook EDA**: disciplined exploration with reusable modules and a simple run path. Read `references/module-conventions.md` and `references/marimo-patterns.md`. Do not load `hydra-config.md`, `dvc-guide.md`, `kedro-guide.md`, or `mlflow-guide.md`.
- **Stage 2 — Workbench**: add Hydra-managed repeatable runs, comparisons, and experiment discipline on top of Stage 1. Read `references/hydra-config.md`. Do not load `dvc-guide.md`, `kedro-guide.md`, or `mlflow-guide.md`.
- **Stage 3 — Reproducible**: add DVC and/or Kedro for expensive data, pipeline structure, and lineage. Read `references/dvc-guide.md` or `references/kedro-guide.md`. Do not load `mlflow-guide.md`.
- **Stage 4 — Orchestrated**: add MLflow plus orchestration for team or production use. Read `references/mlflow-guide.md`.

Promotion bias:

- move `0 -> 1` when the work is worth keeping
- move `1 -> 2` after initial findings if the user wants to continue, compare, rerun, tune, or keep the work
- treat `1 -> 2` as an additive wiring upgrade, not a rewrite; preserve Stage 1 computation and notebook contracts

## Surface Rules

- Stage 1 should already use a notebook surface for EDA
- prefer `marimo` for interactive review and iterative analysis
- prefer `qmd` for staged narrative delivery or final presentation artifacts
- if the user cannot reliably run `qmd`, do not force it as the main exploration surface
- keep computation in reusable modules and use the surface for review, controls, and presentation

## ML and Causal Rules

If the work includes prediction, classification, AutoML, or causal analysis,
read `references/modeling-guardrails.md` before modeling. Key expert-level rules:

- frame the target and choose binary vs multiclass vs regression vs causal *before* any model runs — an unexamined framing wastes every downstream step
- use sampling and CV that match the data structure — naive splits on temporal or grouped data leak information and inflate metrics
- use AutoML as a comparison accelerator after framing and baselines are set, not as problem framing
- keep predictive and causal claims separate — predictive feature importance is not causal effect
- provide interpretability artifacts for important outputs; read `references/interpretability.md` when explanations matter

For causal design and claim discipline, read `references/causal-analysis.md`.

## References

Stage-specific and modeling references are linked at their decision points
above. Read these as needed regardless of stage:

- `references/artifact-strategy.md` for runs and comparison outputs
- `references/review-workflow.md` for review and approval flow
- `references/environment-setup.md` for environment and dependency setup
- `references/code-templates.md` for reusable code patterns
