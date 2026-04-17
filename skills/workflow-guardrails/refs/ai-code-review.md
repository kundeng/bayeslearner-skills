# Comprehensive Code Review Prompt for AI-Authored Projects

> **Purpose**: Coherence audit of an AI-authored codebase where the code, the docs, and the real human intention have all drifted from each other. This is not a spec-compliance check — it is a judgment-driven assessment of whether the system serves its actual purpose across all layers.

> **Key insight**: In AI-authored projects, there are three imperfect representations of intent: the code (which drifted because agents solve local problems without holding global intent), the docs (which drifted through revisions and aspirational edits), and the real human intention (which evolved through using and seeing the system take shape). None of these is ground truth. The review must triangulate between all three.

---

## How to Use This Prompt

Feed this to your reviewing agent along with:
1. The codebase (or repo access)
2. All governing docs: spec, milestones, user journeys, feature inventory, steering docs
3. Any revision history or changelog if available

The review runs in **four sequential passes**. Pass 0 establishes the judgment framework. Passes 1-3 apply it. Each pass produces a structured artifact. Do NOT skip or reorder — the value is in the ground-truth-first ordering and the constitutional layer that precedes it.

---

## The Prompt

```
You are performing a coherence audit of an AI-authored project. The codebase has evolved beyond its original steering documents through multiple revision cycles. The spec itself has been revised and may contain internal contradictions. The feature inventory and user journeys may not fully agree.

Your job is NOT to mechanically check code against spec. Your job is to determine whether this system, as it actually exists, serves its core purpose — and to identify everything that prevents it from doing so, whether that's a code bug, a spec error, or a gap in the governing documents themselves.

You must exercise judgment. When code and spec disagree, do not automatically assume the spec is right. When a feature exists that the spec doesn't mention, do not automatically call it scope creep — the agent may have solved a real problem the spec didn't anticipate. When a spec feature is missing from code, do not automatically call it a gap — the revision history may have made it obsolete. Your role is to surface these as decision points with your reasoned assessment, not to mechanically flag mismatches.


## CONTEXT FILES
- [Insert or reference: spec, milestones, user journeys, feature inventory, steering docs, revision notes]
- [Insert or reference: codebase root / repo structure]

## ARCHITECTURE OVERVIEW
- **Backend**: [framework, language, entry points]
- **Data Tier**: YAML file repositories at [path(s)]
- **Frontend**: [framework, key views/routes]

---

## PASS 0: CONSTITUTIONAL LAYER (Establishing the Judgment Framework)

Before touching any code or spec, establish the foundational truths that will serve as tiebreakers throughout the review. These are derived from the governing documents but sit ABOVE them — they represent the intent behind the intent.

### 0A. Core Mission Statement
Distill the project's reason for existence into 3-5 sentences. Not features. Not architecture. Answer:
- Who is this for?
- What problem does it solve for them?
- What does success look like from the user's perspective?
- What is this project NOT? (What adjacent problems does it deliberately NOT solve?)

This becomes the supreme tiebreaker. When code and spec and journeys all disagree, the question is: "Which interpretation best serves this mission?"

### 0B. User Journey Intent Layer
For each user journey in the governing docs, write a ONE-SENTENCE intent statement. Not the steps — the outcome.

Journey: [Name]
Intent: [What the user accomplishes, in outcome terms]
Example: "A new user can onboard a data source and see results without editing config files."

These intent statements become the real acceptance criteria. A journey can pass every mechanical step check and still fail the intent. A journey can skip documented steps and still satisfy the intent through a better path the code discovered.

### 0C. Authority Hierarchy for Conflicts
Before you encounter conflicts (and you will), establish the resolution framework:

1. Where is the code more likely to reflect current intent than the spec?
   AI-authored code often evolves past the spec for pragmatic reasons — the agent encountered a real constraint and adapted. Identify areas where this is likely (e.g., data validation, error handling, edge cases the spec didn't anticipate, UI flows that simplified during implementation).

2. Where is the spec more likely to reflect intent than the code?
   Business logic, access control, and user-facing workflows are areas where the spec usually encodes deliberate human decisions that agents may have misunderstood or oversimplified.

3. Where are revisions aspirational vs. prescriptive?
   Review the revision history. Flag any spec revisions that read as "it would be nice if..." rather than "this must work." These should be treated as FUTURE scope, not MISSING features. If no revision history exists, use your judgment based on language — "should support" vs. "must support" vs. "will eventually support."

4. What is the minimum viable coherent product?
   Identify the subset of features and journeys that constitute the irreducible core. Everything else is negotiable. This prevents the review from treating a nice-to-have gap with the same severity as a broken core journey.

### 0D. AI-Authored Code Smell Catalog
Before starting the code review, prime yourself for the specific failure modes of AI-authored code:

- LOCAL COHERENCE, GLOBAL INCOHERENCE: Every function works, every endpoint returns the right shape, but the system doesn't add up to a product. Functions solve the immediate problem without considering how they compose.
- COMMENT-CODE DIVERGENCE: AI agents often copy comments from the spec then implement something slightly different. Do NOT trust comments — read the code.
- CONFIDENT STUBS: Unlike human TODO stubs, AI-authored stubs often look complete (proper types, error handling, reasonable return values) but do nothing real. A function that catches errors, logs them, and returns a default value may be a polished stub.
- NAMING COLLISIONS ACROSS LAYERS: The same concept called user_role in backend, userRole in frontend, role in YAML, access_level in the spec. All referring to the same thing. YAML won't complain.
- OVERCOMPLETE IMPLEMENTATIONS: Features implemented more thoroughly than the spec requires, often because the agent followed a pattern or tutorial rather than the spec. Not always wrong — sometimes it's better than the spec asked for.
- DEAD BRANCHES BEHIND CONDITIONS THAT NEVER FIRE: If/else branches or switch cases for states the system never enters. The agent anticipated possibilities the spec didn't define.
- CARGO-CULTED PATTERNS: The agent applied a pattern (middleware, decorators, factory classes, event systems) because it saw it elsewhere in the codebase, not because this use case needs it.
- HALLUCINATED DEPENDENCIES: Imports or API calls to libraries or services that don't exist or aren't installed.

---

## PASS 1: GROUND-TRUTH EXTRACTION (Code → Reality Map)

Build a factual inventory of what the code actually implements. Do not interpret intent. Do not reference the spec. Describe what exists and what it does.

### 1A. Backend Inventory
For each backend module/service/endpoint:
- Route/Entry Point: exact path, method, handler
- Business Logic: what it actually computes or orchestrates (read the code, not the comments or function names)
- Data Dependencies: which YAML files/schemas it reads or writes
- External Dependencies: APIs, services, libraries with version-sensitive behavior
- Auth/Access Control: what's enforced vs. what's stubbed/TODO vs. what's confidently stubbed (looks real but does nothing)
- Error Handling: what fails gracefully vs. what throws unhandled vs. what silently swallows errors

Produce a table:
| Module | Endpoints | YAML Dependencies | Status (complete/partial/stub/confident-stub) | Notes |

### 1B. Data Tier Inventory
For each YAML file or YAML schema:
- Schema: actual fields present, types (inferred if untyped), nesting structure
- Consumers: which backend modules read this, which fields they actually use
- Producers: which backend modules or tools write/generate this
- Validation: is the schema enforced anywhere? By what? Is validation consistent with actual usage?
- Orphan files: YAML files that exist but are never read by any code
- Phantom references: code that references YAML files or fields that don't exist
- Duplicate keys: YAML allows these silently — check for them
- Cross-file consistency: do YAML files that reference each other stay in sync?

Produce a dependency matrix:
| YAML File/Schema | Read By | Written By | Validated By | Orphan? | Issues |

### 1C. Frontend Inventory
For each view/route/component:
- Route: URL path and any params
- Data Sources: what API calls it makes, what state it reads
- User Actions: what the user can do on this view (buttons, forms, navigation, flows)
- Backend Coupling: which endpoints it depends on, what response shapes it expects
- Dead UI: components rendered but non-functional (empty handlers, TODO callbacks, disabled-but-visible controls)
- Unreachable UI: components that exist in the codebase but are not mounted in any route or layout

Produce a table:
| View/Route | API Dependencies | User Actions | Status (complete/partial/stub/unreachable) | Notes |

### 1D. Cross-Layer Dependency Graph
Produce a summary showing the full chain for each functional path:

Frontend View → API Call (method, path, expected shape) → Backend Handler → Business Logic → YAML Read/Write → Response Shape → Frontend Rendering

Flag:
- Broken chains: frontend calls endpoint that doesn't exist, backend reads YAML that's missing
- Shape mismatches: frontend expects fields the backend doesn't return (or vice versa)
- Silent dead ends: data is written to YAML but never read by anything, or computed but never returned to the frontend

---

## PASS 2: INTENT RECONCILIATION (Reality vs. Purpose)

Now compare the ground-truth inventory from Pass 1 against the governing documents AND the constitutional layer from Pass 0. This is where judgment matters most.

### 2A. Feature Coverage Matrix
For each feature in the feature inventory:

| Feature | Spec Status | Backend | Data Tier | Frontend | Verdict | Judgment |

Verdict categories:
- COMPLETE: All layers implemented and connected, serves the mission
- PARTIAL: Some layers done, gaps identified (describe what's missing)
- STUB: Skeleton exists but no real logic
- MISSING: Not implemented at all
- ORPHAN: Implemented but NOT in the feature inventory
- DIVERGENT: Implemented but behavior differs from spec
- SUPERSEDED: Spec describes this but a revision or the code has replaced it with something better

The Judgment column is critical. For every non-COMPLETE verdict, state:
- CODE IS RIGHT — the implementation is better than or has outgrown the spec; update the docs
- SPEC IS RIGHT — the implementation missed the intent; fix the code
- NEITHER IS RIGHT — both the spec and the code miss the actual need; surface for human decision with your recommendation
- DEFERRED — this was aspirational in the spec and is correctly absent from code for now
- AMBIGUOUS — you cannot determine intent; state both interpretations

Justify each judgment in one sentence referencing the core mission from Pass 0A.

### 2B. User Journey Trace (Intent-Aware)
For each user journey, first restate the intent from Pass 0B. Then trace the journey through the code.

Journey: [Name]
Intent: [One-sentence outcome from Pass 0B]

Step 1: [User action from journey doc]
  → Frontend: [what component handles this? does it exist?]
  → API call: [what gets called? does it exist?]
  → Backend: [what processes? correct behavior?]
  → Data: [what YAML is read/written? correct schema?]
  → Result: [what does the user actually see?]
  Step verdict: ✅ SERVES INTENT / ⚠️ WORKS BUT WRONG APPROACH / ❌ BROKEN / 🚫 NOT IMPLEMENTED

Journey-level verdict: Does this journey, as actually implemented, achieve the stated intent?
- YES: The user can accomplish what they came to accomplish
- PARTIALLY: The user gets part of the way there (describe where it falls apart)
- NO, BUT FIXABLE: The pieces exist but are misconnected
- NO, STRUCTURAL: The approach taken cannot serve this intent — needs rethinking, not patching
- BETTER THAN SPEC: The code achieves the intent through a better path than the journey doc describes

Do this for EVERY journey. The journey-level verdict is more important than the step-level verdicts.

### 2C. Milestone Reconciliation
For each milestone:
- What was promised?
- What was actually delivered (based on Pass 1)?
- What was added beyond scope? Was the addition justified? (Use mission from 0A)
- What was promised but absent? Was it deferred for good reason, or dropped accidentally?
- Does the milestone's definition of "done" match reality?

### 2D. Document Contradiction Register
List every instance where governing documents contradict each other or themselves:
- Two parts of the spec that are mutually exclusive
- A revision that overrides an earlier spec item but the old behavior persists in code
- Feature inventory items the user journeys never exercise
- User journeys that require features not in the feature inventory
- Milestones that declare something complete that Pass 2A marks PARTIAL or MISSING
- Places where the spec uses inconsistent terminology for the same concept

For each contradiction: state which side you believe reflects actual intent and why. Flag as DECISION REQUIRED if you genuinely cannot tell.

---

## PASS 3: COHERENCE ASSESSMENT & REMEDIATION

### 3A. Architectural Coherence
Assess whether the system hangs together as a unified product:

1. Naming Consistency: Are entities named the same thing across backend, YAML schemas, frontend, and docs? List every naming mismatch. For each, recommend the canonical name (the one closest to user-facing language).
2. Data Flow Integrity: Does data written by one component get read correctly by another? Format mismatches, missing fields, silent defaults, type coercions that lose information.
3. State Consistency: Can the system get into states that no code path handles? YAML data in a state the frontend doesn't render. Backend logic that produces output no frontend consumes. User actions that create data no backend flow processes.
4. API Contract Alignment: Do frontend calls match backend response shapes exactly? Field names, types, nullability, pagination, error format, empty states.
5. Error Propagation: When something fails at the data tier, does it surface meaningfully to the user? Or silently succeed with wrong data? Or show a generic error that prevents diagnosis?

### 3B. Dead Code & Scope Creep Assessment
List everything that exists in the code but serves no user journey and no spec requirement.

For each item, apply judgment — do NOT blindly recommend removal:
- KEEP: This serves the mission even though the docs don't mention it (explain why)
- KEEP AND DOCUMENT: This is valuable but needs to be added to the governing docs
- REMOVE: This is genuinely dead weight (explain why it exists — agent pattern-following, abandoned approach, etc.)
- DECIDE: Could be valuable or dead weight depending on product direction — flag for human decision with your recommendation

Categories to check:
- Unused endpoints
- Orphan YAML files
- Frontend components not reachable by any route
- Utility functions never called
- Configuration options nothing reads
- Feature flags with no toggle mechanism
- Overcomplete implementations (more thorough than needed — but maybe that's good?)

### 3C. Risk Register
Rank the top issues by severity, with judgment on each:

| # | Issue | Layer(s) | Impact | Judgment | Effort | Priority |

Impact categories:
- BLOCKING: Core user journey broken or unachievable
- DEGRADING: Feature works but incorrectly, partially, or in a way that undermines user trust
- INCOHERENT: System works but doesn't feel like one product (naming mismatches, inconsistent patterns, disorienting UX)
- DEBT: Works now but will cause problems at scale or during future changes
- SECURITY: Auth, validation, or access control gap
- COSMETIC: Visible inconsistency but not functionally impactful

### 3D. Remediation Plan
Group fixes into coherent work packages. For each package, state whether it's a code fix, a doc fix, or both.

1. CORE JOURNEY REPAIRS: Fixes required for every journey in Pass 2B that got a NO verdict. These are non-negotiable.
2. COHERENCE REPAIRS: Naming alignment, cross-layer contract fixes, state consistency gaps. These make the system feel like one product.
3. DOCUMENT RECONCILIATION: Spec sections, journey steps, and feature inventory entries that need to be updated to reflect reality — where reality is RIGHT and the docs are stale.
4. CODE RECONCILIATION: Code that needs to be updated to reflect the spec — where the spec is RIGHT and the code diverged.
5. DECISION QUEUE: Everything classified as DECIDE, AMBIGUOUS, or NEITHER IS RIGHT. Organized by dependency (decisions that block other decisions first). For each, state the options and your recommendation.
6. DEAD CODE REMOVAL: Items from 3B marked REMOVE, batched so removal doesn't break anything.
7. DRIFT PREVENTION: Validation, tests, or schema enforcement needed to prevent the same kinds of drift from recurring. Focus on the YAML tier — this is where untyped drift is most dangerous.

### 3E. Governing Document Revision List
Concrete list of updates needed, organized by document:

For each update, state:
- What currently says / is missing
- What it should say
- Why (reference the pass and section that identified the issue)
- Whether this is a correction (doc was wrong) or an evolution (doc was right at the time but reality has moved on)

---

## OUTPUT FORMAT

Produce all passes as a single structured document. Use tables where specified. Be specific — reference exact file paths, function names, endpoint paths, YAML keys.

For every judgment call, show your reasoning in one sentence. "I believe the code is right here because..." / "I believe the spec is right here because..." / "I cannot determine intent because..."

Where you are uncertain, say so explicitly and state both interpretations. Uncertainty is information. Fake confidence is noise.

The DECISION QUEUE in 3D.5 is arguably the most valuable output of this entire review — it tells the human exactly what questions remain that only they can answer, organized so they can answer them efficiently.

Total expected length: Be thorough. A comprehensive review that surfaces every structural issue and judgment call is more valuable than a concise one that misses the hard questions.
```

