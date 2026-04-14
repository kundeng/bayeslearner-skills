# E3 CLI Reorg

## Context

WiseRpaBDD CLI had 4 flat commands (run/dryrun/validate/generate) — all Exploit-phase. SKILL.md documented `/rrpa-*` phases never wired. Needed: map CLI to E3 (Endow → Explore → Exploit) with standard naming and guided getting-started flow for new users.

## Constraints

- Single file: `scripts/WiseRpaBDD.py` — CLI lives at the bottom
- Seed template must NOT include `Library Browser` (DataDome detects Node.js process)
- `generate` is Explore-phase — agent decides URLs, not the user
- Must pass all 29 golden tests under `check`

## Decisions

### D1: 5 commands, not 7
**Choice:** Merge dryrun+validate → `check`. Drop standalone `explore`.
**Why:** dryrun and validate always run together. Explore is not a standalone step — the agent explores as part of `generate`.

### D2: generate takes project dir, not -o path
**Choice:** `generate <project/>` reads `requirement.md` from the project dir.
**Why:** Decouples init from generation. User can edit requirement between steps. Agent writes `suite.robot` into the project.

### D3: No Library Browser in seed
**Choice:** Seed template only includes `Library WiseRpaBDD`.
**Why:** `Library Browser` starts Playwright's Node.js server — detected by DataDome. Only 1/29 golden tests needs it (raw passthrough keywords). Agent adds it during `generate` only when needed.

### D4: BDD linter tolerates structural keywords
**Choice:** `I define rule "..."` whitelisted. `*** Keywords ***` section skipped entirely.
**Why:** Rule definitions are framework keywords, not BDD steps. User-defined keywords contain raw RF calls by design.

## Tasks

### P1 — Must Do
- [x] 1.1 Add `_cli_doctor()` — env checks with `Fix:` hints, try/except for npx
- [x] 1.2 Add `_cli_init()` — scaffold project + store requirement.md
- [x] 1.3 Restructure `generate` — takes project dir, reads requirement.md, `-r` override
- [x] 1.4 Merge dryrun+validate into `_cli_check()` — lint gates dryrun
- [x] 1.5 Update `main()` — guided getting-started, `--help` interception on all commands
- [x] 1.6 Fix BDD linter: structural prefixes, continuation indent, skip Keywords section
- [x] 1.7 Update SKILL.md phase table to E3 mapping
- [x] 1.8 Remove `Library Browser` from seed template

### P2 — Should Do
- [x] 2.1 Fix `check --help` / `run --help` leaking robot's 250-line help
- [x] 2.2 Fix `run` no-args showing robot error instead of our usage
- [x] 2.3 Fix `doctor` crash when npm/npx not installed (FileNotFoundError)
- [x] 2.4 Fix `init` hint not quoting paths with spaces

### P3 — Nice to Have
- [ ] 3.1 Move `spec-10-yelp-stealth.md` from `skills/wise-rpa-bdd/` to `.kiro/specs/`

## Open Questions

- [x] Should `explore` be a standalone command? → No, merged into `generate` (D1)
- [x] Should `create` or `generate` be the primary name? → `generate`, `create` as alias

## Log

**2026-04-13** — Implemented full E3 CLI reorg. 5 commands: doctor, init, generate, check, run. Red/green tested all commands — found and fixed: --help leaking robot help, no-args errors, npx crash, BDD linter false positives (continuation lines, rule definitions, Keywords section). 29/29 golden tests pass `check`. Agent successfully generated a quotes suite via `generate`.
