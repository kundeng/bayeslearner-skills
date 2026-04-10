# Escape MDP: Resilient Rule Execution for WiseRpaBDD

## Status: Design Spec (v0.1)

## Problem

Web pages are non-deterministic environments. Popups appear at unpredictable
times, pages load at variable speeds, SPAs hydrate asynchronously, and
navigation destroys execution contexts. The current engine handles these as
edge cases with hardcoded waits and one-shot dismissals. This doesn't scale.

## Core Insight

WiseRpaBDD's rule tree is a **delayed Markov Decision Process (MDP)**. Each
rule is a state. Actions cause transitions. The browser's DOM is the
observation. What's missing: **escape transitions** — automatic recovery
from unexpected observations (popups, timeouts, navigation failures).

## Architecture

### 1. Periodic Interrupt Dismiss (implemented)

`_dismiss_interrupts()` runs before every action and state check. This is
the simplest escape mechanism — a background recovery process that clears
known obstacles.

```robot
And I configure interrupts
...    dismiss=text="Got it"
...    dismiss=[role="dialog"] button[aria-label="Close"]
```

**Status:** Implemented in this session. Works.

### 2. Navigation-Aware Evaluate JS (implemented)

When `evaluate_js` triggers a page navigation (detected by URL change or
script content heuristics), the engine automatically:
- Waits for `load` state
- Runs dismiss-during-settle loop (3 × 3s with interrupt dismiss)

**Status:** Implemented. Eliminates the need for manual `When I wait Xms`.

### 3. AOP-Style Rule Instrumentation (proposed)

Instead of inline debug prints, rules support lifecycle decorators:

```robot
And I set rule options for "root"
...    on_enter=screenshot
...    on_fail=screenshot+retry
...    timeout_ms=30000
```

The engine instruments rules at walk time. Debug screenshots, timing, retry
logic — all controlled declaratively, removable without code changes.

**Implementation:** Add `options` dict to `RuleNode`. Engine checks options
at each lifecycle point (enter, action, state_check, fail, exit).

### 4. Recovery Rules (proposed)

User-defined escape transitions when state checks fail:

```robot
And I set recovery for "root"
...    when=state_check_fail
...    action=dismiss_all
...    action=wait_3000
...    retry=3
```

Or as a reusable pattern:

```robot
I define recovery "dismiss_and_retry"
    And I evaluate js "() => { ... dismiss all overlays ... }"
    When I wait 2000 ms
```

The engine attaches recovery behaviors to rules and invokes them
automatically on failure before giving up.

### 5. Built-in Navigation Keywords (proposed)

Replace imperative JS with declarative keywords:

| Current (imperative JS) | Proposed (declarative) |
|---|---|
| `evaluate_js "() => { window.location.href = url + '&price_max=3000' }"` | `When I add url params "price_max=3000&min_bedrooms=1"` |
| `evaluate_js "() => { for (b of buttons) if (b.text === 'Anywhere') b.click() }"` | `When I click text "Anywhere"` |
| `evaluate_js "async () => { ... calendar loop ... }"` | `When I navigate datepicker to "${CHECKIN}"` |
| `evaluate_js "() => { stepper.click() × N }"` | `When I set stepper "[data-testid='stepper-adults']" to ${N}` |

Each new keyword is:
- Deferred (records during definition, executes during walk)
- Adapter-agnostic (works with RF-Browser and stealth adapter)
- Navigation-aware (automatically waits if it causes page change)

### 6. Fix `call_keyword` for Stealth Mode (proposed)

When stealth mode is active, `call_keyword` fails because RF Browser lib
has no open page. Two approaches:

**A. Register stealth page with RF Browser lib** — at context creation,
inject the stealth adapter's page into the Browser library's internal
catalog. Pros: full RF keyword compatibility. Cons: tight coupling.

**B. Route `call_keyword` through the adapter** — instead of
`BuiltIn().run_keyword()`, parse the keyword's Browser lib calls and
delegate to the adapter. Pros: clean separation. Cons: incomplete coverage.

**Recommended:** Start with (A) for compatibility, gate behind a flag.

### 7. Keyword Hierarchy (guidance for agents)

```
Prefer → 1. Deferred BDD keywords (When I click locator, When I type, etc.)
         2. And I call keyword (multi-step RF flows — needs stealth fix)
         3. And I evaluate js (escape hatch for unsupported patterns)
         4. And I browser step (raw adapter method — no flow control)
```

As the framework matures, patterns migrate from level 3→1.

## Generate Prompt Improvements

### Re-exploration after first draft

Current flow: orient → explore → draft → review (loop) → done

Proposed flow: orient → explore → draft → review → **re-explore if needed** → revise → review

The agent should be allowed (encouraged) to go back to `agent-browser`
after the first dryrun to verify selectors that didn't resolve, check
interaction flows, or discover popups that need interrupts.

### Generalizability guidance

The prompt should instruct the agent to:
- Use `*** Variables ***` for all dynamic values (URLs, search terms, dates)
- Never hardcode `place_id`, session tokens, or page-specific identifiers
- Build entry URLs through interactive exploration, not by guessing params
- Use `And I configure interrupts` for site-specific popup patterns

### Construct variety

Different prompt variants can encourage the agent to exercise different
keyword patterns:
- **Basic:** pagination + extraction (quotes-test pattern)
- **Interactive:** form filling + search + extraction (airbnb pattern)
- **Multi-resource:** discovery → detail chaining (docs pattern)
- **Stealth:** interrupt dismiss + evaluate_js escapes (protected sites)
