# Analytic Workbench Skill

Reusable skill for human-in-the-loop analytic workflows:
- Stage 0: ad hoc MCP or free-form EDA to understand the problem quickly
- Stage 1: notebook-centered EDA with `marimo`, pure Python modules, and a handwired driver
- Stage 2: add `Hydra` for config composition, CLI overrides, and multirun sweeps
- Stage 3: add `Kedro` (DAG runner, data catalog, viz) and/or `DVC` (caching, versioning, remotes)
- Stage 4: add `MLflow` + `Dagster`/`Prefect` for tracking and orchestration

Default loop:

`Frame -> Acquire -> Profile -> Hypothesize -> Model or Analyze -> Review -> Promote`

From Stage 1 onward, substantive analysis should live in notebooks and reusable
modules, not throwaway inline scripts. Most serious analyses should promote to
Stage 2 after initial findings if the user wants to continue, compare, rerun, or
keep the work.

The skill entrypoint is `SKILL.md`. Keep it lean and load focused references
only as needed for modeling guardrails, causal analysis, interpretability, and
later-stage implementation details.
