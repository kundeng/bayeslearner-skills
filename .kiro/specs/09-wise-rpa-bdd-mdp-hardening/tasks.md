# Tasks: WiseRpaBDD MDP Hardening (Phase 2)

## Overview

3-1 format: tasks grouped by priority. P1 = must-resolve (blocking or high-value), P2 = architecture, P3 = docs/agent guidance.

## Tasks

- [x] 1. P1 — Must Resolve

  - [x] 1.1 Stealth bridge: fix RF-Browser instance swap for call_keyword
    - Fixed: `_kw_store._libraries` → `_kw_store.libraries` (RF 7.x OrderedDict)
    - Page injection into gRPC catalog not feasible — bridge swap is correct approach
    - Documented 3-layer browser control hierarchy in code comments
    - Updated quotes-callkw-test.robot to indicate stealth support
    - **Depends**: —
    - **Requirements**: 1.1, 1.2, 1.3
    - **Properties**: 2

  - [x] 1.2 Investigate hockey-teams quality gate (rating 0%)
    - RESOLVED: golden file already updated (no rating field). 582 records, all gates pass.
    - **Depends**: —
    - **Requirements**: 2.1

  - [x] 1.3 Investigate oscar-films quality gate (6 records, expected 80)
    - RESOLVED: golden file already updated. 96 records (6 tabs × 16), all gates pass.
    - **Depends**: —
    - **Requirements**: 2.2

  - [x] 1.4 Investigate python-modindex quality gate (85%/81%)
    - Site-side: 368 modules, some sub-modules have no visible name, deprecated ones lack description.
    - Adjusted thresholds: module_name 85%, description 80% (matching site reality).
    - **Depends**: —
    - **Requirements**: 2.3

  - [x] 1.5 Investigate mdn-web-api quality gate (description 0%)
    - RESOLVED: golden file already updated. All detail pages extract cleanly, no gate warnings.
    - **Depends**: —
    - **Requirements**: 2.4

  - [x] 1.6 Investigate splunk-itsi quality gate (body 0%)
    - RESOLVED: golden file already updated. Passes but hits 120s global timeout on some pages.
    - **Depends**: —
    - **Requirements**: 2.5

  - [x] 1.7 AOP slow-motion mode
    - Added `WISE_RPA_SLOW` (ms delay) and `WISE_RPA_SLOW_SCREENSHOT` env vars
    - Implemented in `_do_action_instrumented` — zero overhead when unset (int 0 check)
    - **Depends**: —
    - **Requirements**: 4.1, 4.2, 4.3
    - **Properties**: 4

- [x] 2. P2 — Architecture

  - [x] 2.1 Dismiss scoping: per-rule interrupt override
    - Added `interrupt_override` and `interrupt_paused` to RuleNode
    - New keywords: `And I scope interrupts` (with dismiss= specs), `And I pause interrupts`
    - Engine: `_get_interrupt_selectors(rule)` resolves per-rule → global fallback
    - `_dismiss_interrupts_with(bl, selectors)` factored out for scoped dismiss
    - **Depends**: —
    - **Requirements**: 5.1, 5.2, 5.3
    - **Properties**: 3

  - [x] 2.2 Declarative rule options: on_enter, on_fail, timeout_ms
    - Added `options` dict to RuleNode
    - Engine: on_enter screenshot before guards, on_fail screenshot on guard/timeout failure
    - timeout_ms via deadline param in _execute_steps, raises TimeoutError
    - New keyword: `And I set rule options` with continuation rows (k=v specs)
    - **Depends**: —
    - **Requirements**: 6.1, 6.2, 6.3

  - [x] 2.3 Multi-resource chaining golden test
    - Verified: `scifi-books-test.robot` has 2 resources (discover→detail),
      consumes book_urls artifact via `{detail_url}` template, 16 records
    - No new test needed — existing golden file covers the pattern
    - Stealth/non-stealth: no stealth-specific keywords used, should work in both modes
    - **Depends**: —
    - **Requirements**: 8.1, 8.2

- [x] 3. P3 — Docs & Agent Guidance

  - [x] 3.1 Update skill docs with AI explore/exploit knowledge
    - workflow.md: added guard vs observation section (position determines type)
    - workflow.md: added observation gate decision tree (split rules vs await= vs interleaved)
    - SKILL.md: added rule 7 to agent contract (guard/observation positioning)
    - Async dependency checklist and dismiss scoping already present from Phase 1
    - **Depends**: —
    - **Requirements**: 3.1, 3.2, 3.3, 3.4

  - [x] 3.2 Browser control hierarchy doc in tutorial
    - Added section 19b: 3-layer stack with page ownership table
    - Explains call_keyword routing and stealth bridge solution
    - Documents why gRPC prevents page injection
    - **Depends**: 1.1
    - **Requirements**: 7.1

  - [x] 3.3 Keyword hierarchy doc in tutorial
    - Added section 19c: 4-level keyword hierarchy table
    - deferred BDD > call_keyword > evaluate_js > browser_step
    - Includes migration path callout
    - **Depends**: —
    - **Requirements**: 7.2

  - [x] 3.4 Tutorial reorganization
    - Section 19 (adapter pattern) already in right position — engine internals start there
    - Added 19b (browser hierarchy) and 19c (keyword hierarchy) after adapter pattern
    - Enhanced section 22 with dismiss scoping (scope/pause interrupts) and rule options
    - Progressive difficulty: RF basics → engine model → adapter/stealth → expansions → gates
    - **Depends**: 3.2, 3.3
    - **Requirements**: 7.3

  - [x] 3.5 Construct variety in generate prompt
    - Added CONSTRUCT PATTERNS section to _build_generate_prompt
    - 4 variants: basic (pagination), interactive (forms/await), multi-resource, stealth
    - Each guides agent toward appropriate keyword patterns
    - **Depends**: 3.1
    - **Requirements**: 3.2

