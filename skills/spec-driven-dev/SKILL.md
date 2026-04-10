---
name: spec-driven-dev
description: "Spec-driven development: plan → go → review loop. Use for planning features, implementing from specs, refining specs, resuming work. Trigger on requests mentioning specs, requirements/design/tasks, spec-help, spec-plan, `.kiro`. IMPORTANT: Never edit spec files without first reading this skill."
metadata:
  author: kundeng
  version: "2.0.0"
---

## Spec-Driven Development

Specs live in `.kiro/specs/<NN-name>/`. Numeric prefixes for ordering (`01-auth`, `02-api-layer`). Two modes:

- **Full ceremony** (requirements.md → design.md → tasks.md): formal traceability, approval gates, multi-team
- **Fast-track** (single `spec.md`): one scratchpad for planner/builder/reviewer — no gates, cycle freely between hats

**Detection:** `spec.md` → fast-track. `requirements.md` → full ceremony. Never mix both.
**Small work:** Add to an existing spec as tasks, or create a fast-track spec.
**Upgrade:** Fast-track → full when >20 tasks or traceability needed: Context → requirements.md, Decisions → design.md, Tasks → tasks.md.

### Spec Resolution

SPEC → `.kiro/specs/*-SPEC/` or `.kiro/specs/SPEC/`. No name → auto-select if exactly one exists. Let **SPEC_DIR** = resolved directory. When creating, assign next available number.

### Core Loop

```mermaid
stateDiagram-v2
  [*] --> Plan : spec-plan create

  state Plan {
    [*] --> Scaffold
    Scaffold --> Scan
    Scan --> GenReqs : full
    Scan --> GenSpec : fast
    GenReqs --> Approve_R
    Approve_R --> GenReqs : revise
    Approve_R --> GenDesign : ok
    GenDesign --> Approve_D
    Approve_D --> GenDesign : revise
    Approve_D --> GenTasks : ok
    GenTasks --> Approve_T
    Approve_T --> GenTasks : revise
    GenSpec --> Ready
    Approve_T --> Ready
  }

  Plan --> Go : approved

  state Go {
    [*] --> Build
    state Build {
      [*] --> PickTask
      PickTask --> Implement
      Implement --> Test
      Test --> Implement : fix up to 3x
      Test --> Commit : pass
      Test --> Stuck : 3x fail
      Commit --> PickTask : more tasks
    }
    Build --> SelfReview : task done or stuck
    state SelfReview {
      [*] --> CheckSpec
      CheckSpec --> AddTests : coverage gaps
      CheckSpec --> MinorFix : add or tweak tasks
      AddTests --> CheckSpec
      MinorFix --> CheckSpec
      CheckSpec --> OK : clean
    }
    SelfReview --> Build : continue
    SelfReview --> Replan : drastic change
  }

  Replan --> Plan : human reviews new plan
  Go --> [*] : all tasks done
  Go --> [*] : stuck
```

**Concurrency:** Single orchestrator owns spec files, one sequential builder by default. Subagents OK for non-code work (research, docs, website). Parallel builders only when user explicitly requests AND tasks are truly independent.

| State | Entry | Stops when |
|-------|-------|-----------|
| **Plan** | `/spec-plan create [--fast]` | User approves (full) or spec generated (fast) |
| **Go** | `/spec-go`, `/spec-task` | All done, needs human feedback, or stuck |
| **Review** | `/spec-audit`, `/spec-status`, `/spec-plan refine` | Findings presented |

**Resuming** — detect from files on disk:

| Files present | State | Action |
|---------------|-------|--------|
| None | Plan | `/spec-plan create` |
| `spec.md` | Go | Next unchecked task |
| `requirements.md` only | Plan | Generate design.md |
| `requirements.md` + `design.md` | Plan | Generate tasks.md |
| All 3 + `[ ]` tasks | Go | Next task |
| All tasks `[x]` | Done | Audit or merge |

### Rules

1. **Read before acting** — all spec files + steering docs if they exist.
2. **Re-anchor when uncertain** — re-read spec if next action could deviate.
3. **Respect dependencies** — never skip ahead.
4. **Tests are separate tasks.**
5. **Commit per task** — `feat(<spec>/<task>): [description]`
6. **Minimal changes** — only what the task requires.

---

## Commands

### `/spec-plan <name> [create|refine] [--fast]`

Auto-detected: **create** if spec doesn't exist, **refine** if it does.

#### Create (full ceremony)

**Scaffold:** Create `.kiro/specs/NN-SPEC/`.
**Scan:** Read README, manifests, source structure, tests, CI, steering docs. Align with conventions.

**Generate requirements.md** — template below. **Generate first, iterate second.** EARS format:
- `WHEN [event] THEN [system] SHALL [response]`
- `IF [condition] THEN [system] SHALL [response]`
- `WHILE [state] [system] SHALL [response]`
- `[system] SHALL [response]`

