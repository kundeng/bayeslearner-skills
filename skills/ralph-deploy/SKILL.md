---
name: ralph-deploy
description: Plan and configure ralph-orchestrator deployments for projects at any stage — from a vague phase plan to a mature codebase. Use this skill whenever the user wants to set up ralph for a new project, choose between deployment topologies (direct, Claude+MCP, multi-project supervisor), pick the right config for their project's maturity, run oneshot autonomous builds, or manage multiple concurrent ralph loops across tmux sessions. Also use when the user asks "how should I run ralph on this?", mentions phase plans, or wants to configure cost budgets, hat workflows, or guardrails for a specific project type.
---

# Ralph Deploy

Configure and launch ralph-orchestrator. Install: `cargo install --git https://github.com/mikeyobrien/ralph-orchestrator ralph-cli`

## Directory Discipline

```
.kiro/specs/                        # specs (committed)
  NN-<name>/
    requirements.md                 # input: the spec AND the ralph prompt (-P)
    design.md                       # output: archived scratchpad after loop
    progress.txt                    # output: timestamped task log
  steering/                         # optional: product vision, tech decisions

.ralph/                             # orchestrator (gitignored runtime state)
  ralph.yml                         # config (core.specs_dir → .kiro/specs)
  hats/greenfield.yml               # hat definitions with ceremony instructions
  agent/scratchpad.md               # hat handoff channel (ephemeral)
  agent/memories.md                 # persistent constraints (seed with ceremony rules)
```

**Rules:** No root pollution. requirements.md IS the prompt — no separate prompt.md. design.md is an output, not an input. `.kiro/specs/` is canonical — migrate legacy locations. Number spec dirs sequentially (`01-`, `02-`).

## Before You Start

```bash
ralph loops list                    # existing loops?
tmux has-session -t ralph-$NAME 2>/dev/null && echo "running"
ls .ralph/loop.lock 2>/dev/null     # stale lock?
```

If running: monitor, don't start another. If stale lock with no session: `rm .ralph/loop.lock`.

## Hats = Roles in the Loop

```
work.start → [planner] → plan.ready → [builder] → build.done → [reviewer]
                ↑                         ↑                          │
                │                         └── work.resume ───────────┤ (code bug)
                └──────── replan ────────────────────────────────────┘ (plan wrong)
                                                                     │
                                                        LOOP_COMPLETE (verified)
```

Hats communicate via scratchpad (task breakdown + acceptance criteria), memories (persistent constraints), and event payloads. Sonnet MUST NOT be reviewer — it ignores event constraints and causes stale loops. Use Opus for planner and reviewer; Opus or Sonnet for builder.

## Tmux Setup

```bash
SPEC="<spec-name>"
tmux new-session -d -s "$NAME" -c "$PROJECT_PATH"
tmux send-keys -t "$NAME:0" "ralph run -q -c .ralph/ralph.yml -H .ralph/hats/greenfield.yml -P .kiro/specs/$SPEC/requirements.md > .ralph/run.log 2>&1" Enter
tmux split-window -v -t "$NAME:0" -c "$PROJECT_PATH" -l 80%
tmux send-keys -t "$NAME:0.1" "bash .ralph/monitor.sh" Enter
tmux resize-pane -t "$NAME:0.0" -y 3
```

Monitor: `.ralph/monitor.sh` (copy from `scripts/monitor.sh` in this skill) or `ralph tui` (needs real TTY, attach directly). Set up `CronCreate` every 3 minutes to poll events + commits. Auto-cancel when loop terminates.

## Codex Periodic Watch

For Codex, periodic Ralph monitoring can be implemented by reusing a watcher sub-agent as a timer-like harness.

- Spawn one monitor sub-agent and keep reusing the same agent id/thread.
- Give it a bounded instruction such as: wait 60-180 seconds, inspect the Ralph loop, then return a compact status summary.
- When it returns, the main Codex agent should:
  - summarize status to the user if needed
  - decide whether to steer Ralph
  - send the next timed watch instruction to that same monitor sub-agent
- Treat this as a reusable monitor channel, not as a native always-on daemon.

Recommended Codex watch cycle:

1. Create monitor agent once.
2. Instruct: wait N minutes, check Ralph status, report `progressing`, `stuck`, `failed`, or `needs-input`.
3. Main agent inspects result and optionally emits steering.
4. Main agent reuses the same monitor agent for the next cycle.

Use this when Codex is the meta-orchestrator and no built-in timer tool is available. If another frontend provides a native timer tool, prefer that simpler primitive over a sub-agent watch loop.

## CLI Reference

| Action | Command |
|--------|---------|
| Loop status | `ralph loops list` |
| Events | `ralph events --last 10` |
| View plan | `cat .ralph/agent/scratchpad.md` |
| Stop | `touch .ralph/stop-requested` |
| Resume | `ralph run --continue` |
| Steer | `ralph wave emit human.guidance --payloads "msg"` |
| Validate | `ralph preflight -c .ralph/ralph.yml -H .ralph/hats/greenfield.yml` |
| Dry run | `ralph run --dry-run -c .ralph/ralph.yml -H .ralph/hats/greenfield.yml -P .kiro/specs/<name>/requirements.md` |

## Writing the Spec (requirements.md)

Human-authored, variable-depth. The planner fills gaps; never overrides what the human specified.

**Thin** (domain is well-understood):
```markdown
Rework Docker/Splunk infra from the devcontainer template.
Splunk 10.2.1+, Python 3.12. Ports: 18000/18088/18089.
Accept when: `docker compose config` validates and all 7 checks pass.
```

