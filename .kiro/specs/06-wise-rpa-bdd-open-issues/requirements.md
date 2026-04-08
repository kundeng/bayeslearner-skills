# wise-rpa-bdd Open Issues

Discovered during the 2026-04-07/08 development session. Tracked here
so nothing falls through the cracks.

## P1 — Must fix before shipping

### ~~1. E2E test golden baseline drift~~ RESOLVED
All 8 golden baselines agent-vetted via subagents with agent-browser exploration.
Each promoted after dryrun pass. Commits: 35cefea, 1e351eb, 02fac90.

### 2. Interrupt dismiss — no golden test
The `_dismiss_interrupts()` implementation exists but no golden test exercises it.
Best candidate: **Yelp (yelp.com)** — uses OneTrust cookie banner, dismiss via
`#onetrust-accept-btn-handler`. Has scrapable listings/reviews. Alternatives:
theguardian.com, wired.com. Requires Playwright (banners are JS-rendered).

### ~~3. Hook system is log-through only~~ RESOLVED
`_invoke_hooks()` now implements config-driven transforms: rename, drop,
strip_html, default, lowercase, regex. Wired into post_extract lifecycle.
Commit: e8bc6fa.

### 4. AI extraction untested at runtime
Now uses pluggable adapter (aichat → anthropic → openai → cli:<cmd>).
Adapter chain works but live test blocked on local router auth (sk-dummy
rejected by router on port 20128). Need working AI backend to validate.
Adapter code + golden suite (splunk-itsi with AI) are ready. Commit: 2f22bd3.

### ~~5. `generate_from_wise_yaml.py` removed but referenced in memories~~ RESOLVED
Cleaned `.ralph/agent/memories.md`. Stale references removed.

## P2 — Should fix

### 6. Ralph loop reliability
Ralph with Opus hangs on first activation (~10 min with no output) for even
simple single-task specs. Root cause unclear — possibly:
- Extended thinking phase before first tool call
- Context loading overhead with many skills/MCP servers loaded
- Rate limiting on rapid loop restarts

**Workaround:** Do implementation manually, use ralph for well-scoped review tasks.
**Investigation needed:** Check ralph logs for what happens during the hang.

### 7. WiseRpaBDD.py type checker warnings
`self._bl()` returns `object` (from `BuiltIn().get_library_instance()`),
causing ~30 "attribute not found" warnings in the IDE. Not a runtime issue.

**Fix:** Add `# type: ignore` or create a Protocol/stub for the Browser library.

### 8. Multi-parent node execution correctness
The `executed` set in `_walk_rule` prevents duplicate execution of multi-parent
nodes. But the WISE engine waits for ALL parents to complete before running
the child. Current implementation runs the child when the FIRST parent
reaches it (since it's DFS from roots). The `executed` set then prevents
re-execution when the second parent reaches it.

**Impact:** If parent A extracts data that child needs AND parent B extracts
other data child needs, the child only sees parent A's context (whichever
parent runs first). Low severity for current golden baselines.

### ~~9. `open_bound` action not implemented~~ RESOLVED
Implemented: resolves field from context dict or artifact store.
Context now flows through `_execute_actions`. Commit: e8bc6fa.

### 10. Infinite scroll expansion missing
The WISE engine supports `expand.over: infinite` with scroll-based discovery
and stable-count stop conditions. WiseRpaBDD only supports elements, pages_next,
pages_numeric, and combinations.

## P3 — Nice to have

### 11. `text_in_page` state check missing
WISE supports checking if a text string appears anywhere in the page body.
WiseRpaBDD only checks URL patterns and CSS selectors.

### 12. JMESPath query support depends on optional import
`_write_outputs` tries `import jmespath` and silently skips on ImportError.
Should be in pyproject.toml dependencies if we want it to work.

### 13. Main branch / dev branch sync
The dev branch has: pyproject.toml, tests/, AgentRunner.py, .gitignore.
Main has only shippable files. Need a clear workflow for promoting
validated changes from dev → main.

## Completed (for reference)

- [x] Topological sort for node execution (b3ec658)
- [x] Resource dependency ordering (3220451)
- [x] Context inheritance (6d53f38)
- [x] Retry logic (2517161)
- [x] Combination expansion (2517161)
- [x] AI extraction with mode parameter (2517161, 21fdd7e)
- [x] BFS expansion mode (2517161)
- [x] Output format support (2517161)
- [x] Auth/state setup (2517161)
- [x] Interrupt dismiss mechanism (2517161)
- [x] WiseRpaBDD rewritten to use robotframework-browser
- [x] Simplified phases: orient → explore → draft ⇄ review → ship
- [x] References/templates merged (17 files → 5)
- [x] Test structure: golden baselines + AgentRunner E2E
- [x] Ralph-loop skill updated (budgeting, hat configs, reviewer discipline)
