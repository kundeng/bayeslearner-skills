---
name: ralph-deploy
description: Plan and configure ralph-orchestrator deployments for projects at any stage — from a vague phase plan to a mature codebase. Use this skill whenever the user wants to set up ralph for a new project, choose between deployment topologies (direct, Claude+MCP, multi-project supervisor), pick the right config for their project's maturity, run oneshot autonomous builds, or manage multiple concurrent ralph loops across tmux sessions. Also use when the user asks "how should I run ralph on this?", mentions phase plans, or wants to configure cost budgets, hat workflows, or guardrails for a specific project type.
---

# Ralph Deploy

Configure and launch ralph-orchestrator for a project. Covers topology selection, config generation, and tmux session automation.

Ralph supports multiple agent backends (`claude`, `codex`, `kiro`, `gemini`, `amp`, `copilot`, `opencode`, `pi`, `custom`). Ask which backend the user runs and set `cli.backend` accordingly.

## Install

```bash
cargo install --git https://github.com/mikeyobrien/ralph-orchestrator ralph-cli
```

Verify: `ralph --version`.

---

## Topology Selection

**A — Direct**: Ralph runs in a tmux session. You script and steer from a shell. Best for single-project focused work.

**B — Agent+MCP**: The user's CLI agent (Claude Code, Codex, etc.) manages ralph via MCP while ralph executes in a separate tmux session. The MCP server (`ralph mcp serve`) is a standalone control plane — it runs independently, reads/writes `.ralph/` state, and can queue tasks, update config, and monitor events. However, it cannot start loop execution. `ralph run` must be launched separately (via `tmux send-keys`) to actually execute queued tasks. Best for oneshotting from a phase plan.

**C — Multi-Project Supervisor**: One agent session manages multiple ralph instances, each in its own tmux session with its own MCP server entry. Best for 3+ concurrent projects.

```
Single project, user watching         → A
Single project, oneshot from plan     → B
Multiple projects, coordinated        → C
```

---

## Topology A Setup

Create a tmux session with ralph run, TUI monitor, and steering shell:

```bash
tmux new-session -d -s "$NAME" -c "$PROJECT_PATH"
tmux send-keys -t "$NAME:0" "ralph run -c ralph.yml -H hats/workflow.yml" Enter
tmux split-window -h -t "$NAME:0" -c "$PROJECT_PATH"
tmux send-keys -t "$NAME:0.1" "sleep 3 && ralph tui" Enter
tmux split-window -v -t "$NAME:0.0" -c "$PROJECT_PATH"
```

Steering from pane 2: `ralph wave emit human.guidance --payloads "message"`, `touch .ralph/stop-requested`, `ralph run --continue`.

## Topology B Setup

1. Start MCP server (can run before any loop exists):
   ```bash
   # Add to ~/.claude/mcp.json (or codex equivalent)
   {"mcpServers": {"ralph": {"command": "ralph", "args": ["mcp", "serve", "--workspace-root", "/path/to/project"]}}}
   ```

2. From the agent session, set up work via MCP: `task.create` to queue tasks, `config.update` to adjust ralph.yml.

3. Start the loop in a separate tmux session:
   ```bash
   tmux new-session -d -s "ralph-$NAME" -c "$PROJECT_PATH"
   tmux send-keys -t "ralph-$NAME:0" "ralph run -c ralph.yml -H hats/workflow.yml" Enter
   ```

4. Monitor via MCP: `loop.status`, `stream.subscribe` (topics: `task.status.changed`, `loop.status.changed`). Steer via `task.create` with corrective tasks.

5. Between phases: set up new tasks via `task.create`, update config via `config.update`, then:
   ```bash
   tmux send-keys -t "ralph-$NAME:0" "ralph run --continue" Enter
   ```

Key MCP tools: `loop.status`, `loop.stop`, `loop.list`, `task.create/list/run_all`, `config.get/update`, `stream.subscribe`, `planning.start/respond`.

## Topology C Setup

Same as B, but with one MCP server per project in the config and one tmux session per project. The supervisor agent polls all via `loop.status` on each MCP server.

---

## Stage Configs

### Greenfield (phase plan, no code)

This is the full reference config. Other stages follow the same structure with adjustments noted below.

```yaml
cli:
  backend: claude   # or codex, kiro, gemini, etc.

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

Hat collection for greenfield (`hats/greenfield.yml`):

```yaml
event_loop:
  starting_event: "work.start"
  completion_promise: "LOOP_COMPLETE"

hats:
  planner:
    name: "Architect"
    description: "Reads specs and breaks work into tasks"
    triggers: ["work.start", "phase.next"]
    publishes: ["plan.ready", "scaffold.done"]
    default_publishes: "plan.ready"
    max_activations: 8
    instructions: |
      Read specs. Break into concrete tasks ordered by dependency.
      Emit scaffold.done if scaffolding, then plan.ready.

  builder:
    name: "Builder"
    description: "Implements tasks from the plan"
    triggers: ["plan.ready", "task.resume"]
    publishes: ["build.done", "tests.passing"]
    default_publishes: "build.done"
    instructions: |
      Implement next task. Write tests. Run them. Fix failures. Commit.

  reviewer:
    name: "Reviewer"
    description: "Verifies implementation against spec"
    triggers: ["build.done"]
    publishes: ["LOOP_COMPLETE", "task.resume"]
    instructions: |
      Review against spec. Run full test suite.
      Issues → emit task.resume. Clean → emit LOOP_COMPLETE.
```

### Other Stages (adjustments from greenfield)

**Feature** (existing codebase, defined work): `max_iterations: 20`. Guardrails: don't modify out-of-scope files, follow existing conventions. Use `builtin:code-assist` instead of custom hats — it's sufficient for well-scoped work: `ralph run -c ralph.yml -H builtin:code-assist -p "description"`.

**Refactor** (existing codebase, large changes): `max_iterations: 30`, `max_consecutive_failures: 2` (fail fast — this is the critical setting), `features.parallel: false`. Guardrails emphasize reverting on test failure. Always run on a branch. Required events: `tests.passing`, `migration.verified`.

**Explore** (vague goals, prototyping): `max_iterations: 15`, `persistent: true` (loop idles after completion for interactive follow-up), `tasks.enabled: false`. Guardrails: maintain FINDINGS.md, prototype in scratch/, work on a branch.

---

## Oneshot Pattern (Topology B)

For running a project from phase plan to completion:

1. Place phase plan in `specs/plan.md` with per-phase goals, done-when criteria, and dependencies
2. Configure ralph with greenfield config
3. From the agent session (MCP connected): create Phase 1 tasks via `task.create`
4. Start loop: `tmux send-keys -t "ralph-project:0" "ralph run -c ralph.yml -H hats/greenfield.yml" Enter`
5. Monitor via `loop.status` and `stream.subscribe`
6. When loop terminates: check reason, review via `task.list`
7. Set up Phase 2: `task.create` new tasks, `config.update` if needed
8. Continue: `tmux send-keys -t "ralph-project:0" "ralph run --continue" Enter`
9. Repeat for each phase

Corrections happen at two levels: within a phase (ralph handles via hat rotation, guardrails, circuit breaker) and between phases (agent reviews results, creates corrective tasks, adjusts config).

---

## Notes

- `ralph run` uses fresh context per iteration by design — no context overflow risk on long loops.
- Memories persist across stages in `.ralph/agent/memories.jsonl`. Keep them when transitioning between stages.
- Validate config with `ralph preflight --strict` before launching.
- Hat trigger names `task.start` and `task.resume` are reserved by ralph for coordination. Use semantic names like `work.start`, `review.start`.
