---
name: ralph-deploy
description: Plan and configure ralph-orchestrator deployments for projects at any stage — from a vague phase plan to a mature codebase. Use this skill whenever the user wants to set up ralph for a new project, choose between deployment topologies (direct, Claude+MCP, multi-project supervisor), pick the right config for their project's maturity, run oneshot autonomous builds, or manage multiple concurrent ralph loops across tmux sessions. Also use when the user asks "how should I run ralph on this?", mentions phase plans, or wants to configure cost budgets, hat workflows, or guardrails for a specific project type.
---

# Ralph Deploy

Configure and launch ralph-orchestrator. Install: `cargo install --git https://github.com/mikeyobrien/ralph-orchestrator ralph-cli`

## Before You Start

```bash
ralph loops list                    # existing loops?
tmux has-session -t ralph-$NAME 2>/dev/null && echo "running"
ls .ralph/loop.lock 2>/dev/null     # stale lock?
```

If running: monitor, don't start another. If stale lock with no session: `rm .ralph/loop.lock`.

## Hats = Roles in the Loop

Hats rotate per iteration via events. The recommended greenfield pattern:

```
work.start → [planner] → plan.ready → [builder] → build.done → [reviewer]
                ↑                         ↑                          │
                │                         └── work.resume ───────────┤ (code bug)
                └──────── replan ────────────────────────────────────┘ (plan wrong)
                                                                     │
                                                        LOOP_COMPLETE (verified)
```

**Reviewer failure paths:**
- `work.resume → builder`: code bug — say what's wrong, how to fix
- `replan → planner`: plan wrong — say what's infeasible, why
- `plan.ready → builder`: task passes, do next one
- `LOOP_COMPLETE`: all tasks verified

### Dynamic Handoff Between Hats

Hat instructions and PROMPT.md are static per loop. Hats communicate dynamically via:

1. **Scratchpad** (`.ralph/agent/scratchpad.md`) — planner writes task breakdown + acceptance criteria, builder/reviewer read and update it. This is the key handoff channel.
2. **Task list** — ralph injects task status (ready/open/closed) each iteration.
3. **Memories** (`.ralph/agent/memories.md`) — persistent notes across iterations. Keep budget low (2000 tokens). All hats should read memories at the start of each iteration and write to them when they discover non-obvious constraints (version gotchas, dependency issues, config traps). This prevents future iterations from hitting the same problems.
4. **Event payloads** — text in `build.done`, `work.resume` etc.

### Acceptance Criteria Pattern

The planner writes per-task criteria in the scratchpad. The reviewer verifies by running them — not just pytest.

```markdown
## Task: REST API
**Accept when:**
- `uv run simdata run sim.sim scene.json --port 8080 &` starts
- `curl localhost:8080/tree` returns JSON with entity names
- `curl -X POST localhost:8080/command -d '{...}'` returns 200
```

### Artifact Registry Pattern

The planner creates a verification dashboard in the scratchpad:

```markdown
| Artifact | Exists | Tests | Runtime Verified | Acceptance Criteria |
|----------|--------|-------|-----------------|---------------------|
| CLI hello | yes | unit | YES | ran hello, got KV output |
| REST /tree | yes | mocked | NO | never curled |
```

## Topology Selection

```
Single project, user watching         → A (direct tmux)
Single project, autonomous oneshot    → B (agent + CLI/MCP)
Multiple projects, coordinated        → C (multi-tmux)
```

## Tmux Setup (all topologies)

```bash
tmux new-session -d -s "$NAME" -c "$PROJECT_PATH"
tmux send-keys -t "$NAME:0" "ralph run -q -c ralph.yml -H hats/greenfield.yml 2>&1 | tee .ralph/run.log" Enter
tmux split-window -h -t "$NAME:0" -c "$PROJECT_PATH"
tmux send-keys -t "$NAME:0.1" "bash .ralph/monitor.sh" Enter  # dashboard pane
tmux split-window -v -t "$NAME:0.0" -c "$PROJECT_PATH"        # steering pane
```

**Monitor dashboard** (`.ralph/monitor.sh`): Loop showing `ralph loops list`, `ralph events --last 5`, recent iterations, files written, git log. Refresh every 15s.