---

## Adaptation Notes

### For Very Large Codebases
If the codebase exceeds context limits, break the review into sub-passes by layer:
1. Run Pass 0 first — the constitutional layer must be established once and shared across all sub-passes
2. Run Pass 1A + 1B together (backend + data are tightly coupled)
3. Run Pass 1C separately (frontend)
4. Run Pass 1D as a synthesis pass with the outputs of 1A-1C as input
5. Run Pass 2 with all Pass 1 artifacts + Pass 0 as input
6. Run Pass 3 with everything above as input

### For Multi-Agent Review
If using multiple agents:
- **Agent A (Auditor)**: Runs Pass 1 — no access to spec, only code. Prevents confirmation bias. Also runs Pass 0D (AI smell catalog) against the code.
- **Agent B (Constitutionalist)**: Runs Pass 0A-0C — reads all governing docs and distills intent. No access to code. Cannot be influenced by what was actually built.
- **Agent C (Reconciler)**: Runs Pass 2 — gets Pass 0 + Pass 1 outputs + all spec docs. This agent must exercise judgment.
- **Agent D (Strategist)**: Runs Pass 3 — gets all prior outputs, produces the remediation plan and decision queue.

The separation between Agent A and Agent B is the most important. The auditor sees only reality. The constitutionalist sees only intent. The reconciler sees both and must judge.

