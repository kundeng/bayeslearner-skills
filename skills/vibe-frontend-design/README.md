# Vibe Frontend Design

`vibe-frontend-design` is a frontend skill for vibe-coding workflows: loose prompts, taste-led iteration, and rapid UI improvement that still has to ship as real code.

## What makes it different

This skill is not a generic “make it prettier” frontend helper.

It is designed to:

- turn vague taste language into concrete screen decisions
- choose patterns before decoration
- preserve or introduce a usable visual system
- keep implementation moving instead of replacing it with design theory
- handle dashboards, forms, lists, and dense admin UI without flattening them into generic SaaS screens

Compared with a more purely aesthetic frontend-design skill, this one is more likely to:

- explain the screen job
- identify the right pattern family
- preserve operator efficiency and state handling
- explicitly decide whether a lightweight design system should be introduced

## Best use cases

- “Make this UI feel more premium.”
- “Vibe code this screen.”
- “This dashboard is messy. Make it clearer and sharper.”
- “Polish this form, but keep it aligned with the product.”
- “Restyle this table without hurting operator speed.”

## Not for

- backend-only implementation
- branding-only requests with no screen interaction model
- voice UX, chat UX, AR/VR, or other non-screen interaction systems

## Quality bar

A good output from this skill should:

- make the main user task obvious
- improve hierarchy before adding visual effects
- preserve accessibility and state handling
- use pattern language to support implementation rather than replacing it
- produce real code or code-shaped implementation direction when the user wants a build
