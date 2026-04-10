# Requirements: WiseRpaBDD MDP Hardening (Phase 2)

## Introduction

Phase 2 of WiseRpaBDD engine work. Phase 1 delivered: observation gates (3 options), guards/steps data model, zero-sleep engine, AOP instrumentation, 26 golden files passing in both stealth and non-stealth modes.

Phase 2 resolves the remaining gaps: stealth bridge, quality gate regressions, docs that teach the AI exploration agent, and architecture improvements that exploit the rule-node structure.

## Glossary

- **Guard**: Type 1 state check — precondition before actions. Defensive, policy-controlled (skip/abort).
- **Observation**: Type 2 state check — synchronization gate between actions within a rule. Required for correctness.
- **Stealth adapter**: Patchright-based browser backend that avoids bot detection (TLS fingerprint, JS environment).
- **RF-Browser**: Robot Framework Browser library — Playwright wrapper with keyword interface.
- **call_keyword**: Defers an arbitrary RF keyword to walk time. Needs browser context to work.
- **AOP instrumentation**: Aspect-oriented timing wrapper around actions/rules, default on.

## Requirements

### Requirement 1: Stealth Bridge

**User Story:** As an AI agent generating robot suites, I want `call_keyword` to work in stealth mode, so that auth flows and complex multi-step interactions don't require mode switching.

#### Acceptance Criteria

1. WHEN a robot file uses `And I call keyword "X"` AND stealth mode is active, THE engine SHALL route Browser library calls (Click, Fill Text, etc.) inside keyword X to the stealth adapter's live page.
2. WHEN the stealth bridge is active, THE engine SHALL support at minimum: Click, Fill Text, Type Text, Get Text, Wait For Elements State, Get Element Count.
3. WHEN `quotes-callkw-test.robot` runs with `WISE_RPA_STEALTH=1`, THE engine SHALL produce >0 records and pass the quality gate.

### Requirement 2: Quality Gate Regressions

**User Story:** As a developer, I want all golden tests to pass quality gates without warnings, so that I can trust the regression suite as a correctness signal.

#### Acceptance Criteria

1. WHEN `hockey-teams-test` runs, THE engine SHALL extract rating for >90% of teams (currently 0% — selector may have changed).
2. WHEN `oscar-films-test` runs, THE engine SHALL extract >=80 records (currently 6 — AJAX tab expansion may be silent-failing).
3. WHEN `python-modindex-test` runs, THE engine SHALL extract module_name for >95% and description for >90%.
4. WHEN `mdn-web-api-test` runs, THE engine SHALL extract description for >80% of API pages.
5. WHEN `splunk-itsi-focused-test` runs, THE engine SHALL extract body for >90% of pages.

### Requirement 3: AI Agent Explore/Exploit Knowledge

**User Story:** As an AI coding agent running `/rrpa-explore` and `/rrpa-draft`, I want the skill docs to teach me the three observation gate patterns, dismiss scoping rules, and guard vs observation distinction, so that I produce correct robot files without user intervention.

#### Acceptance Criteria

1. WHEN the agent reads SKILL.md and workflow.md, THE docs SHALL explain async dependency identification during explore with concrete examples.
2. WHEN the agent drafts a robot file with interactive flows, THE docs SHALL guide it to choose between split rules, `await=`, and interleaved state checks.
3. WHEN the agent configures interrupts, THE docs SHALL warn against broad selectors with examples of what goes wrong.
4. WHEN the agent uses `Given url` or `And selector exists` after a `When` action, THE docs SHALL explain that this becomes an observation (not a guard).

### Requirement 4: AOP Slow-Motion Mode

**User Story:** As a developer debugging or demoing, I want a slow-motion mode that pauses between actions and optionally takes screenshots, so that I can see exactly what the engine does step by step.

#### Acceptance Criteria

1. WHEN `WISE_RPA_SLOW=N` is set, THE engine SHALL pause N ms after each action.
2. WHEN `WISE_RPA_SLOW_SCREENSHOT=1` is also set, THE engine SHALL capture a screenshot after each action.
3. WHEN slow mode is off (default), THE engine SHALL have zero overhead from this feature.

### Requirement 5: Dismiss as MDP Node

**User Story:** As a suite author, I want to scope dismiss selectors per rule or per phase, so that interactive panels aren't destroyed by global dismiss.

#### Acceptance Criteria

1. WHEN a rule declares `And I scope interrupts`, THE dismiss selectors for that rule SHALL override the global interrupt config.
2. WHEN a rule declares `And I pause interrupts`, THE engine SHALL skip dismiss for that rule's steps.
3. WHEN the rule completes, THE engine SHALL restore the previous dismiss config.

### Requirement 6: Declarative Rule Options

**User Story:** As a suite author, I want per-rule lifecycle hooks, so that I can add screenshots, custom timeouts, and retry behavior declaratively.

#### Acceptance Criteria

1. WHEN a rule declares `on_enter=screenshot`, THE engine SHALL take a screenshot before executing the rule's steps.
2. WHEN a rule declares `on_fail=screenshot`, THE engine SHALL take a screenshot when a guard or action fails.
3. WHEN a rule declares `timeout_ms=N`, THE engine SHALL abort the rule after N ms.

### Requirement 7: Tutorial and Documentation

**User Story:** As a reader of the tutorial, I want hard topics (stealth bridge, browser control hierarchy, adapter pattern) explained clearly with diagrams, and sections arranged in a logical learning order.

#### Acceptance Criteria

1. THE tutorial SHALL include a section explaining the 3-layer browser control hierarchy: RF-Browser → Playwright adapter → Stealth (Patchright) adapter.
2. THE tutorial SHALL include a section explaining the keyword hierarchy: deferred BDD > call_keyword > evaluate_js > browser_step.
3. THE tutorial sections SHALL be arranged in progressive difficulty order with cross-references.

### Requirement 8: Golden Test Coverage

**User Story:** As a developer, I want a golden test exercising multi-resource discovery+detail chaining, so that the pattern is regression-tested.

#### Acceptance Criteria

1. THE golden suite SHALL include a test with >=2 resources where resource 2 consumes URLs from resource 1 (discovery → detail pattern).
2. THE test SHALL pass in both stealth and non-stealth modes.

### Requirement 9: Dev → Main Merge (carry-forward from spec-07)

**User Story:** As a user installing the skill, I want the main branch to contain shippable code only, so that I can use the skill without dev tooling or broken state.

#### Acceptance Criteria

1. WHEN a user checks out main, THE branch SHALL contain only production files (no .venv, no dev-only test infra).
2. WHEN smoke tests run on main, THE tests SHALL pass without dev dependencies.

### Requirement 10: Yelp Stealth Validation (carry-forward from spec-07/08)

**User Story:** As a developer, I want to validate stealth mode against a fingerprint-heavy site, so that I know the limits of the patchright approach.

#### Acceptance Criteria

1. WHEN the stealth adapter runs against a DataDome/fingerprint-protected site, THE result SHALL be documented (success, partial, or known limitation with root cause).

## Out of Scope

- Full production browser runtime / deployment
- SQLite-backed artifact store (design approved in spec-08, implementation deferred)
- Ralph 2-hat mode testing (depends on ralph loop stability, separate concern)
- New site-specific golden tests beyond the multi-resource one
