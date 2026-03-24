## Analytic Work In Spec-Driven Development

Use this when the spec is for:

- exploratory notebook workflows
- experiment sweeps
- Hamilton or DAG-based analysis pipelines
- marimo- or notebook-centered analysis that may later be promoted
- human review/approval loops for analysis outputs
- reproducibility layers such as Hydra, DVC, Kedro, Dagster, or Prefect

This does not replace `analytic-workbench`. Pair with that skill when the user
needs tool-selection or workflow-engineering guidance.

## What Changes In Analytic Specs

Analytic work often starts ambiguous and exploratory. The spec still needs to
be concrete, but it should reflect staged maturity:

1. exploratory/prototype work
2. review/comparison and approval
3. promotion into a reproducible or automated stage

Do not pretend the whole workflow is productionized on day one.

## Requirements Guidance

Requirements for analytic specs should cover:

- artifact outputs: tables, charts, datasets, reports, notebooks
- review checkpoints and approvers
- comparison criteria for parameter sweeps or experiments
- promotion criteria from exploratory to reproducible stages
- reproducibility expectations by tier
- error handling for missing/dirty/incomplete data

Examples:

- `WHEN an exploratory run completes THEN the system SHALL write outputs to a reviewable artifact directory.`
- `WHEN multiple parameter settings are tested THEN the system SHALL produce a comparison table for human review.`
- `IF outputs are not approved THEN the system SHALL block promotion to the next stage.`

## Design Guidance

Designs for analytic specs should make explicit:

- notebook vs library/module boundaries
- config management approach
- artifact directory conventions
- experiment tracking/comparison mechanism
- approval loop and reviewer touchpoints
- promotion path from ad hoc analysis to repeatable execution

If `analytic-workbench` applies, align the design with its tiered model rather
than inventing a separate maturity model.

## Task Guidance

Separate tasks by stage instead of collapsing them:

- scaffold exploratory notebook or analysis entrypoint
- implement core transforms/models/queries
- implement experiment sweep/config support
- generate comparison/review artifacts
- add approval gate or review step
- promote to reproducible workflow stage
- add validation/tests for promoted stages

Tests should be separate tasks here too:

- data validation tests
- deterministic transform tests
- workflow smoke tests
- approval/promotion gate tests

## What Not To Do

- Do not force a fully productionized architecture onto a short-lived exploration.
- Do not leave promotion criteria implicit.
- Do not mix exploratory notebooks and production workflow code without documenting the boundary.
- Do not treat “run experiment” and “review experiment” as one task.
