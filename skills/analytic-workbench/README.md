# Analytic Workbench Skill

Human-directed, AI-operated analysis. The AI computes; the human steers
through a review surface (marimo notebook or Quarto doc). Intermediate findings
are presented for redirection at every step — this is not a batch pipeline.

Two axes advance together at each mode:

| Mode | Execution | Review Surface |
|---|---|---|
| `probe` | bare Python | chat + inline figures |
| `explore` | Hamilton Driver | marimo explore notebook or Quarto EDA doc |
| `experiment` | Hamilton + Hydra | marimo report app or Quarto report |
| `operate` | + orchestrator + MLflow | deployed marimo app or dashboard |

Default loop:

`Frame -> Acquire -> Profile -> Hypothesize -> Model or Analyze -> Review -> Promote`

Hamilton + Hydra are the primary execution stack. marimo + Quarto are the
primary presentation stack. Together they cover DAG execution, config, sweeps,
caching, visualization, interactive review, and stakeholder reporting.

The skill entrypoint is `SKILL.md`. Keep it lean and load focused references
only as needed for modeling guardrails, causal analysis, interpretability, and
later-stage implementation details.
