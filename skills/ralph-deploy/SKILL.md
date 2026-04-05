---
name: ralph-deploy
description: Plan and configure ralph-orchestrator deployments for projects at any stage — from a vague phase plan to a mature codebase. Use this skill whenever the user wants to set up ralph for a new project, choose between deployment topologies (direct, Claude+MCP, multi-project supervisor), pick the right config for their project's maturity, run oneshot autonomous builds, or manage multiple concurrent ralph loops across tmux sessions. Also use when the user asks "how should I run ralph on this?", mentions phase plans, or wants to configure cost budgets, hat workflows, or guardrails for a specific project type.
---

# Ralph Deploy

Configure and launch ralph-orchestrator for a project. Covers topology selection, config generation, and tmux session management.

Ralph supports multiple agent backends (`claude`, `codex`, `kiro`, `gemini`, `amp`, `copilot`, `opencode`, `pi`, `custom`). Ask which backend the user runs and set `cli.backend` accordingly.

## Install

```bash
cargo install --git https://github.com/mikeyobrien/ralph-orchestrator ralph-cli
```

Verify: `ralph --version`.

---

## Before You Start: Check for Existing Loops

Always check before creating a new loop:

```bash
ralph loops list                    # any running loops?
tmux has-session -t ralph-$NAME 2>/dev/null && echo "running"
ls .ralph/loop.lock 2>/dev/null     # stale lock?
```

If a loop exists:
- **Still running**: Monitor it — don't start another. Use `ralph events --last 5` and read `.ralph/agent/scratchpad.md`.
- **Finished**: Review results, update PROJECT_PLAN.md, then start next phase.
- **Stale lock, no tmux session**: `rm .ralph/loop.lock` then proceed.

---

## What Are Hats?

Hats are **roles that ralph rotates through** during a loop. Each iteration, ralph picks one hat based on which event was last emitted, runs the agent with that hat's instructions, and expects the agent to emit a new event that triggers the next hat.

Think of it as a state machine: `planner → builder → reviewer → planner → ...`

Each hat has:
- **triggers**: which events activate this hat (e.g. `["work.start", "phase.next"]`)
- **publishes**: which events this hat is allowed to emit (e.g. `["plan.ready", "scaffold.done"]`)
- **default_publishes**: what event to emit if the agent doesn't explicitly emit one
- **instructions**: the role's prompt — what this hat should do
- **max_activations**: safety cap on consecutive activations (prevents infinite loops)

The event flow for a typical greenfield build:

```
work.start → [planner] → plan.ready → [builder] → build.done → [reviewer]
                ↑                         ↑                          │
                │                         └── work.resume ───────────┤ (code bug)
                └──────── replan ────────────────────────────────────┘ (plan wrong)
                                                                     │
                                                        LOOP_COMPLETE (verified)
```

The reviewer has three failure paths:
- **work.resume → builder**: implementation bug — code is wrong, tests missing, wrong output. Include the specific error and what to fix.
- **replan → planner**: plan is wrong — task is infeasible, missing dependency, wrong approach, acceptance criteria are impossible. The planner re-scopes and emits a new `plan.ready`.
- **plan.ready → builder**: this task passes, move to the next one.
- **LOOP_COMPLETE**: all tasks verified against acceptance criteria.

### How Information Flows Between Hats

Hat instructions and PROMPT.md are **static** — they don't change during a loop run. But hats communicate dynamically through:

1. **Scratchpad** (`.ralph/agent/scratchpad.md`) — the planner writes the task breakdown and acceptance criteria here. The builder and reviewer read it each iteration. Any hat can update it.
2. **Task list** — ralph injects the current task status (ready/open/closed) into each iteration's prompt automatically.
3. **Memories** (`.ralph/agent/memories.md`) — persistent notes that survive across iterations.
4. **Event payloads** — the text in `build.done`, `work.resume`, etc. carries context to the next hat.

