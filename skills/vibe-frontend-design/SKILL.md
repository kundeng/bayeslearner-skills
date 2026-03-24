---
name: vibe-frontend-design
description: Design and implement distinctive, production-grade screen UI for vibe-coding workflows: loose prompts, taste-driven iteration, and fast frontend polishing that still respects usability, layout discipline, and real code constraints. Use this skill whenever the user wants a frontend to feel more polished, modern, premium, cohesive, bold, or simply "better", including landing pages, dashboards, app screens, forms, lists, onboarding, settings, and component restyling. Also use it for vague requests like "make this UI nicer", "give this more personality", "make it feel expensive", or "vibe code this screen." Preserve existing design systems when they are good; introduce a clearer visual and interaction system when they are weak or absent.
---

# Vibe Frontend Design

This skill helps an agent turn vague frontend taste requests into usable, screen-first UI decisions and working code. It combines three things:

- human-centered interaction patterns
- disciplined layout and sizing defaults
- practical implementation judgment inside a real codebase

It is for vibe coders: users who often describe the desired feel before they describe the exact structure. The job of the agent is to convert that taste signal into concrete hierarchy, layout, states, and implementation choices without flattening everything into generic component-library UI.

Use it for screen interfaces only. Do not stretch it to voice UX, chatbots, AR/VR, or other non-graphical interaction models unless the user explicitly wants crossover guidance.

## Scope

In scope:
- web apps, marketing sites, dashboards, mobile web, app screens
- flows such as onboarding, auth, checkout, search, settings, CRUD, detail/list views
- component and page restyling
- translating visual direction into React, Next.js, Tailwind, CSS, or similar frontend code
- improving hierarchy, navigation, forms, commands, lists, and data display

Out of scope by default:
- voice and conversational UX
- AR/VR or spatial interfaces
- backend-only work
- branding-only work with no screen interaction model

## Operating stance

- Start with people and tasks, not pixels.
- Organize content and actions before styling them.
- Treat component libraries as a floor, not a ceiling.
- Preserve existing product patterns when they are coherent.
- Invent boldly only where the current system is weak, generic, or missing.

## Agent workflow

Follow this order instead of jumping straight to visuals:

1. Inspect the context first.
   - Read the existing page, component, design system, and surrounding styles.
   - Identify whether the repo already has usable tokens, primitives, spacing conventions, and motion patterns.
   - Preserve good existing patterns instead of replacing them with generic AI aesthetics.
   - If the repo has no clear visual design system or reusable styling rules, consider asking the user whether they want one introduced. If that answer would materially change the implementation approach, ask early; otherwise make a strong first pass and note that a reusable system can be extracted next.

2. Define the screen job.
   - Who is using this UI?
   - What is the primary action or decision?
   - What must feel obvious in the first 5 seconds?

3. Choose the pattern family before choosing styles.
   - information architecture
   - navigation and wayfinding
   - layout and hierarchy
   - lists and collections
   - forms and controls
   - actions and commands
   - complex data display

4. Build the structure.
   - Use block framing first as an internal reasoning tool: treat headings, text, cards, images, actions, and controls as rectangles.
   - Solve grouping, alignment, and spacing before visual polish.
   - Do not turn block framing into ceremony in the final answer unless it helps the user. The point is to stop the agent from jumping straight to decoration, not to force wireframing language into every response.

5. Apply the visual system.
   - If the existing system is strong, extend it.
   - If not, create a focused direction with intentional type, color, shape, and motion.
   - Avoid defaulting to bland SaaS UI unless the product already wants that.

6. Implement in code.
   - Use the repo's stack and conventions.
   - Prefer reusable tokens, CSS variables, and composable primitives when the change is substantial.
   - Include hover, focus, empty, loading, error, and success states when they matter.

7. Audit before finishing.
   - Check spacing, alignment, interaction states, responsiveness, accessibility, and visual coherence.

## Working with vibe coders

Treat fuzzy prompts as usable product input, not as ambiguity to hide behind.

- If the user gives a mood like "clean", "premium", "playful", "editorial", or "more vibe", translate it into concrete decisions about type, density, color, motion, and interaction emphasis.
- Do not ask the user to become a designer unless the missing information is truly blocking. Make a strong first pass with defensible assumptions.
- Prefer showing a clear point of view over listing many options.
- Keep the work shippable. Vibe coding is still frontend implementation, not only art direction.
- When the user is moving fast, protect them from the common failures: weak hierarchy, random styling, broken states, inaccessible contrast, and tiny hit areas.
- If the existing UI is bland but structurally sound, improve the visual system without breaking the flow.
- If the existing UI is structurally weak, fix the structure first and then add vibe.
- If there is no visible design system at all, decide whether the task calls for a one-off polish pass or the start of a reusable system of tokens, primitives, and rules. Ask the user when that choice would significantly affect scope.

## Keep it lightweight

This skill should guide implementation, not slow it down.

- Use the pattern and structure steps internally to improve decisions.
- Do not force a long design lecture when the user clearly wants code.
- Do not block implementation with unnecessary analysis once the structure is clear.
- If another active skill owns the stack or domain, complement it instead of competing with it.
- Preserve the repo's coding conventions, framework constraints, and existing component patterns.
- If the task is straightforward, keep the structure reasoning brief and move quickly into implementation.

## Hard defaults

Use these unless the existing product language clearly calls for something else.

Some defaults are universal. Some are mobile-biased. Do not blindly apply mobile sizing to dense desktop tools.

