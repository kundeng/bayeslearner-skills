# Architecture

This document describes the wise-rpa-bdd runtime architecture and data model for developers maintaining or extending the skill.

## Data Model

### Suite as Exploitation Spec

The `.robot` suite is both the spec and the executable artifact. It encodes:

- **Deployment**: suite-level identity (`${DEPLOYMENT}`)
- **Artifacts**: declared field schemas, format, output options
- **Resources**: one test case per data source, with entry URL, globals, and rules
- **Rules**: named blocks within a resource — state checks, actions, expansion, extraction, emit
- **Quality gates**: min records, fill percentages, max failure rates

### Record Flow

```
Suite Setup (deployment init)
  → Resource Case (entry + globals)
    → Rule Block (state → action → expand → extract → emit)
      → Artifact Store (flat records + tree records)
  → Quality Gates (validation)
Suite Teardown (finalize + output)
```

### Context Accumulation

Fields flow downward through rule blocks:
- Parent rule extracts `{name, url}` → child rule sees both fields
- Cross-artifact references: `{artifacts.page_urls.url}` resolves from artifact store
- Config references: `{config.timeout}` resolves from variables

### Artifact Store (Conceptual)

Two parallel storage paths:
- **Flat records**: denormalized rows for CSV/JSONL output
- **Tree records**: nested hierarchy preserving parent-child relationships

Emit steps push extracted data into named artifact slots. Merge steps combine child data back into parent artifacts by key.

### TreeRecord Shape

```
TreeRecord:
  node: rule name
  url: page URL at extraction time
  data: extracted key-value pairs
  children: nested TreeRecords from child rules
  extracted_at: ISO timestamp
```

## Execution Pipeline

### Two-Phase Validation

1. **BDD Validator** (`validate_suite.py`): structural check — every step has BDD prefix, no site-specific keywords
2. **Robot Dryrun** (`robot --dryrun`): execution check — keyword resolution, argument matching, continuation row parsing

### Generator Pipeline

```
YAML Profile → generate_from_wise_yaml.py → .robot suite → validate_suite.py → robot --dryrun
```

The generator handles:
- Artifact registration with field schemas and options
- Resource cases with entry URLs (static or `{from:}` references)
- Rule blocks with state/action/expand/extract/emit
- Quality gate synthesis
- Emit synthesis when `produces` is set but no explicit emit exists

### Keyword Library Layers

| Layer | Purpose |
|-------|---------|
| `WiseRpaBDD.py` | Deferred keyword library — records during definition, executes during walk |
| `ExecutionEngine` | Walks the rule tree with a browser adapter (StealthAdapter or RF-Browser) |
| `_StealthAdapter` | Raw Playwright with patchright + playwright-stealth for bot-detected sites |

### Deferred Execution Model

All WiseRpaBDD keywords **record** instructions during Robot Framework test case execution. No browser exists at this point. The `ExecutionEngine` opens the browser and walks the recorded rule tree during `finalize deployment` (Suite Teardown).

```
Test Case Execution:   Keywords → Record rules, actions, extractions
                       (no browser, no pages, no navigation)

Suite Teardown:        finalize_deployment → ExecutionEngine.run()
                       → open browser → walk rule tree → execute actions
                       → extract data → emit to artifacts → close browser
```

**Raw Browser keywords placed directly in test cases will fail** because no browser context exists during recording. Use deferred action keywords, `And I browser step`, or `And I call keyword` instead.

### Browser Actions (16 deferred keywords + 2 passthroughs)

| Category | Keywords |
|----------|----------|
| Navigation | `open`, `open bound field` |
| Interaction | `click`, `double click`, `type`, `type secret`, `select`, `check`, `hover`, `focus`, `press keys`, `upload file` |
| Timing | `scroll down`, `wait for idle`, `wait N ms` |
| Debug | `take screenshot` |
| Passthrough | `browser step` (any adapter method), `call keyword` (any RF keyword) |

## Hook System

Five lifecycle extension points (registered via `And I register hook`):

| Hook | Fires | Use Case |
|------|-------|----------|
| `post_discover` | After URL/page list built | Filter or reorder targets |
| `pre_extract` | Before page extraction | Skip pages, add headers |
| `post_extract` | After raw data captured | Clean, normalize, enrich |
| `pre_assemble` | Before output assembly | Transform, deduplicate |
| `post_assemble` | After final output | Validate, upload, notify |

## Interrupt Handling

Auto-dismiss patterns for blocking overlays:
- Cookie consent banners
- Newsletter popups
- Age verification modals

Configured via `And I configure interrupts` with `dismiss=<selector>` continuation rows. Checked after each page load and action.

## State Setup

Pre-scrape authentication or cookie consent:
- `skip_when=<url_pattern>` — skip if already authenticated
- Sequential actions: open, input, password, click
- Runs once per resource before extraction begins

## Design Decisions

1. **Suite as spec**: the .robot file is both documentation and executable — no separate config layer
2. **Generic keywords only**: site specifics go in arguments, never in keyword names
3. **BDD prefix enforcement**: structural constraint prevents keyword drift
4. **Continuation rows**: structured data in a flat Robot Framework format
5. **Two-gate validation**: BDD structure + Robot dryrun catch different error classes
