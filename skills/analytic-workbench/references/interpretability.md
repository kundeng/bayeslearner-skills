# Interpretability Reference

Use this reference when the user wants explanations, feature importance,
audience-facing interpretation, or model diagnostics beyond headline metrics.

## Start With Audience

Match the explanation style to the decision:

- developer or analyst: detailed diagnostics are usually appropriate
- stakeholder or reviewer: concise explanation with caveats is usually better

## Baseline Rule

Prefer interpretable baselines early when they are decision-useful. If a more
complex model wins, explain why the extra complexity is worth it.

## Common Artifacts

Use the smallest set that answers the question:

- coefficients or odds ratios
- feature importance
- SHAP summaries
- ablations
- calibration plots
- slice-level error analysis
- confusion matrices or ranking diagnostics

## Guardrails

- Do not confuse explanation with causation.
- Do not present unstable importance as a strong business conclusion.
- Prefer comparison across runs or slices over one isolated chart.
- Tie explanations back to model framing, data coverage, and evaluation metrics.

## Review Expectations

For important outputs, show:

- what is being explained
- which explanation artifact was chosen and why
- what the artifact supports
- what it does not support
