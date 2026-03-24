---
name: analytic-workbench
description: "ALWAYS use this skill for human-in-the-loop analytic workflows: exploratory notebook runs, Tier 0 data exploration, Tier 1 structured analysis, folder normalization for analytics projects, Hydra-managed experiment sweeps, review/approval loops, and reproducibility layers such as DVC, Kedro, or MLflow. Use it when the user wants to set up or run an analysis pipeline, asks whether an analytic workflow maps to best practices, wants to normalize repo structure for analytics, wants to choose a tier, compare hyperparameters, build a comparison table, review outputs before approval, run the next stage, or decide how marimo, Hydra, DVC, Kedro, MLflow, Dagster, or Prefect fit together. Trigger on phrases like analysis pipeline, reproducible analysis, best practices, tier 0, tier 1, normalize folder structure, exploratory analysis, notebook workflow, human-in-the-loop, next stage, experiment sweep, hyperparameter comparison, comparison table, marimo, Hydra, DVC, Kedro, MLflow, Dagster, Prefect, analytic workbench, AutoML, PyCaret."
---

# Analytic Workbench

Human-directed, AI-operated analysis. The AI drives execution, self-reviews
outputs, and presents artifacts for human approval. The human guides direction,
edits interpretations, and decides what to try next.

## Invoke Immediately When

Use this skill at the start of the turn, not later, when the user asks for any
combination of:

- analytic workflow best practices
- repo or folder normalization for analysis work
- "Tier 0" exploration before formal code structure
- "Tier 1" structuring after exploration
- notebooks plus reproducible promotion later
- MCP-backed or API-backed data exploration that feeds a notebook/report workflow

Do not wait for the user to explicitly say "use analytic-workbench" when the
workflow shape already matches this pattern.

---

## Architecture: Config -> Computation -> Display

Three layers, each with a single job.

```
Config layer   ->  Computation layer  ->  Display layer
  what to run       how to run it        what the human sees
```

- **Config**: Plain YAML/dict at Tier 1. Hydra (composition, CLI overrides,
  sweeps) at Tier 2+. Alternatives: any system that produces a dict.
- **Computation**: Pure Python modules following DAG-friendly naming conventions
  (function name = output name, typed I/O, small functions). Handwired driver
  at Tier 1-2, optionally Kedro pipelines at Tier 3.
- **Display**: marimo (reactive notebooks, app mode). Alternatives: Jupyter,
  Streamlit, or any surface that separates display from logic.

Config never touches DataFrames, computation never renders UI, display never
contains business logic. At Tier 1, the config layer may just be widget values.

---

## References

**ALWAYS read the relevant reference before acting.** SKILL.md is the routing
layer; references contain the how-to details.

| Reference | Scope | When to read |
|-----------|-------|--------------|
| `references/environment-setup.md` | Dependencies, packages, pyproject.toml, env management | Project scaffold, adding libraries |
| `references/module-conventions.md` | DAG-friendly module discipline, handwired driver, pure function patterns | All tiers: writing computation code |
| `references/marimo-patterns.md` | Frontend patterns, app mode, UI-only philosophy | All tiers: building notebooks |
| `references/hydra-config.md` | Config composition, sweeps, experiment configs | Tier 2+: config management |
| `references/artifact-strategy.md` | Per-run folders, comparison tables, freshness rules | Tier 2+: organizing outputs |
| `references/review-workflow.md` | Human review loop, notebook as review surface | All tiers: presenting results |
| `references/core-contracts.md` | manifest.json, review.json, approval.json schemas | Tier 3+: formal audit trails |
| `references/dvc-guide.md` | `dvc.yaml`, `dvc repro`, `dvc exp`, remotes, caching | Tier 3 option: stage caching |
| `references/kedro-guide.md` | Kedro pipelines, data catalog, `kedro viz` | Tier 3 option: pipeline framework |
| `references/mlflow-guide.md` | Experiment tracking, model registry, comparison UI | Tier 4: team-scale tracking |
| `references/code-templates.md` | Complete working examples for every component | All tiers: bootstrapping code |

---

## Pick Your Tier

| Tier | When | Config | Computation | Display |
|------|------|--------|-------------|---------|
| **1: Notebook** | Small, exploratory | Plain YAML/dict or widget values | Pure modules + handwired driver | Reactive notebook (marimo preferred) |
| **2: Workbench** | Repeatable experiments, comparison | Hydra (composition, sweeps, auto output dirs) | Pure modules + handwired driver | marimo app + comparison tables |
| **3: Reproducible** | Expensive data, many runs, pipeline structure | Hydra (composition, sweeps) + DVC params tracking | DVC cached stages and/or Kedro pipelines | Notebook/app for review |
| **4: Orchestrated** | Production, team, CI/CD | Hydra/orchestrator config | Dagster/Prefect + MLflow | Orchestrator UI + notebook |