The **scratchpad is the key handoff channel**. The planner must write concrete acceptance criteria there so the reviewer knows how to verify — not just "run pytest" but "run this command, curl this endpoint, check this file."

### Acceptance Criteria Pattern

The planner should write acceptance criteria per task in the scratchpad:

```markdown
## Task: REST API endpoint
**Accept when:**
- `uv run simdata hello.simulation hello.json --port 8080 &` starts without error
- `curl http://localhost:8080/tree` returns JSON with entity names
- `curl -X POST http://localhost:8080/command -d '{"entity":"Greeter","variable":"rate","value":5}'` returns 200
```

The builder verifies these before committing. The reviewer verifies them again independently. This catches the gap where unit tests pass but the system doesn't actually work end-to-end.

**Do NOT hardcode verification methods in hat instructions** (e.g. "run pytest, mypy, ruff"). Instead instruct hats to read the scratchpad for what to verify. Different tasks need different verification — a CLI tool needs to be run, an API needs to be curled, a config file needs to be parsed.

---

## Topology Selection

**A — Direct**: Ralph runs in a tmux session. Best for single-project focused work. You monitor and steer from the shell.

**B — Agent+MCP**: An agent (Claude Code, Codex, etc.) orchestrates ralph via MCP or CLI while ralph executes in a separate tmux session. Best for autonomous oneshot builds from a plan.

**C — Multi-Project Supervisor**: One agent manages multiple ralph instances across tmux sessions. Best for 3+ concurrent projects.

```
Single project, user watching         → A
Single project, autonomous oneshot    → B
Multiple projects, coordinated        → C
```

---

## Topology A Setup (Human-Operated)

Three-pane tmux layout: run | monitor | steering.

**Important**: The TUI (`ralph tui`) requires a real TTY. When scripting tmux, use `-q` mode.

```bash
tmux new-session -d -s "$NAME" -c "$PROJECT_PATH"
tmux send-keys -t "$NAME:0" "ralph run -q -c ralph.yml -H hats/workflow.yml 2>&1 | tee .ralph/run.log" Enter
tmux split-window -h -t "$NAME:0" -c "$PROJECT_PATH"
tmux split-window -v -t "$NAME:0.0" -c "$PROJECT_PATH"
```

**Pane 1 — Monitor dashboard**: Create `.ralph/monitor.sh`:

```bash
#!/bin/bash
while true; do
  clear
  printf "═══ RALPH MONITOR ═══\n\n"
  ralph loops list 2>/dev/null | grep -E "primary|running|done"
  printf "\n── Recent Events ──\n"
  ralph events --last 5 2>/dev/null | tail -8
  printf "\n── Iterations ──\n"
  grep "ITERATION" .ralph/run.log 2>/dev/null | tail -3
  printf "\n── Files Built ──\n"
  grep '"name":"Write"' .ralph/run.log 2>/dev/null | grep -oE '"file_path":"[^"]*"' | grep -v tmp | grep -v scratchpad | sed 's/"file_path":"//;s/"//' | xargs -I{} basename {} 2>/dev/null | sort -u | tail -10
  printf "\n── Git ──\n"
  git log --oneline -3 2>/dev/null
  printf "\n[%s] refreshing in 15s\n" "$(date +%H:%M:%S)"
  sleep 15
