# Navigation and Information Architecture

Use this reference when the work involves app structure, screen roles, content grouping, navigation models, or wayfinding.

## Core principle

Information architecture comes before visuals.

Before choosing components, define:

- what exists
- how it is grouped
- how users move between groups
- how they know where they are
- how they recover or exit

## Screen archetypes

Classify the screen before styling it:

- `Overview`
  - supports scanning, triage, browsing, monitoring, or choosing
  - usually needs search, filters, sorting, and visible entry points

- `Focus`
  - supports reading, inspecting, comparing, or deciding on one object
  - should preserve orientation without stealing attention

- `Make`
  - supports editing, composing, building, or configuring
  - needs tool findability, workspace persistence, and recovery

- `Do`
  - supports completion of a guided process such as checkout, setup, or onboarding
  - often benefits from sequence cues and reduced distraction

## Navigation models

Choose the navigation model from task shape and screen size.

### Hub and spoke

Use when:
- mobile or compact apps need a stable home and focused destination screens

Why:
- simple mental model
- easy recovery through the hub

### Fully connected

Use when:
- major areas should be one jump apart
- desktop or web apps need fast lateral movement

Why:
- reduces travel cost for frequent switching

### Multilevel tree

Use when:
- the domain is truly hierarchical or deeply nested

Why:
- mirrors real hierarchy

Watch for:
- disorientation
- buried important destinations

### Step by step

Use when:
- order matters
- the user must complete a sequence

Why:
- reduces decision load during complex flows

### Pyramid

Use when:
- users need an overview hub plus guided next/back movement within a branch

### Flat workspace

Use when:
- tool-heavy environments need broad exposure and quick access

Why:
- reduces deep drilling

Watch for:
- clutter
- poor tool findability

## Wayfinding toolkit

Always provide a visible "you are here" cue.

Use:

- active global-nav state for major areas
- local tabs for sibling sections
- breadcrumbs for deep hierarchy or post-search context
- progress indicators for multi-step flows
- visible page title and current-state marker
- escape hatches when navigation is constrained
- deep links for shareable, restorable state
- selected states and transitions to reinforce movement

## Discovery patterns

Treat these as navigation, not as extras:

- search
- browse categories
- filters and facets
- tags
- related content
- menu pages
- fat menus
- sitemap footers

For large collections, support more than one discovery mode when needed:

- feature
- search
- browse

## Agent decision rules

- Promote frequent destinations upward.
- Flatten hierarchies where possible.
- Keep common actions within one-screen completion when feasible.
- Use progressive disclosure for secondary options.
- Prefer user-language labels over org-chart labels.
- On mobile, simplify and linearize large navigation structures.
- In modals or constrained spaces, reduce global nav and keep one obvious exit.

## Layout implications

- Use headers for global identity, current location, and high-level actions.
- Use sidebars when desktop apps need persistent area switching.
- Use footers for low-frequency breadth, utilities, or large-site exposure.
- Use menu pages when speed-to-destination matters more than ambient browsing.

## Failure modes

- Deep tree with no breadcrumb or recovery path
- Hidden frequent actions
- Missing current-location cues
- Overloaded global nav
- Labels based on internal teams instead of user intent
- Trying to solve structure problems with styling alone

## Quick checklist

- Is the screen archetype clear?
- Is the nav model appropriate for device and task?
- Can the user tell where they are?
- Can the user get back or escape safely?
- Are search, browse, and filters treated as part of navigation where relevant?
- Are frequent destinations easier to reach than rare ones?
