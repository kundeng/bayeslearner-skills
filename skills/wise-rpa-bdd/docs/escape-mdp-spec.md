# Escape MDP: Resilient Rule Execution for WiseRpaBDD

## Status: Design Spec (v0.2 — updated April 10, 2026)

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

### 1. Periodic Interrupt Dismiss (implemented — scoping lesson learned)

`_dismiss_interrupts()` runs before every action and state check. This is
the simplest escape mechanism — a background recovery process that clears
known obstacles.

```robot
And I configure interrupts
...    dismiss=text="Got it"
```

**Status:** Implemented. Works.

**Critical lesson (April 10):** Dismiss selectors must be **surgical**.
Broad selectors like `[role="dialog"] button[aria-label="Close"]` or
`[data-testid="modal-container"] button` match interactive panels (search
bars, calendars, guest pickers) and destroy the flow by closing them
mid-interaction. Only dismiss known popup patterns with specific selectors.
The agent must verify each dismiss selector during explore with panels open.

### 2. Navigation-Aware Evaluate JS (implemented)

When `evaluate_js` triggers a page navigation (detected by URL change or
script content heuristics), the engine automatically:
- Waits for `load` state
- Runs dismiss-during-settle loop (3 × 3s with interrupt dismiss)

**Status:** Implemented. Eliminates the need for manual `When I wait Xms`.

### 2b. Observation Gates — Zero-Wait Execution (implemented)

Two MDP-native patterns replace all `When I wait` in robot files:

**Option 1 — Split rules:** Each s,a→o transition is its own rule. The
engine's `wait_for_elements_state` (10s) naturally gates entry.

```robot
I define rule "type_city"
    When I type "${CITY}" into locator "#input"
I define rule "autocomplete_ready"
    And I declare parents "type_city"
    And selector "[data-testid='option-0']" exists
I define rule "select_city"
    And I declare parents "autocomplete_ready"
    When I click locator "[data-testid='option-0']"
```

**Option 2 — `await=` inline gate:** After any action, wait for a selector
before advancing to the next action within the same rule.

```robot
I define rule "enter_city"
    When I type "${CITY}" into locator "#input"
    ...    await=[data-testid='option-0']
    When I click locator "[data-testid='option-0']"
```

**Status:** Both implemented and verified on live Airbnb (96 records, Nov
2026 dates, 2 adults). `await=` works on click, type, click_text. Supports
fallback selectors.

### 2c. Zero time.sleep Engine (implemented)

All fixed sleeps removed from the engine. Replacements:

| Was | Now |
|-----|-----|
| `time.sleep(page_delay)` after pagination click | Staleness detection: poll until first element text changes |
| `time.sleep(0.3)` after calendar forward | Poll until heading text changes |
| `time.sleep(0.5)` after scroll | `networkidle` |
| `time.sleep(2.0)` after combo click | `networkidle` |
| `time.sleep(1)` after evaluate_js | `domcontentloaded` |
| `delay_ms=` on click/type | Removed — use `await=` instead |
| Stepper `bl.click()` × N | JS click + `wait_for_elements_state` (avoids Playwright stability timeout on re-rendering elements) |

Only remaining `time.sleep`: retry backoff loop (intentional delay between retries).

### 3. AOP-Style Rule Instrumentation (implemented — default on)

AOP wrapper `_do_action_instrumented` around `_do_action`:
- Per-rule timing: state_check, actions, expansion, total
- Per-action timing: logs any action >0.5s or failures with context
- Default on (`WISE_RPA_INSTRUMENT=0` to disable)

**Status:** Implemented. No inline timing code in action execution. The
wrapper handles all instrumentation uniformly.

**Future:** Declarative per-rule options (`on_enter=screenshot`,
`on_fail=screenshot+retry`, `timeout_ms=N`) are still desirable but not
yet implemented.

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

### 5. Built-in Navigation Keywords (implemented)

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