**→ Present for approval:**
```
Requirements for SPEC — N requirements, M acceptance criteria, K non-functional
  R1: [title] — [N criteria]
  R2: [title] — [N criteria]
  NF1: [title]
  Out of scope: [summary]
Ready for design? (approve / revise)
```

**Generate design.md** — template below. Research if needed. Modules, interfaces, data flow, testing strategy, correctness properties validating requirements.

**→ Present for approval:**
```
Design for SPEC — N modules, M properties, K decisions
  Modules: [list]
  Properties: P1 validates R1.1,1.2 | P2 validates R2.1 | ...
  Test command: [command]
  Decisions: [list titles]
Ready for tasks? (approve / revise)
```

**Generate tasks.md** — template below. Each task one session. Depends/Requirements/Properties. Order: Foundation → Core → Tests → Polish. Every requirement → ≥1 task.

**→ Present for approval:**
```
Tasks for SPEC — N tasks across M phases
  1.1: [title]  (depends: —)
  1.2: [title]  (depends: 1.1)
  2.1: E2E — [scenario]  (depends: 1.1, 1.2)
  Coverage: all requirements traced, all properties tested
Ready to implement? (approve / revise)
```

// turbo
**Commit:** `git add -A && git commit -m "spec(SPEC): create requirements, design, and tasks"`

#### Create (fast-track)

Same scaffold and scan. Generate `spec.md` (template below): Context, Decisions (can start empty), Tasks by P1/P2/P3. Iterate if feedback, then move on.

// turbo
Commit: `git add -A && git commit -m "spec(SPEC): create fast-track spec"`

#### Refine (full ceremony)

1. Read requirements.md, design.md, tasks.md + scan repo for drift.
2. Ask what should change (or use `/spec-audit` findings).
3. Refinement: merge redundant requirements, separate what from how, collapse over-specified sub-requirements, merge overlapping properties, cascade renumbering, validate traceability (requirement → property → task), align spec with disk.
4. Trace changes top-down and bottom-up. Done tasks (`[x]`): update references, do NOT uncheck.

**→ Present change summary:**
```
Refine SPEC — changes:
  Requirements: +N added, ~M merged, -K removed
  Properties:  +N added, ~M renumbered
  Tasks:       +N added, ~M updated, -K removed
  Traceability gaps: [list or "none"]
  Disk drift fixed: [list or "none"]
Approve refinement? (approve / revise)
```

// turbo
Commit: `git add -A && git commit -m "spec(SPEC): refine — [brief]"`

#### Refine (fast-track)

Read `spec.md`, scan for drift, update Context/Decisions/Tasks, re-prioritize. If >20 tasks, suggest promoting to full ceremony. Append to Log.

// turbo
Commit: `git add -A && git commit -m "spec(SPEC): refine fast-track — [brief]"`

---

### `/spec-go <name> [count]`

Autonomous build→self-review loop. Optional count limits tasks per session. Stops on: all done, needs human, or stuck.

**Build phase:**
1. **Read spec** — full: requirements.md, design.md, tasks.md (+ steering). Fast-track: spec.md.
2. **Pick next task** — first `[ ]` with all deps satisfied. Only optional left → STOP.
3. **Announce** — "Starting task [ID]: [TITLE]"
4. **Implement** — read relevant code first. Test tasks: Red-Green-Refactor. Implementation tasks: write code, run existing tests.
5. **Test** — failures → fix up to 3x. Still failing → mark `[!] BLOCKED: reason`, skip to next. No unblocked tasks → STOP (stuck).
// turbo
6. **Lint** if configured.
7. **Update** — mark task `[x]`.
// turbo
8. **Commit** — `git add -A && git commit -m "feat(SPEC/[ID]): [description]"`

**Self-review phase** (every 3 tasks or after a BLOCKED):
9. Re-read spec, check for drift. **Primary job: ensure test coverage** — for each completed task, verify a test task exists that covers it. If not, append a test task so the builder implements and runs it next. Tests must pass before the reviewer signs off.
10. **Minor fixes** (add/drop/tweak tasks, add test tasks) → apply inline, continue. **Drastic changes** (wrong requirements, architecture rethink, scope shift) → STOP, go to Plan for human review.
11. **Report checkpoint:**
```
Checkpoint: SPEC — N/TOTAL tasks done
  Completed this session:
    [x] 1.1: [title]
    [x] 1.2: [title]
  Blocked:
    [!] 2.1: [reason]
  Tests: PASS/FAIL
  Next: [ID]: [title]
  Spec drift: [none / what was fixed]
```
Then loop to build.

---

### `/spec-task <name> <task>`