done
```

Launch: `tmux send-keys -t "$NAME:0.1" "bash .ralph/monitor.sh" Enter`

**Pane 2 — Steering console**: Print a command reference:

```
╔═══════════════════════════════════════════╗
║         RALPH STEERING CONSOLE            ║
╠═══════════════════════════════════════════╣
║                                           ║
║  Steer:                                   ║
║    ralph wave emit human.guidance \        ║
║      --payloads "focus on X first"        ║
║                                           ║
║  Stop gracefully:                         ║
║    touch .ralph/stop-requested            ║
║                                           ║
║  Resume after stop:                       ║
║    ralph run --continue                   ║
║                                           ║
║  Inspect:                                 ║
║    ralph events --last 10                 ║
║    ralph loops list                       ║
║    cat .ralph/agent/scratchpad.md         ║
║                                           ║
║  Diagnostics:                             ║
║    ralph loops logs <id> -f               ║
║    ralph loops history <id>               ║
║    ralph loops diff <id> --stat           ║
║                                           ║
╚═══════════════════════════════════════════╝
```

## Topology B Setup (Agent-Orchestrated)

1. Register MCP server with Claude Code (do NOT edit config files directly):
   ```bash
   claude mcp add -s user "ralph-$NAME" -- ralph mcp serve --workspace-root "$PROJECT_PATH"
   ```
   **Note**: The MCP server's tool schemas are large (~2.4MB). If tools don't load in Claude Code, use the CLI commands below instead — they are functionally equivalent.

2. Start the loop in tmux with the same 3-pane layout as Topology A.

3. Monitor and steer via CLI (preferred) or MCP tools:

   | Action | CLI command | MCP tool |
   |--------|-------------|----------|
   | Loop status | `ralph loops list` | `loop.status` |
   | Event history | `ralph events --last 10` | `stream.subscribe` |
   | View plan | `cat .ralph/agent/scratchpad.md` | `planning.get` |
   | Stop loop | `touch .ralph/stop-requested` | `loop.stop` |
   | Create task | write to PROMPT.md | `task.create` |
   | View config | `ralph run --dry-run -c ralph.yml -H hats/...` | `config.get` |
   | View diff | `ralph loops diff <id> --stat` | — |
   | View logs | `ralph loops logs <id> -f` | — |

4. Between phases: update PROMPT.md, `ralph clean`, then start a new `ralph run`.

## Topology C Setup

Same as B, but with one tmux session + MCP server per project. The supervisor agent polls all via `ralph loops list` or `loop.status` on each MCP server.

---

## Oneshot Pattern (autonomous build from plan)

For a human who wants to run a project autonomously from a plan:

1. **Write the plan** — put the full project plan in `specs/plan.md` or `PROJECT_PLAN.md`. Include phase goals, done-when criteria, and task dependencies. The more detail, the better — ralph's planner will break it down further.

2. **Write the prompt** — create `PROMPT.md` as a comprehensive spec. This is NOT just "build phase 3." It must include:
   - **Code deliverables**: what to implement, which files, what behavior
   - **Infrastructure tasks**: what the builder needs to start/configure (Docker, dev servers, databases) to verify its own work
   - **Handoff artifacts**: README, getting started guide, deployment docs, changelog, demo — anything a human needs to use the project
   - **Verification requirements**: what "done" means for each deliverable in concrete, runnable terms

   You can supply the whole plan and let the planner break it down, or break it into specs yourself and run one loop per spec.

3. **Configure** — create `ralph.yml` (core config) and `hats/greenfield.yml` (hat roles). See Stage Configs below.

4. **Validate** — `ralph preflight` (use `--strict` for CI, plain for dev).

5. **Launch** — start the 3-pane tmux session as described in Topology A.

6. **Wait** — the loop runs autonomously. Monitor via the dashboard pane. The loop terminates when it emits `LOOP_COMPLETE` or gets stale-detected (both mean the work is done).

7. **Review and continue** — when the loop stops:
   ```bash
   uv run pytest tests/           # verify tests
   git log --oneline -10           # review commits
   git push                        # push to remote
   ```
   Update PROJECT_PLAN.md checkboxes, write a new PROMPT.md for the next spec, `ralph clean`, and launch again.

For agent-orchestrated oneshots (Topology B), the agent does steps 6-7 automatically and chains specs without human intervention.

### What the Planner Must Do

The planner's job is not just "break work into tasks." It must:

1. **Research first**: read existing code, understand what's built, identify gaps
2. **Write an artifact registry** in the scratchpad — a table of every deliverable, its current status (missing / exists / unit tested / runtime verified), and what verification means
3. **Write acceptance criteria per task** — concrete, runnable commands and expected outputs
4. **Include infrastructure setup tasks** — if verifying the REST API requires a running server, the builder must start one. If verifying Splunk integration requires Docker, the builder must `docker compose up`. These are tasks, not assumptions.
5. **Include handoff artifacts** — README, getting started guide, deployment docs. These are deliverables with acceptance criteria too (e.g. "follow the README from scratch, every command works")
6. **Sequence by dependency** — don't schedule E2E tests before the features they test are verified working

### Artifact Registry Pattern

The planner should create this in the scratchpad. The reviewer updates it as tasks are verified:

```markdown
## Artifact Verification Status
| Artifact | Exists | Tests | Runtime Verified | Acceptance Criteria |
|----------|--------|-------|-----------------|---------------------|
| CLI: simdata <sim> <scene> | yes | unit | NO | run hello, see KV output |
| REST: GET /tree | yes | mocked | NO | start server, curl, get JSON |
| README | yes | n/a | NO | follow from scratch, all commands work |
| Docker compose | yes | n/a | NO | docker compose up, Splunk accessible |
```

This gives humans (and the orchestrating agent) a confidence dashboard. "Runtime Verified = NO" means the artifact is scaffolded but unproven.

### Testing Strategy Across Specs

The builder writes tests alongside implementation — but the *type* of test depends on what's being built. The planner schedules the right tests:

**Code specs (core engine, libraries, APIs):** Unit tests and integration tests. The builder writes these for every task. The builder also runs the actual system to verify — not just pytest.

**Integration specs (UI + backend, Splunk + HEC):** The planner must include infrastructure setup tasks. The builder starts services, connects components, writes integration tests that exercise real connections. Mocked tests are insufficient at this stage.

**Verification specs (fix-and-verify, pre-release):** Focus on runtime verification of existing artifacts. The planner writes acceptance criteria that require actually using the system. The builder fixes what's broken. The reviewer verifies every artifact end-to-end.

**Handoff specs (docs, demo, release):** The planner lists every handoff artifact. The builder creates them. The reviewer follows the docs from scratch to verify they work.

---

## Per-Hat Backend Routing

Each hat can use a different agent backend via the `backend` and `backend_args` fields. This lets you burn cheaper/faster quotas on high-volume roles while reserving expensive models for orchestration.

**Recommended split:**

| Hat | Backend | Why |
|-----|---------|-----|
| Planner | `claude` + `["--model", "opus"]` | Architecture decisions, acceptance criteria, and dependency ordering need deep reasoning |
| Builder | `claude` + `["--model", "sonnet"]` | Fast code generation, follows instructions reliably, commits consistently |
| Reviewer | `claude` + `["--model", "sonnet"]` | Verification, diagnosis, scratchpad updates |

```yaml
hats:
  planner:
    backend: claude
    backend_args: ["--model", "opus"]
    ...
  builder:
    backend: claude
    backend_args: ["--model", "sonnet"]
    ...
  reviewer:
    backend: claude
    backend_args: ["--model", "sonnet"]
    ...