Universal defaults:

- Use an 8-point-based spacing ladder with `4/8/16/24/32/48`.
- Use smaller gaps inside a group and larger gaps between groups.
- Center button labels mechanically, not by eye: top equals bottom, left equals right.
- If an icon or text link looks small, expand the hit area invisibly instead of shrinking usability.
- Start with one primary accent and derive supporting neutrals or tints from it before adding more colors.
- Use realistic, theme-matched content. Avoid lorem ipsum and inconsistent fake data.

Mobile-biased defaults:

- Keep touch targets at `44x44` minimum where touch is primary.
- Keep buttons at `40-48px` high minimum on mobile; `44-60px` is usually safer.
- Do not let important mobile UI text drop below `12px`.

Desktop adaptations:

- For pointer-first desktop UI, interactive controls can be denser when the workflow benefits from it.
- Typical desktop control heights:
  - general product UI: `36-44px`
  - dense operator/admin tables: `32-40px`
- Preserve larger targets for destructive actions, primary CTAs, and mixed-input contexts.
- Use the same spacing logic on desktop, but scale section spacing and layout regions to the larger canvas rather than simply enlarging every element.
- In dense desktop tools, optimize for scan speed and grouping clarity before applying mobile-style spaciousness.

## Visual direction guidance

When the user wants "vibe", that does not mean random decoration. It means a stronger point of view.

- Typography: pick a type direction that matches the product character. Do not default to Inter unless the repo already does.
- Color: define a small, intentional palette. Avoid muddy low-contrast pastels and harsh clashing accents.
- Shape: make corner radii, borders, and shadows feel related across components.
- Motion: use a few meaningful transitions or reveal patterns instead of constant animation noise.
- Density: decide whether the UI should feel compact, editorial, luxurious, playful, or operational, then make spacing and type support that choice.

## Pattern template

When reasoning about a UI pattern, structure it like this:

- What: define the pattern in one sentence.
- Use when: say when it fits, plus important constraints or exceptions.
- Why: connect it to user behavior, comprehension, speed, safety, or trust.
- How: describe the layout, interaction, states, and implementation choices.

This keeps the agent from cargo-culting components without understanding the problem they solve.

## Output expectations

For design or planning requests:
- explain the chosen pattern direction before or alongside the implementation
- make the screen job, hierarchy, and key actions explicit
- state what is being preserved from the existing system and what is being changed

For implementation requests:
- produce working code, not only design language
- make responsive behavior intentional on both mobile and desktop
- keep semantics, keyboard access, and focus states intact
- prefer design tokens or reusable styling primitives for repeated decisions
- if no design system exists, say whether you are doing a local page polish or establishing the first layer of a reusable visual system

For complex implementation prompts such as dashboards, admin tables, dense data views, and design-system refactors:
- do not stop after pattern selection and rationale
- follow the structural explanation with a fuller implementation layer
- include the main layout regions, component primitives, state handling, token recommendations, and responsive behavior
- provide at least one substantial code sketch when the user is asking for implementation, not just direction
- keep the implementation tied to the chosen pattern so the output does not split into disconnected "strategy" and "code" halves

For dashboard and design-system prompts specifically:
- include a concrete component map such as `MetricTile`, `DashboardCard`, `FilterRail`, `TableShell`, or similar primitives
- show a small example token set or theme shape instead of speaking about tokens only in the abstract
- make clear which parts are one-off screen layout and which parts belong in the reusable system
- if the user is asking for implementation, include at least a small layout or primitive code sketch, not only prose

For vague "make it better" requests:
- interpret them as a request for stronger hierarchy, clearer actions, better spacing, more coherent visual identity, and more convincing states
- avoid replying with generic style adjectives only; convert them into actual code and interface decisions

When the prompt is dense or operational:
- optimize first for scan speed, command clarity, and recoverability
- use visual polish to reinforce clarity, not to compete with it
- explain how loading, empty, error, bulk-action, and selection states work

When the prompt is implementation-heavy:
- keep pattern language in service of the build
- prefer concrete layout, primitives, states, and code over abstract design commentary

## Reference files

Read only what you need:

- `references/behavioral-patterns.md`
  Use for human behavior patterns such as Safe Exploration, Instant Gratification, Satisficing, Deferred Choices, and Habituation.

- `references/spacing-typography.md`
  Use for spacing ladders, text sizing, touch targets, radii, and sizing rules.

- `references/color-shadows.md`
  Use for accent-derived palettes, muted supporting colors, and shadow ratios.

- `references/forms-validation.md`
  Use for field sizing, grouping, validation states, and common auth or form flows.

- `references/pattern-selection.md`
  Use when the prompt is vague, taste-driven, or underspecified and you need to turn mood words into concrete pattern, layout, and state decisions.

- `references/navigation-ia.md`
  Use when the work involves screen roles, information architecture, app structure, navigation models, breadcrumbs, progress indicators, or wayfinding.

- `references/lists-actions-data.md`
  Use when the UI centers on collections, commands, tables, dashboards, charts, filtering, retrieval, or complex data views.

## Pitfalls to avoid

- Jumping straight to gradients and shadows before fixing hierarchy.
- Replacing an existing design system with generic patterns for no reason.
- Making everything visually louder instead of making the primary action clearer.
- Shipping only the happy path with no empty, loading, or error states.
- Mixing incompatible icon styles, radii, or typography voices.
- Treating "vibe" as decoration instead of product character plus usability.
