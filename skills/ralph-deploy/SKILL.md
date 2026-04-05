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

**Monitoring options**:
- **`.ralph/monitor.sh`** — copy from `scripts/monitor.sh` in this skill. Dashboard showing active task (from scratchpad), events, uncommitted changes, commits, memory count. Detects claude/codex/aichat for AI-summarized status. Best for VS Code terminal panes.
- **`ralph tui`** — built-in terminal UI. Only works with a real TTY (attach directly: `tmux attach -t $NAME`). Does NOT work when launched via `tmux send-keys`.
- **`ralph web`** — exists but is internal/incomplete. Only works from the ralph source tree, not from user projects. Do not rely on it.

The active task (from scratchpad) and uncommitted changes are the most useful signals for humans — they answer "what is it doing right now?"

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

### What the Planner Does

1. **Research first** — read existing code, understand what's built/broken. Don't plan from PROMPT.md alone.
2. **Write artifact registry** in scratchpad — every deliverable with verification status
3. **Write acceptance criteria** per task — concrete, runnable commands
4. **Include infrastructure setup** as tasks when verification requires Docker, servers, etc.
5. **Include handoff artifacts** as tasks with acceptance criteria
6. **Sequence by dependency** — don't schedule E2E tests before features work

### What the Builder Does

The builder's job is broader than writing code. It executes whatever the planner's task requires:

- **Write code** — implement features, fix bugs, refactor
- **Write tests** — unit, integration, or E2E depending on the task. Use mocks for unit tests but real connections for integration.
- **Set up infrastructure** — `docker compose up`, start dev servers, install dependencies, configure services. If verification requires a running system, the builder starts it.
- **Create documentation** — README, getting started guide, API reference, architecture docs. These are build tasks, not afterthoughts.
- **Create project artifacts** — project website, demo scripts, sample configs, changelog
- **Verify own work** — run the acceptance criteria before committing. If the criterion says "curl this endpoint", actually curl it.
- **Write to memories** — when discovering non-obvious constraints (version gotchas, dependency issues), persist them for future iterations.

### What the Reviewer Does

The reviewer's job is broader than running pytest. It verifies against the planner's acceptance criteria:

- **Run the acceptance criteria** — if it says "run this command", run it. If it says "curl this endpoint", start the server and curl it. If it says "follow this doc", follow it from scratch.
- **Run the test suite** — as a baseline, but not the only check.
- **Check code quality** — lint, type checks, style consistency, security concerns.
- **Diagnose failures** — capture actual errors, read the code, identify root causes. Write findings to scratchpad and memories.
- **Verify handoff artifacts** — follow the README as a new user. Do the commands work? Is anything missing?
- **Decide the right escalation** — code bug → `work.resume` to builder. Plan wrong → `replan` to planner. All done → `LOOP_COMPLETE`.

### Adapting for Complex Projects

The greenfield config below works for most projects. For more complex projects, adapt it:

- **Add hats** — a `researcher` hat that investigates before the planner plans, a `devops` hat that handles infrastructure, a `writer` hat for docs.
- **Add events** — `research.done`, `infra.ready`, `docs.done` to create more specific handoffs.
- **Split the builder** — one builder for backend, another for frontend, with different backends or instructions.
- **Adjust max_activations** — higher for the planner if replans are expected, keep reviewer at 1.

Use `ralph hats validate` and `ralph hats graph` to verify event topology before launching.

## Per-Hat Backend Routing

| Hat | Recommended | Why |
|-----|-------------|-----|
| Planner | `claude --model opus` | Deep reasoning for architecture, acceptance criteria |
| Builder | `claude --model sonnet` | Fast, reliable commits, follows instructions |
| Reviewer | `claude --model sonnet` | Verification, diagnosis |

Codex can be used for builder but may not commit reliably.

## Greenfield Hat Config

```yaml
event_loop:
  starting_event: "work.start"
  completion_promise: "LOOP_COMPLETE"

hats:
  planner:
    name: "Architect"
    description: "Reads specs, breaks work into tasks with acceptance criteria"
    backend: claude
    backend_args: ["--model", "opus"]
    triggers: ["work.start", "phase.next", "replan"]
    publishes: ["plan.ready", "scaffold.done"]
    default_publishes: "plan.ready"
    max_activations: 8
    instructions: |
      Research first: read code, PROMPT.md, CLAUDE.md, scratchpad, memories.
      Write artifact registry + acceptance criteria per task in scratchpad.
      Include infrastructure setup and handoff artifact tasks.

  builder:
    name: "Builder"
    description: "Implements tasks and verifies against acceptance criteria"
    backend: claude
    backend_args: ["--model", "sonnet"]
    triggers: ["plan.ready", "work.resume"]
    publishes: ["build.done", "tests.passing"]
    default_publishes: "build.done"
    instructions: |
      Read scratchpad for task + criteria. Read memories for constraints.
      Implement, test, verify criteria yourself before committing.
      Write to memories when you discover non-obvious constraints.

  reviewer:
    name: "Reviewer"
    description: "Verifies implementation and diagnoses failures"
    backend: claude
    backend_args: ["--model", "sonnet"]
    triggers: ["build.done"]
    publishes: ["LOOP_COMPLETE", "work.resume", "plan.ready", "replan"]
    default_publishes: "plan.ready"
    max_activations: 1
    instructions: |
      Read scratchpad for criteria. Read memories. Verify by running
      what criteria specify. On failure: capture error, diagnose,
      write to scratchpad + memories, emit work.resume or replan.
      On pass: mark verified, emit plan.ready or LOOP_COMPLETE.
      NEVER emit build.done.
```

Critical rules:
- **Reserved triggers**: `task.*` names reserved by ralph. Use `work.start`, `build.done`, etc.
- **No self-triggering**: reviewer must NEVER emit `build.done`. Set `default_publishes: plan.ready`, `max_activations: 1`.
- **Reviewer diagnoses failures**: capture error, write findings in scratchpad + memories, emit `work.resume` (code bug) or `replan` (plan wrong).
- **All hats read/write memories**: discovered constraints persist across iterations.

## Operational Discipline

- **Minimize loop restarts** — each costs a planner re-analysis. Supply all tasks in one PROMPT.md.
- **Don't ask human questions unless blocked** — resolve from specs, code, patterns.
- **Update PROJECT_PLAN.md** after each spec completes.
- **TUI needs real TTY** — use `-q` mode in tmux. Monitor via dashboard script.
- **Handoff artifacts are deliverables** — README, docs, demo are tasks with acceptance criteria, not afterthoughts.