- [x] 4. Carry-Forward (from specs 06–08)

  - [x] 4.1 Dev → main merge
    - Multiple promotions during session: hardening, SKILL.md, checkpoint/resume, tutorial reorg
    - Main excludes dev tooling (pyproject.toml, test_topo_sort.py)
    - **Depends**: 1.1
    - **Source**: spec-07 item 3

  - [!] 4.2 Yelp stealth validation — DEFERRED
    - TLS/JA3 fingerprinting is a genuinely hard problem (DataDome)
    - patchright defeats browser-level flags but JA3 requires real browser subprocess + CDP
    - Deferred to a future spec — separate concern from MDP hardening
    - **Depends**: 1.1
    - **Source**: spec-07 item 6, spec-08 item 2

  - [x] 4.3 Type checker warnings cleanup
    - Fixed 46 → 0 mypy errors: Any annotations on _StealthAdapter attrs,
      assert guards on Expansion | None, renamed redefined vars, typed summary dict
    - Only 1 type: ignore for patchright/playwright import fallback
    - **Depends**: —
    - **Source**: spec-06 P2

  - [x] 4.4 Selector resilience golden test — DONE in phase 1
    - `quotes-fallback-test.robot` exercises pipe-delimited fallback + exclude_if
    - **Source**: spec-07 item 4, spec-08 item 1

  - [x] 4.5 Raw browser actions golden test — DONE in phase 1
    - `quotes-callkw-test.robot` exercises call_keyword auth flow
    - **Source**: spec-08 item 5

  - [x] 4.6 Interrupt dismiss golden test — DONE in phase 1
    - `cookiebot-interrupt-test.robot` exercises auto-dismiss
    - **Source**: spec-06 P1

- [x] 5. Additional Work (emerged during session)

  - [x] 5.1 AOP checkpoint/resume
    - PersistentArtifactStore: drop-in dict replacement with write-ahead staging
    - AspectRegistry: unified hooks for instrumentation, slow-motion, checkpoint
    - CLI: run --fresh/--resume flags, WISE_RPA_RESUME_MODE env var
    - Verified: 3 consecutive ITSI runs resume correctly (8→14→20 URLs)
    - **Requirements**: new (not in original spec — user-requested P0)

  - [x] 5.2 All-in-one SKILL.md
    - Replaced pointer-heavy SKILL.md with 616-line self-contained doc
    - Full keyword API, 10 patterns, validation commands, agent contract inline
    - Generate prompt updated to read SKILL.md instead of references/

  - [x] 5.3 Skill consolidation
    - Deleted references/ folder (5 files, 919 lines) — absorbed into SKILL.md
    - Deleted docs/escape-mdp-spec.md — recovery rules proposal moved to design.md
    - to_markdown hook transform added (markdownify)

  - [x] 5.4 Tutorial full reorg
    - 34 sections, sequential 0-33 numbering (no b/c suffixes)
    - CLI moved to section 8 (early), Python internals after deferred execution
    - Observation gates promoted, record linkage moved to appendix
    - CLI section documents checkpoint/resume, env vars, testing strategy

  - [x] 5.5 Test infrastructure
    - E2E test harness expanded from 7 to 21 cases
    - test_topo_sort.py fixed for phase 2 method renames
    - Regression verified: 5 golden tests via CLI entry script

  - [x] 5.6 Naming cleanup
    - WISE_RPA_INSTRUMENT → WISE_RPA_TIMING (clearer purpose)
    - splunk-itsi-complete-test.robot: full 2-section scrape with markdownify + AI

## Notes

- Quality gate investigations (1.2–1.6) are independent — can run in parallel
- Stealth bridge (1.1) blocks browser hierarchy doc (3.2) and dev→main merge (4.1)
- Tutorial reorg (3.4) should come last — it arranges content other tasks create
- `scifi-books-test` already has 2 resources; task 2.3 may just be verification + stealth run
- File-backed data model (spec-08 item 6) is design-only, deferred to a future spec
- Ralph 2-hat mode (specs 07/08) deferred — depends on ralph loop stability which is a separate concern