**Detailed** (high stakes, specific opinions):
```markdown
### Requirement 1: Strategy wiring
1. WHEN scene JSON has `"strategy": "rule-based"`, THE Bot SHALL use RuleBasedStrategy
2. WHEN strategy is omitted, THE Bot SHALL default to RuleBasedStrategy
3. WHEN unknown strategy specified, THE ScenePlayer SHALL raise ScenePlayerError
```

Include: code deliverables, infrastructure tasks, handoff artifacts, verification requirements. Claude can help draft — but should not author unilaterally.

## Lifecycle

```
human writes requirements.md  →  ralph run -P requirements.md
                                       ↓
                              planner → builder → reviewer loop
                                       ↓
                              ceremony: archive scratchpad → design.md
                                        write progress.txt
                                       ↓
                              update PROJECT_PLAN.md → next spec
```

One spec = one loop. Only write requirements.md before launching. Archive after loop. Migrate legacy spec locations on sight.

## Operational Discipline

- Minimize loop restarts — each costs a planner re-analysis
- Don't ask human questions unless blocked
- Update PROJECT_PLAN.md after each spec completes
- TUI needs real TTY — use `-q` mode in tmux
- Handoff artifacts are deliverables with acceptance criteria
- Ceremony is enforced in hat instructions and seeded memories — not here

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
    max_activations: 4
    instructions: |
      RESEARCH FIRST: Read existing code, the requirements.md (passed via -P),
      CLAUDE.md, scratchpad, and .ralph/agent/memories.md. Understand what's
      built, what works, what's broken. Do not plan from requirements.md alone.

      Write an ARTIFACT REGISTRY in the scratchpad — a table of every
      deliverable with columns: Exists | Tests | Runtime Verified | Acceptance Criteria

      Break work into tasks. For EACH task, write concrete acceptance criteria:
      commands to run, output to expect, endpoints to curl, files to check.

      Include infrastructure setup and handoff artifacts as tasks when needed.

      Emit scaffold.done if scaffolding, then plan.ready.

  builder:
    name: "Builder"
    description: "Implements tasks from the plan"
    backend: claude
    backend_args: ["--model", "opus"]
    triggers: ["plan.ready", "work.resume"]
    publishes: ["build.done", "tests.passing"]
    default_publishes: "build.done"
    instructions: |
      Read the scratchpad for the current task and its acceptance criteria.
      Read .ralph/agent/memories.md for known constraints and past fixes.

      Implement the task. Write appropriate tests. Verify your own work against
      the acceptance criteria before committing. If a criterion says "run this
      command and see X", actually run it. Commit after each logical unit.

      PROGRESS TRACKING — after each task commit:
      1. Find the spec directory (parent dir of the -P requirements.md file).
         If unsure, check .ralph/agent/memories.md for the spec dir path.
      2. Append a line to progress.txt in that spec directory:
         [YYYY-MM-DD HH:MM] DONE task-id — one-line description (commit-hash)
      3. Update the SUMMARY line at the top:
         # SUMMARY: M/N done | next: <next-task-id>
      4. If progress.txt doesn't exist yet, create it with this header:
         # Progress Log: <spec-name>
         # Auto-updated by builder during ralph loop
         # Format: [TIMESTAMP] STATUS task-id — description
         # SUMMARY: 0/N done | next: <first-task-id>

      Write to .ralph/agent/memories.md when you discover non-obvious constraints.

  reviewer:
    name: "Reviewer"
    description: "Verifies implementation and diagnoses failures"
    backend: claude
    backend_args: ["--model", "opus"]
    triggers: ["build.done"]
    publishes: ["LOOP_COMPLETE", "work.resume", "plan.ready", "replan"]
    default_publishes: "plan.ready"
    max_activations: 1
    instructions: |
      Read the scratchpad for the current task's acceptance criteria.
      Read .ralph/agent/memories.md for known constraints and past fixes.
      Verify by actually running what they specify — commands, curl, file checks.
      Run the test suite as a baseline but do NOT stop there.

      WHEN VERIFICATION FAILS:
      1. Capture the actual error (stderr, stack trace, diff from expected)
      2. Diagnose root cause — read the code, identify what's wrong
      3. Write diagnosis in scratchpad under "## Reviewer Findings"
      4. Write root cause to .ralph/agent/memories.md if non-obvious
      5. Code bug → emit work.resume. Plan wrong → emit replan.

      WHEN VERIFICATION PASSES:
      - Mark task verified in scratchpad with what you ran
      - More tasks remain → emit plan.ready

      COMPLETION CEREMONY — when ALL tasks verified, do these IN ORDER:
      1. SPEC DIR: parent directory of the -P requirements.md file.
         Example: -P .kiro/specs/06-foo/requirements.md → .kiro/specs/06-foo/
      2. ARCHIVE: cp .ralph/agent/scratchpad.md <spec-dir>/design.md
      3. PROGRESS: verify <spec-dir>/progress.txt has a DONE line per task.
         Update SUMMARY to: # SUMMARY: N/N done | next: DONE
         If missing or incomplete, write it now with all tasks.
      4. VERIFY: confirm spec dir has requirements.md, design.md, progress.txt
      5. EMIT LOOP_COMPLETE only after steps 1-4 are done.

      NEVER emit build.done.
      NEVER emit LOOP_COMPLETE without completing ALL ceremony steps.
```