**Start at Tier 1 only for truly lightweight work. Most comparison-driven
analyses should begin at Tier 2.** Signs you need the next tier:

- **1->2**: You want config composition, parameter sweeps, or structured output dirs.
- **2->3**: Re-fetching source data wastes time, or the pipeline needs a DAG
  runner / data catalog. Choose DVC (additive caching), Kedro (pipeline
  restructure), or both.
- **3->4**: Multiple people need scheduling, retries, experiment tracking, or CI/CD.

---

## Project Structure

Enforce from Tier 1. No migration needed when moving up tiers.

```
project/
  src/
    <project_name>/            # Importable Python package
      __init__.py
      analysis/                # Pure function modules with explicit dependency naming
        __init__.py
        baseline.py
        features.py
        ...
      scripts/                 # Entry points (Hydra runners, comparison builders)
        run.py
        build_comparison.py
      tools/                   # Data access CLI tools
        fetch_data.py
  notebooks/                   # marimo notebooks (outside src/)
    explore.py
    report.py
  conf/                        # Tier 2+: Hydra config files
    config.yaml
    source/
    experiment/
  rawdata/                     # Frozen file inputs for analysis (gitignored)
  runs/                        # Per-run artifacts (gitignored)
    <run-id>/
      config.yaml
      metrics.json
      figures/
      data/
  review/                      # Tier 3+: manifest, review, approval files
  tests/                       # pytest tests for src/ modules
  pyproject.toml               # Package definition + dependencies
  .gitignore
```

Key rules:

- `src/<project_name>/` is an installable package (`pip install -e .`).
- `notebooks/` is outside `src/` — not importable, not part of the package.
- `rawdata/` is immutable and gitignored. It is for frozen file inputs that the
  analysis treats as given: user-provided files, manually staged extracts, or
  explicitly promoted snapshots.
- The first pull from a live external system is not automatically `rawdata/`.
  Treat that as a run artifact or acquisition output first. Promote it into
  `rawdata/` only when you intend to reuse it as a stable input snapshot.
- `runs/` is gitignored.
- No `data/processed/` or `outputs/figures/` — artifacts live inside `runs/<run-id>/`.
- Even at Tier 1, analysis code belongs in `src/<project_name>/analysis/`, not
  in notebook cells. Move exploratory code to modules within the same session.

---

## The Core Loop

Every analysis cycle, regardless of tier:

```
Execute -> Self-Review -> Present -> Human Decision -> Record & Advance
```

**Execute** — Run the analysis (handwired driver, Hydra sweep, Kedro pipeline,
DVC repro). Produce outputs inside `runs/<run-id>/`.

**Self-Review** — Before showing the human anything, check your own work:
outputs exist and are non-empty, figures are non-trivial, metrics are plausible,
no NaN/Inf in key columns, values match figures. At Tier 3+, write `review.json`.

**Present** — The marimo notebook is the primary review surface. The human reads
it, interacts with it, drills into comparison tables and figures. At Tier 1 this
can be a chat message with inline figures. At Tier 2+, the notebook *is* the
presentation. See `references/review-workflow.md`.

**Human Decision** — Approve, approve with edits, or reject with feedback.

**Record & Advance** — At Tier 1-2, note approval conversationally. At Tier 3+,
write `approval.json`. Never update a report with unapproved results.

---

## Language & Environment

The skill is **Python-first** (marimo, Hydra, Kedro are Python). The
methodology — layered architecture, tiered maturity, the core loop — is
language-agnostic.

- Use `uv`, `conda`, `poetry`, or `venv` to manage environments. The skill does
  not prescribe a specific tool.
- Define dependencies in `pyproject.toml`, not bare `requirements.txt`.
- See `references/environment-setup.md` for details and library recommendations.

---

## Git Practices

- Commit analysis code, configs, `pyproject.toml`, and lockfiles.
- Gitignore `rawdata/`, `runs/`, `__pycache__/`, `.env`.
- At Tier 3+, commit `dvc.lock` (tracks data lineage without storing data).
- Tag or branch for significant experiment milestones.
- Use descriptive commit messages: `experiment: sweep window_size 24-168h`.
- marimo's pure-Python format avoids stale-output problems common with `.ipynb`.

---

## Testing

Analysis modules are pure functions — test them with pytest. No special
framework needed. See `references/module-conventions.md` for testing patterns.

```
tests/
  test_baseline.py      # Unit tests for src/<project>/analysis/baseline.py
  test_features.py      # Unit tests for src/<project>/analysis/features.py
```

---

## Maturity Path

Each phase builds on the previous without rewrites.

**Phase 1** — marimo + pure modules + handwired driver + `runs/` folder.
**Phase 2** — Hydra configs + sweeps + comparison tables.
**Phase 3** — DVC caching and/or Kedro pipelines + formal review contracts.
**Phase 4** — MLflow tracking + Dagster/Prefect orchestration + CI/CD.

Move up when the pain of not having the next tool exceeds the cost of adding it.
