# Modeling Guardrails

Use this reference when the analytic workflow includes prediction, scoring,
classification, AutoML, or model comparison.

Keep it compact and practical. The goal is to prevent common workflow mistakes,
not to force heavyweight ML process on every project.

## Start With Framing

Before modeling, write down:

- the target to predict or estimate
- whether the task is binary, multiclass, regression, ranking, forecasting, or
  causal
- the decision the model is meant to support
- the metric or small metric set that matches that decision

Do not let AutoML choose the problem framing for you.

## Sampling

- If you are not using the full dataset, explain the sampling strategy in the
  visible plan.
- Do not default to naive random row sampling for temporal, spatial, grouped,
  or event-driven data.
- Prefer slices that preserve the structure of the problem:
  - full time windows for seasonal or behavioral patterns
  - location or entity slices for geographic or grouped effects
  - stratified sampling when label balance matters
- Keep train, validation, and test splits aligned with that structure.

## Imbalance and Target Shape

- Inspect label distribution before picking models or metrics.
- Consider whether multiclass should be reframed as binary when the decision is
  effectively "high risk vs not" or when classes are too sparse to support a
  stable model.
- For imbalanced tasks, avoid relying on accuracy alone.
- Choose metrics that reflect the real question, such as precision, recall,
  balanced accuracy, PR AUC, ROC AUC, class-weighted summaries, or calibration
  measures.

## Cross-Validation and Overfitting

- Use cross-validation or a holdout strategy that matches the data shape.
- For time-dependent data, prefer time-aware splits.
- For grouped data, avoid leaking entities across splits.
- Compare against simple baselines first before trusting more complex models.
- Watch for overfitting, leakage, and suspiciously large metric jumps after
  feature engineering.

## Feature Engineering

- Features must be reproducible in the same pipeline at train and review time.
- Keep feature logic in reusable modules, not in ad hoc cells or shell code.
- Prefer features that can be generated consistently from available inputs.
- Be cautious with aggregate features that may leak future information or test
  data statistics.

## AutoML

- Use AutoML after framing, baseline setup, and metric choice are already done.
- Treat AutoML as a model comparison accelerator, not a substitute for EDA.
- Exclude model families that are clearly unsuitable for the data size,
  runtime budget, or task shape.
- Put runtime budgets and comparison limits in config when possible.
- Review the winning model rather than accepting it blindly.

For causal work, read `references/causal-analysis.md`.
For explanation and interpretation work, read `references/interpretability.md`.