```

The orchestrating agent (Opus) pays for the meta-layer — monitoring, spec transitions, steering. The loop runs on Opus (planner, once) + Sonnet (builder + reviewer, many times).

Ask the user which backends and quotas they have available. Other combinations:
- **Codex builder**: `backend: codex` on builder — faster iteration but may not commit reliably or follow guardrails as well as Sonnet
- **All Sonnet**: cheap default, works well for most projects
- **All Opus**: when quality matters more than cost (small critical projects)

---

## Stage Configs

### Greenfield (phase plan, no code)

Core config (`ralph.yml`):

```yaml
cli:
  backend: claude

core:
  specs_dir: ./specs
  scratchpad: .ralph/agent/scratchpad.md
  guardrails:
    - "Read the spec before writing any code"
    - "Create directory structure before implementing"
    - "Write tests alongside implementation"
    - "Commit after each logical unit of work"

event_loop:
  max_iterations: 50
  max_runtime_seconds: 7200
  completion_promise: "LOOP_COMPLETE"
  required_events:
    - "scaffold.done"
    - "tests.passing"

memories:
  enabled: true
  inject: auto
  budget: 2000

tasks:
  enabled: true
```

Hat collection (`hats/greenfield.yml`):

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
      Read PROMPT.md and the scratchpad. Break work into tasks.
      For EACH task, write acceptance criteria in the scratchpad:
      what command to run, what output to expect, what to curl, etc.
      The reviewer will verify against these — make them concrete.

  builder:
    name: "Builder"
    description: "Implements tasks and verifies against acceptance criteria"
    backend: claude
    backend_args: ["--model", "sonnet"]
    triggers: ["plan.ready", "work.resume"]
    publishes: ["build.done", "tests.passing"]
    default_publishes: "build.done"
    instructions: |
      Read the scratchpad for the current task and its acceptance criteria.
      Implement. Write tests. Verify against acceptance criteria before committing.
      If a criterion says "run this command", actually run it.

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
      Read the scratchpad for acceptance criteria. Verify by actually
      running what they specify. On failure: capture error, diagnose
      root cause, write findings in scratchpad. Then decide:
      - work.resume (code bug): tell builder what's wrong and how to fix
      - replan (plan wrong): tell planner what's infeasible and why
      On pass: mark verified in scratchpad, emit plan.ready or
      LOOP_COMPLETE. NEVER emit build.done.
```

