# Eval Rubric

Use this rubric to review `vibe-frontend-design` outputs qualitatively.

The current eval set is intentionally small and should answer one question:

> Does this skill outperform a generic frontend-aesthetics skill when the user gives taste-driven prompts but still needs usable implementation?

## Global checks

A strong output should satisfy most of these:

- `Pattern before polish`
  - identifies the screen job, layout, or pattern family before leaning on visuals

- `Concrete implementation`
  - includes code or clearly implementable structure rather than taste adjectives only

- `Usability preserved`
  - keeps touch targets, hierarchy, state handling, and accessibility in view

- `System-aware`
  - preserves an existing design system when present, or explicitly addresses whether to introduce one when absent

- `Distinctive without slop`
  - has a clear visual point of view without collapsing into generic purple-gradient SaaS output

## Eval-specific checks

### Eval 1: Auth screen

- form stays simple and focused
- login and forgot-password actions are both clear
- warmth/premium tone appears without harming readability
- fields and actions feel touch-safe

### Eval 2: Product card

- card is responsive on mobile and desktop
- hierarchy makes image, title, price, and CTA immediately scannable
- visual direction feels editorial rather than library-default
- interaction states are accounted for

### Eval 3: Signup system fit

- validation states are explicit and believable
- password strength and mismatch handling are concrete
- output sounds compatible with a real design system rather than a one-off landing page
- semantics and accessibility are preserved

### Eval 4: Design-system decision

- output explicitly answers whether to do page polish or introduce a reusable system
- answer identifies reusable primitives or tokens
- structure is improved before visual styling
- implementation direction is concrete enough to begin coding

### Eval 5: Data-heavy admin

- operator efficiency remains central
- filtering, bulk actions, and row-level actions are visible and believable
- loading, empty, and error states are explicit
- premium styling supports clarity instead of competing with the data

## Failure signs

Common failure signals:

- only mood words, no concrete layout or component decisions
- aesthetics overwhelm dense workflows
- no mention of states
- no system decision when the prompt clearly requires one
- too much theory and not enough build guidance