Single task build. Same as `/spec-go` build steps 1–8 for one task. Verify deps first — if unmet, STOP. When run by a subagent in a parallel worktree, **never modify spec files** — only write code, tests, docs. Orchestrator updates status after merge.

**→ Report:**
```
Task [ID] complete: [title]
  Tests: PASS/FAIL
  Files changed: [list]
  Follow-up: [issues or "none"]
```

---

### `/spec-audit <name>`

Read requirements.md, design.md, tasks.md. Run checks:
1. **Traceability** — orphan requirements, orphan properties, broken references
2. **Redundancy** — duplicates, subset properties, implementation details in requirements
3. **Stale language** — future tense on done tasks, checked goals with unchecked subs
4. **Spec↔disk drift** — design directory vs actual repo
5. **Doc sync** — README/docs vs spec

**→ Print report:**
```
Audit: SPEC
  Traceability:
    ✓ N requirements → M properties → K tasks
    ⚠ R[N] has no validating property
    ⚠ P[N] has no implementing task
  Redundancy:
    ⚠ R[N] and R[M] describe same behavior
  Stale language:
    ⚠ R[N] future tense but task [ID] done
  Spec↔disk drift:
    ✗ spec lists "[path]" — not on disk
  Doc sync:
    ⚠ README says "[X]" but spec says "[Y]"
  Summary: E errors, W warnings
```
Suggest `/spec-plan SPEC refine`.

---

### `/spec-status`

Discover all specs in `.kiro/specs/`. Read tasks, count status marks, compute completion.

**→ Print dashboard:**
```
SPEC STATUS
  01-auth:
    Progress: ████████░░ 5/7 (71%)
    Status:   1.1✓ 1.2✓ 1.3~ 2.1✓ 2.2✓ 3.1○ 3.2○*
    Blocked:  none
  02-api-layer:
    Progress: ██░░░░░░░░ 1/5 (20%)
    Status:   1.1✓ 1.2○ 2.1○ 2.2○ 3.1○*
    Blocked:  none
```

### `/spec-merge <name>`

// turbo
Find branches (`git branch --list "task/*"`, `git worktree list`), ask which to merge. Merge each (`git merge <branch> --no-edit`), resolve conflicts intelligently. Clean up branches/worktrees (confirm). Verify tasks status, tests, lint. Commit fixes: `git add -A && git commit -m "chore(SPEC): post-merge fixes"`

### `/spec-reset <name>`

Confirm with user. Reset all status marks (`[x]`/`[~]`/`[!]` → `[ ]`, preserve `*`).
// turbo
Commit: `git add -A && git commit -m "chore(SPEC): reset progress"`

### `/spec-help`

Print the Core Loop diagram and command table from this skill, then ask what the user wants to do.

---

## Templates

### requirements.md

```markdown
# Requirements Document

## Introduction
<!-- What this spec covers and why -->

## Glossary
- **Term_1**: Definition

## Requirements

### Requirement 1: [Feature area]
**User Story:** As a [role], I want [action], so that [benefit].
#### Acceptance Criteria
1. WHEN [trigger], THE [Component] SHALL [expected behavior]
2. WHEN [trigger], THE [Component] SHALL [expected behavior]

### Requirement 2: [Feature area]
**User Story:** As a [role], I want [action], so that [benefit].
#### Acceptance Criteria
1. WHEN [trigger], THE [Component] SHALL [expected behavior]

### Non-Functional
**NF 1**: [Performance / reliability / security requirement]

## Out of Scope
<!-- What this spec explicitly does NOT cover -->
```

### design.md

```markdown
# Design: [SPEC NAME]

## Tech Stack
- **Language**:
- **Framework**:
- **Testing**:
- **Linter**:

## Directory Structure
\```
src/
tests/
\```

## Architecture Overview
\```mermaid
graph TD
    A[Module A] --> B[Module B]
    A --> C[Module C]
    B --> D[Shared Service]
    C --> D
\```

## Module Design
### [Module 1]
- **Purpose**: [what it does]
- **Interface**:
  \```
  [function signatures, class interfaces, API endpoints]
  \```
- **Dependencies**: [what it depends on]

## Data Flow
\```mermaid
sequenceDiagram
    participant User
    participant CLI
    participant Service
    participant Store
    User->>CLI: command
    CLI->>Service: process(args)
    Service->>Store: read/write
    Store-->>Service: result
    Service-->>CLI: output
    CLI-->>User: display
\```

## State Management
<!-- Omit if stateless -->

## Data Models
<!-- Omit if simple -->

## Error Handling Strategy

## Testing Strategy
- **Property tests**: Verify design invariants (required)
- **E2E tests**: Validate user stories end-to-end (required)
- **Unit tests**: Complex internal logic only (optional)
- **Test command**: `[command]`
- **Lint command**: `[command]`

## Constraints

## Correctness Properties
### Property 1: [Property name]
- **Statement**: *For any* [condition], when [action], then [expected outcome]
- **Validates**: Requirement 1.1, 1.2
- **Example**: [concrete example]
- **Test approach**: [how to verify]

## Edge Cases

## Decisions
### Decision: [Title]
**Context:** [Situation]
**Options:** 1. [Option] — Pros / Cons  2. [Option] — Pros / Cons
**Decision:** [Chosen]  **Rationale:** [Why]

## Security Considerations
<!-- If applicable -->
```

