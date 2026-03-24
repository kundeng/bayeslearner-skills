# Pattern Selection for Vibe-Coding UI Work

Use this reference when the user gives a taste-led or underspecified prompt such as:

- "make this feel premium"
- "give this more vibe"
- "make the dashboard cleaner"
- "vibe code this screen"

The goal is to convert a fuzzy aesthetic request into concrete UI structure and implementation choices.

## Core Principle

Choose the pattern before polishing the surface.

- Start from user goals, task shape, and screen role.
- Pick the structural pattern family first.
- Apply visual direction only after the layout and interaction model are clear.

Good responses should sound like:

> Given this audience and task, this pattern fits best; here are the defaults I am applying to make it concrete.

Not like:

> Here is a prettier version with nicer colors and fonts.

## Inputs to extract from a vague prompt

Pull these from the prompt or infer them conservatively:

- Product type: app, dashboard, landing page, checkout, form, editor, catalog
- Primary task: browse, compare, enter data, configure, monitor, create, complete a flow
- Audience: consumer, operator, analyst, admin, creator
- Screen role: overview, focus, make, do
- Constraints: mobile-first, desktop-heavy, existing design system, real codebase, accessibility needs

## Decision order

Use this sequence:

1. Define the likely user and primary job.
2. Classify the screen:
   - `Overview`: scanning, choosing, monitoring
   - `Focus`: reading, inspecting, deciding
   - `Make`: building, editing, composing
   - `Do`: completing a guided task or settings flow
3. Choose the primary pattern family:
   - IA and navigation
   - layout and hierarchy
   - lists and collections
   - forms and controls
   - actions and commands
   - complex data display
4. Set safe defaults for spacing, sizing, type, and states.
5. Apply the visual direction to reinforce the chosen pattern.

## Safe assumptions when details are missing

If the prompt is vague, assume:

- a conventional screen UI, unless another modality is explicit
- an 8-point spacing system
- clear grouping through space before borders or decoration
- touch-safe targets and readable text
- one font family, one icon set, one primary accent until the system proves it needs more
- a real code implementation, not only mockup language

Bias toward:

- larger targets
- more spacing
- simpler structure
- stronger primary-action emphasis

## Translating mood words into UI decisions

Map taste language into concrete choices:

- `premium`:
  - more breathing room
  - stronger typographic hierarchy
  - fewer but more deliberate colors
  - restrained motion
  - higher visual contrast on key actions

- `playful`:
  - softer shapes or more expressive motion
  - brighter accent usage
  - friendlier copy rhythm
  - more visible delight states

- `editorial`:
  - stronger type-driven layout
  - asymmetry used deliberately
  - clearer content rhythm
  - image/content balance over component repetition

- `clean`:
  - fewer competing surfaces
  - tighter hierarchy
  - reduced visual noise
  - clearer separation between primary and secondary actions

- `more vibe`:
  - pick one stronger point of view in type, color, shape, or motion
  - do not merely add effects everywhere

## Response template for the agent

When the prompt is loose, structure the response internally like this:

- `Interpretation`
  - likely product, audience, and primary task

- `Pattern choice`
  - which pattern family fits best
  - why it fits

- `Assumptions`
  - what defaults are being applied because the prompt omitted them

- `Concrete UI decisions`
  - layout
  - grouping
  - navigation
  - states
  - spacing
  - type
  - color
  - motion

- `Open questions`
  - only ask what would materially change the pattern choice

## When to ask clarifying questions

Ask only if the answer would meaningfully change:

- modality
- platform priority
- audience type
- data density
- whether the work must preserve an existing design system

Do not ask questions the agent can safely answer with defaults.

## Failure modes

- Treating vibe as decoration instead of structure plus character
- Asking the user to do design strategy work the agent can infer
- Jumping to gradients, shadows, and animations before hierarchy is solved
- Returning generic mood words without translating them into code and interface decisions