### For Iterative Use
After remediation, re-run Pass 1 on the changed files only, then re-run the relevant Pass 2 journey traces to verify fixes. The Pass 1 tables become your regression baseline. Re-run Pass 0 only if the human has made decisions from the Decision Queue that change the core mission or journey intents.

### YAML-Specific Concerns
Since the data tier is YAML repos, these deserve special attention:
- **Schema drift**: YAML has no built-in schema enforcement. Are Pydantic models, JSON Schema, or validation scripts keeping schemas honest? If not, this is the single highest-risk area for silent drift.
- **Merge conflicts in YAML**: Multi-key YAML files are notorious for silent merge damage (duplicate keys, indent shifts that change nesting). Check for duplicate keys in all YAML files.
- **Anchor/alias integrity**: If YAML files use `&anchors` and `*aliases`, verify they resolve correctly and haven't been broken by partial edits.
- **Environment-specific overrides**: If YAML files have environment variants, verify all environments have consistent key coverage.
- **Cross-file referential integrity**: If YAML file A references an entity defined in YAML file B, verify B actually defines it and the reference format matches.
- **YAML as a database smell**: If the YAML repo has grown to the point where files reference each other extensively, have ordering dependencies, or require transactional updates, the data tier may have outgrown YAML. Flag this if observed — it's a structural issue, not a bug.