**MCP server** (optional, for Topology B): `claude mcp add -s user "ralph-$NAME" -- ralph mcp serve --workspace-root "$PROJECT_PATH"`. Note: schemas are large (~2.4MB), may not load in Claude Code. CLI commands are functionally equivalent.

**Set up a polling timer** when orchestrating: `CronCreate` every 3 minutes to check `ralph events --last 5`, `grep ITERATION .ralph/run.log | tail -3`, `git log --oneline -3`. Auto-cancel when loop terminates.

## CLI Reference

| Action | Command |
|--------|---------|
| Loop status | `ralph loops list` |
| Event history | `ralph events --last 10` |
| View plan | `cat .ralph/agent/scratchpad.md` |
| Stop gracefully | `touch .ralph/stop-requested` |
| Resume | `ralph run --continue` |
| Steer | `ralph wave emit human.guidance --payloads "msg"` |
| Validate | `ralph preflight` |
| Dry run | `ralph run --dry-run -c ralph.yml -H hats/...` |
| View diff | `ralph loops diff <id> --stat` |
| Follow logs | `ralph loops logs <id> -f` |
| Clean state | `ralph clean` |

## Writing the Spec (PROMPT.md)

PROMPT.md is a comprehensive spec, not a vague goal. Include:

1. **Code deliverables** — what to implement, which files, what behavior
2. **Infrastructure tasks** — what the builder must start/configure (Docker, servers) to verify its own work. Infrastructure is a task, not an assumption.
3. **Handoff artifacts** — README, getting started guide, deployment docs, changelog, demo. These are deliverables with acceptance criteria.
4. **Verification requirements** — what "done" means in runnable terms

### What the Planner Must Do

1. **Research first** — read existing code, understand what's built/broken. Don't plan from PROMPT.md alone.
2. **Write artifact registry** in scratchpad — every deliverable with verification status
3. **Write acceptance criteria** per task — concrete, runnable commands
4. **Include infrastructure setup** as tasks when verification requires Docker, servers, etc.
5. **Include handoff artifacts** as tasks with acceptance criteria
6. **Sequence by dependency** — don't schedule E2E tests before features work

### Testing Strategy

The builder writes tests alongside code. The *type* depends on what's being built:

- **Code specs**: unit + integration tests. Builder also runs the system to verify.
- **Integration specs**: planner includes infra setup tasks. Builder starts services, tests real connections. Mocks insufficient.
- **Verification specs**: runtime verification of existing artifacts. Builder fixes broken things. Reviewer verifies end-to-end.
- **Handoff specs**: planner lists every doc. Builder creates them. Reviewer follows from scratch.

## Per-Hat Backend Routing

| Hat | Recommended | Why |
|-----|-------------|-----|
| Planner | `claude --model opus` | Deep reasoning for architecture, acceptance criteria |
| Builder | `claude --model sonnet` | Fast, reliable commits, follows instructions |
| Reviewer | `claude --model sonnet` | Verification, diagnosis |

Codex can be used for builder but may not commit reliably.

## Greenfield Hat Config

See `hats/greenfield.yml` in any project configured with this skill. Key fields per hat: `backend`, `backend_args`, `triggers`, `publishes`, `default_publishes`, `max_activations`, `instructions`.

Critical rules:
- **Reserved triggers**: `task.*` names reserved by ralph. Use `work.start`, `build.done`, etc.
- **No self-triggering**: reviewer must NEVER emit `build.done`. Set `default_publishes: plan.ready`, `max_activations: 1`.
- **Reviewer must diagnose failures**: capture error, write findings in scratchpad, emit `work.resume` (code bug) or `replan` (plan wrong).

## Operational Discipline

- **Minimize loop restarts** — each costs a planner re-analysis. Supply all tasks in one PROMPT.md.
- **Don't ask human questions unless blocked** — resolve from specs, code, patterns.
- **Update PROJECT_PLAN.md** after each spec completes.
- **TUI needs real TTY** — use `-q` mode in tmux. Monitor via dashboard script.
- **Handoff artifacts are deliverables** — README, docs, demo are tasks with acceptance criteria, not afterthoughts.
