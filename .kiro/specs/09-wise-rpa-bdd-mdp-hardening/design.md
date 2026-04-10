# Design: WiseRpaBDD MDP Hardening (Phase 2)

## Architecture Context

The engine is a delayed MDP walker. Rules are states. Actions cause transitions. The browser DOM is the observation. Phase 1 established:

```
RuleNode
  guards: list[StateCheck]        # Type 1 — preconditions
  steps: list[Action | StateCheck] # Type 2 — actions + observations
  guard_policy: str                # skip | abort
```

Phase 2 builds on this foundation.

## Section 1: Stealth Bridge & Browser Control Hierarchy

### The 3-Layer Stack

```
Layer 3: RF Keywords          Click, Fill Text, Get Text, ...
         ↓ dispatches to
Layer 2: Adapter Interface    click(), fill_text(), get_text(), ...
         ↓ implemented by
Layer 1a: RFBrowserAdapter    → RF-Browser lib → Playwright
Layer 1b: StealthAdapter      → Patchright (patched Playwright)
```

### call_keyword Problem

`And I call keyword "Login"` runs an RF keyword at walk time. Inside that keyword, raw RF-Browser calls (Click, Fill Text) go directly to Layer 3. In stealth mode, Layer 3 has no page — the page lives in Layer 1b.

### Decision: Option A — Register stealth page with RF-Browser

**Rationale:** Full compatibility. RF-Browser internally stores pages in a catalog. At stealth context creation, inject the patchright page into RF-Browser's catalog. All RF keywords then resolve against the stealth page.

**Implementation:**
1. After `_StealthAdapter` opens its page, call `Browser.new_context()` and `Browser.new_page()` via RF-Browser, then replace the internal page reference with the patchright page handle.
2. Gate behind existing `stealth` flag — no new config needed.
3. Fallback: if injection fails (RF-Browser version mismatch), log warning and fall back to current bridge behavior.

### Slow-Motion Mode

Add to `_do_action_instrumented`:
```python
if self._slow_ms:
    time.sleep(self._slow_ms / 1000.0)  # intentional — demo pause
    if self._slow_screenshot:
        bl.take_screenshot(filename=f"slow_{rule}_{action_idx}.png")
```

Read from `WISE_RPA_SLOW` and `WISE_RPA_SLOW_SCREENSHOT` env vars at engine init.

## Section 2: Dismiss Scoping & Rule Options

### Dismiss as Scoped Config

Current: global `ctx.interrupt_selectors` checked before every action.

Proposed: per-rule override stack.

```python
@dataclass
class RuleNode:
    interrupt_override: list[str] | None = None  # None = inherit global
    interrupt_paused: bool = False                # True = skip dismiss for this rule
```

New keywords:
- `And I scope interrupts` with continuation rows → sets `interrupt_override`
- `And I pause interrupts` → sets `interrupt_paused = True`

Engine change in `_execute_steps`: check `rule.interrupt_paused` before calling `_dismiss_interrupts`. If `rule.interrupt_override` is set, use it instead of `ctx.interrupt_selectors`.

### Declarative Rule Options

```python
@dataclass
class RuleNode:
    options: dict[str, str] = field(default_factory=dict)
    # Keys: on_enter, on_fail, timeout_ms
```

Engine hooks in `_walk_rule`:
- `on_enter=screenshot` → screenshot before steps
- `on_fail=screenshot` → screenshot on guard failure or action error
- `timeout_ms=N` → wrap step execution in a deadline check

## Section 3: Quality Gate Investigations & Test Strategy

### Investigation Protocol

For each failing quality gate:
1. Run the test headed + instrumented
2. Check if the extraction selector still matches the live DOM
3. If selector changed: re-explore with agent-browser, update golden file
4. If extraction works but fill rate is low: check if the site now has empty/missing fields
5. If expansion is failing: check pagination/AJAX timing

### Known Suspects

| Test | Symptom | Likely Cause |
|------|---------|-------------|
| hockey-teams | rating 0% | `.r4a59j5` is a generated class — Scrapy site restyled |
| oscar-films | 6 records | AJAX tab expansion timeout — combo click may need networkidle |
| python-modindex | 85%/81% | Some modules have no description in the source |
| mdn-web-api | description 0% | MDN redesigned detail pages |
| splunk-itsi | body 0% | Splunk docs site restructured |

### Multi-Resource Golden Test

Use `scifi-books-test.robot` as the base pattern (already 2-resource). Verify it exercises the full discovery → detail chain. If insufficient, create a new test against a stable 2-level site.

### Skill Doc Updates for AI Agent

Key additions to `workflow.md` and `SKILL.md`:
1. **Explore checklist**: add "identify async dependencies" and "test dismiss with panels open" as explicit steps
2. **Draft guidance**: decision tree for choosing observation pattern (split rule vs await= vs interleaved)
3. **Guard vs observation**: explain that position determines type, with before/after examples
4. **Keyword hierarchy**: deferred BDD > call_keyword > evaluate_js > browser_step, with when-to-use rationale

### Tutorial Reorganization

Current order is mostly logical. Changes needed:
1. Move section 19 (Browser Adapter Pattern) earlier — it's prerequisite for understanding stealth
2. Add new section: "Browser Control Hierarchy" (the 3-layer stack) after adapter pattern
3. Enhance section 22 (State Setup & Interrupts) with dismiss scoping
4. Ensure section 22b (Observation Gates) references the guard/observation distinction

## Correctness Properties

### Property 1: Guard/Observation Routing
- **Statement**: For any rule, state checks before the first action route to `guards`, state checks after an action route to `steps`.
- **Validates**: Requirement 3.4
- **Test approach**: Parse a robot file with interleaved state checks, inspect the RuleNode.

### Property 2: Stealth Bridge Compatibility
- **Statement**: For any RF keyword using Click, Fill Text, Get Text, Wait For Elements State, the stealth bridge routes calls to the stealth adapter's page.
- **Validates**: Requirement 1.1, 1.2
- **Test approach**: Run `quotes-callkw-test` with WISE_RPA_STEALTH=1, verify >0 records.

### Property 3: Dismiss Scoping Isolation
- **Statement**: When a rule declares `And I pause interrupts`, no dismiss calls occur during that rule's steps.
- **Validates**: Requirement 5.2, 5.3
- **Test approach**: Airbnb test with interrupt pause on interactive rules, verify panels not closed.

### Property 4: Slow Mode Zero Overhead
- **Statement**: When WISE_RPA_SLOW is unset, the slow-motion check adds <1ms per action.
- **Validates**: Requirement 4.3
- **Test approach**: Benchmark quotes-test with and without slow mode env var.