**Diagram guidance**: Always include component diagram. Add sequence (multi-actor), state (stateful), ER (data-heavy). Omit empty sections.

### tasks.md

```markdown
# Tasks: [SPEC NAME]

## Status marks
<!-- [ ] pending | [x] done | [~] skipped | [!] BLOCKED: reason | [ ]* optional -->

## Tasks

- [x] 1. Setup phase
  - [x] 1.1 [Completed task title]
    - [What was implemented]
    - **Depends**: —
    - **Requirements**: 1.1, 1.2
    - **Properties**: 1
  - [x] 1.2 [Completed task title]
    - **Depends**: 1.1

- [ ] 2. Core phase
  - [!] 2.1 [Blocked task] BLOCKED: [reason]
    - **Depends**: 1.1
    - **Requirements**: 2.1
    - **Properties**: 2
  - [ ] 2.2 [Pending task]
    - **Depends**: 1.1, 1.2
  - [ ] 2.3 Write property test for [property name]
    - **Depends**: 2.2
    - **Properties**: 2
  - [ ]* 2.4 [Optional task]
    - **Depends**: 2.2

- [ ] 3. E2E Tests
  - [ ] 3.1 E2E — [User story scenario]
    - **Depends**: 2.2, 2.3
    - **Requirements**: 1.1, 2.1

## Notes
```

**Conventions**: Hierarchical IDs. Parents = phase headers (checked when all children done). **Depends** required; **Requirements**/**Properties** for traceability. Tests = separate sub-tasks. Each task 30 min – 2 hours.

### spec.md (fast-track)

This is the single working scratchpad for all three hats: **planner** (Context + Constraints + Tasks), **builder** (check off tasks + append Log), **reviewer** (Decisions + flag issues + add test tasks in Log). No gates — cycle freely between hats throughout the work.

```markdown
# [SPEC NAME]

## Context
<!-- Why this work exists, who it's for, what success looks like. -->

[2-3 sentences describing the problem and motivation]

## Constraints
<!-- Non-negotiable boundaries: tech stack, perf, compatibility, timeline. -->

- [e.g., Must use existing auth system]
- [e.g., Python 3.11+, no new dependencies]

## Decisions
<!-- Key choices made. Add as you go — capture the fork, the choice, and why. -->

### D1: [Decision title]
**Choice:** [what was decided]
**Why:** [rationale — what was the alternative, why not that]

### D2: [Decision title]
**Choice:** [what was decided]
**Why:** [rationale]

## Tasks
<!-- [ ] pending | [x] done | [~] skipped | [!] BLOCKED: reason -->

### P1 — Must Do
- [x] 1.1 [Completed task]
- [ ] 1.2 [Pending task]
- [ ] 1.3 Test: [what to verify for 1.1-1.2]

### P2 — Should Do
- [ ] 2.1 [Task description]

### P3 — Nice to Have
- [ ] 3.1 [Task description]

## Open Questions
<!-- Unknowns that need research or user input before proceeding. -->

- [ ] [Question — what needs answering, who can answer it]
- [x] [Resolved question — answer found, see D2]

## Log
<!-- Append as you go. Date + what happened + decisions made + issues found. -->

**[YYYY-MM-DD]** — [what was done, what was learned, what changed]
**[YYYY-MM-DD]** — [reviewer hat: added test task 1.3, found gap in X]
```

**Conventions**: IDs = `<priority>.<sequence>`. No Depends/Requirements metadata — keep lightweight. Status marks same as full ceremony. The Log is where the reviewer hat lives — flag drift, record why tasks were added/dropped, note test coverage gaps. Open Questions track unknowns that block or inform tasks.

---

## Steering Docs (optional)

Read-only project context at `.kiro/steering/` (root, not inside `specs/`):
`product.md` (vision), `structure.md` (repo layout), `tech.md` (stack decisions).
Read during planning and before implementing. Never modify during execution.

## Analytic Specs

When analytic/notebook/experiment-oriented, pair with `analytic-workbench`. Requirements should cover artifact outputs, review checkpoints, promotion criteria. Design should make notebook vs module boundaries explicit. Tasks should separate exploratory → review → promotion stages.
