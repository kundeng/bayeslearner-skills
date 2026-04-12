# Spec 10: Yelp Stealth Mode — DONE

## Result

Yelp scraping works end-to-end via the nodriver adapter. Tested 3 queries
(restaurants SF, coffee Boston, dentists Chicago) — all pass with 14-15 records.

## Root Cause

DataDome detects **Playwright's JavaScript runtime** injected into pages,
not TLS fingerprints or IP reputation. All Playwright-based approaches
(patchright, Camoufox, CDP+Playwright) failed because the Playwright
protocol layer was detectable.

Additionally, `Library Browser` in `.robot` files starts Playwright's
Node.js server process, which DataDome detects even when the engine uses
a non-Playwright adapter. The yelp test must NOT import Library Browser.

## Solution: Dual Browser Engine

| Engine | When | Speed | Anti-bot |
|--------|------|-------|----------|
| `_PlaywrightAdapter` | `WISE_RPA_STEALTH=0` | Fast (batch CDP) | None |
| `_NodriverAdapter` | `WISE_RPA_STEALTH=1` (default) | ~50% slower | Defeats DataDome |

Both implement `_BrowserAdapter` base class — clean polymorphism, no
mode-branching. The engine calls `_make_adapter(stealth=True/False)`.

### Nodriver specifics

- Raw CDP to real Edge/Chrome, zero Playwright artifacts
- Async internally, sync bridge via dedicated event loop thread
- Homepage warmup on first visit to each origin (DataDome flags direct deep links)
- Playwright `>>` selector syntax translated to CSS + nth indexing
- `evaluate()` results unwrapped from CDP RemoteObject format
- Arrow functions auto-wrapped as IIFE (nodriver doesn't auto-invoke)
- Robot files using nodriver should import only `Library WiseRpaBDD`, not `Library Browser`

## Test Results

- **28/28 golden tests pass** with nodriver (full suite)
- **28/28 golden tests pass** with Playwright (full suite)
- **Yelp**: 14 records, 3 different queries, zero CAPTCHA

## Files Changed

| File | Change |
|------|--------|
| `scripts/WiseRpaBDD.py` | `_BrowserAdapter` base + `_PlaywrightAdapter` + `_NodriverAdapter` |
| `tests/golden/yelp-stealth-test.robot` | New test, `Library WiseRpaBDD` only |
| `SKILL.md` | Updated capabilities description |
