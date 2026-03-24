# Lists, Actions, and Data Display

Use this reference when the UI centers on collections, retrieval, commands, dashboards, charts, tables, or dense information.

## Pattern selection heuristics

Start by classifying the main job:

- `overview`
- `browse`
- `find known item`
- `filter or sort`
- `edit`
- `create`
- `compare`
- `monitor`

Choose the structure from the job, not from aesthetic preference alone.

## Lists and collections

### List-detail patterns

Use one of these first:

- `Two-Panel Selector`
  - best for desktop or tablet when users need fast switching between list and detail

- `One-Window Drilldown`
  - best for mobile or narrow screens

- `List Inlay`
  - best when users need inline expansion or comparison without losing list context

### Rich visual collections

- `Cards`
  - good for mixed metadata and actions

- `Thumbnail Grid`
  - good for image-first browsing

- `Carousel`
  - use sparingly
  - better for casual browsing than efficient retrieval

### Long-list retrieval

Before adding more scrolling, consider:

- filtering
- search
- `Jump to Item`
- `Alpha/Numeric Scroller`
- pagination

Treat pagination as a navigation model with visible position and range, not as a backend artifact.

### Inline editing and creation

If list-based creation is frequent, consider a `New-Item Row` instead of forcing a modal or separate page.

## Actions and commands

### Placement rules

- Put actions near the object they affect.
- Separate global actions from item-level actions.
- Keep high-frequency or high-risk actions visible.
- Hide only low-frequency or contextual actions.

### Action patterns

- `Button Groups`
  - use for compact related actions

- `Action Panel`
  - use for persistent grouped tools

- `Hover Tools`
  - pointer-first only
  - replace with tap-triggered reveal on touch devices

- `Prominent Done / Next Step`
  - use when the completion action should dominate the decision

- `Smart Menu Items`
  - include object or action context in labels where helpful

- `Preview`
  - use when outcomes are costly, visually ambiguous, or hard to undo

## Progress, waiting, and recovery

- For waits over about one second, show progress feedback.
- Use a spinner only when progress cannot be estimated.
- Keep nearby cancel controls for long-running operations.
- Keep the interface responsive during work.
- Model undo/history at meaningful user-action granularity.

Useful recovery patterns:

- undo
- multilevel undo
- command history
- macros for repeated expert workflows

## Complex data display

Choose the display form from the data shape and user task:

- table
- tree
- timeline
- map
- graph
- multiple coordinated views

### Encoding rules

- Use preattentive variables such as color, size, position, and shape for what must pop.
- Do not bury critical distinctions in plain text only.
- Preserve focus plus context when revealing detail.
- Prefer highlighting over hiding when users need subset plus whole visibility.

### Interactive data patterns

- `Datatips`
  - use for exact values in dense graphics

- `Data Spotlight`
  - use to isolate one series or layer in crowded visuals

- `Dynamic Queries`
  - use for immediate, iterative filtering with familiar controls

- `Data Brushing`
  - use when a subset should stay linked across chart, table, and map views

- `Multi-Y Graph`
  - use for shared x-axis comparisons across metrics with incompatible scales

- `Small Multiples`
  - use for comparing many similar slices while keeping scales consistent

## Accessibility and modality notes

- Do not rely on hover-only access for critical actions.
- Keep command labels explicit.
- Ensure tables, charts, and filters remain keyboard reachable where relevant.
- Use redundant encoding where color alone would be ambiguous.

## Frontend implementation checklist

- Is the list or data view optimized for the actual retrieval task?
- Are actions visible at the right level: global vs local?
- Are progress and cancel states represented for long operations?
- Does the dense view still preserve focus and context?
- Are sorting, filtering, and comparison paths obvious?
- Does the layout still work on narrow screens?

## Failure modes

- Using carousels for tasks that require efficient scanning
- Hiding common actions behind menus for aesthetic reasons
- Overloading dense data views with detail but no emphasis
- Using spinners with no context for long waits
- Breaking touch behavior by relying on hover tools
