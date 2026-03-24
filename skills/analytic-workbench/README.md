# Analytic Workbench Skill

Reusable skill for human-in-the-loop analytic workflows:
- Tier 1: `marimo` + pure Python modules + handwired driver
- Tier 2: add `Hydra` for config composition, CLI overrides, and multirun sweeps
- Tier 3: add `Kedro` (DAG runner, data catalog, viz) and/or `DVC` (caching, versioning, remotes)
- Tier 4: add `MLflow` + `Dagster`/`Prefect` for tracking and orchestration

The skill entrypoint is `SKILL.md`.
