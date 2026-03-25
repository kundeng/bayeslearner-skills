# Causal Analysis Reference

Use this reference when the user wants causal claims, treatment effects,
interventions, counterfactual framing, or language like "does X cause Y".

## Start With Framing

Write down:

- treatment
- outcome
- unit of analysis
- confounders you believe matter
- the decision the estimate will support

Do not present predictive feature importance as causal effect.

## Guardrails

- Keep causal analysis separate from predictive modeling in both code and claims.
- State assumptions explicitly.
- Prefer simple, reviewable designs over vague "causal AI" framing.
- Match the method to the data and assumptions, not to tool novelty.

## Methods

Common patterns:

- adjustment or regression with explicit confounders
- matching
- propensity weighting
- difference-in-differences
- regression discontinuity
- instrumental variables

Use the simplest method that can be defended for the question at hand.

## Review Expectations

At minimum, show:

- treatment and outcome definitions
- covariates or confounders used
- overlap or support concerns
- sensitivity or caveat notes
- effect estimate with uncertainty

If assumptions are too weak for a causal claim, say so clearly and downgrade the
result to associational analysis.