### Other Stages

**Feature** (existing codebase, scoped work): `max_iterations: 20`. Use `builtin:code-assist` instead of custom hats: `ralph run -c ralph.yml -H builtin:code-assist -p "description"`.

**Refactor** (large changes): `max_iterations: 30`, `max_consecutive_failures: 2`. Always run on a branch.

**Explore** (vague goals): `max_iterations: 15`, `persistent: true`, `tasks.enabled: false`.

---

## Notes

- `ralph run` uses fresh context per iteration — no context overflow risk on long loops.
- `ralph run` requires either a `PROMPT.md` file or `-p "inline text"`. Create `PROMPT.md` as part of setup.
- Memories persist in `.ralph/agent/memories.jsonl`. Keep them between specs.
- Validate with `ralph preflight` before launching.
- **Reserved triggers**: `task.start`, `task.resume`, `task.complete` and other `task.*` names are reserved. Use `work.start`, `work.resume`, `build.done`, etc.
- **Avoid self-triggering hats**: A hat must not emit an event that matches its own trigger (e.g. reviewer emitting `build.done`). Set `default_publishes` to a forward event, add `max_activations: 1`, and explicitly instruct the hat not to self-trigger.
- **Minimize loop restarts**: Each restart costs a planner re-analysis. Supply all tasks in PROMPT.md up front. Prefer one loop with 20+ tasks over four loops with 5 tasks.
- **Don't ask human questions unless blocked**: Resolve ambiguity from specs, reference code, and patterns. Only escalate for genuine blockers (missing credentials, architectural deadlocks).
- **Update PROJECT_PLAN.md**: After each spec completes, check off completed items so the next planner has accurate state.
- **TUI needs a real TTY**: Use `-q` mode when launching via `tmux send-keys`. For human monitoring, use the dashboard script above.
- **PROMPT.md is a comprehensive spec, not a vague goal**: Include code deliverables, infrastructure tasks, handoff artifacts (README, docs, demo), and verification requirements. "Build phase 3" is not a spec. "Implement REST API, start the server, verify /tree returns JSON, write a getting started guide that works when followed" is a spec.
- **The planner must research before planning**: Read existing code, understand what's built, identify what's broken or missing. Don't plan from PROMPT.md alone.
- **Infrastructure is a task, not an assumption**: If verifying work requires Docker, a running server, or a database, the planner must include setup tasks. The builder sets up infrastructure as part of the build, not as a precondition.
- **Handoff artifacts are deliverables**: README, getting started guide, deployment docs, changelog, project website, demo — these are tasks with acceptance criteria, not afterthoughts.
