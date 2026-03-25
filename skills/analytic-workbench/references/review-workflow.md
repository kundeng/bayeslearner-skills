# Review Workflow Reference

The review workflow is how AI-produced analysis gets validated by a human. The
preferred review surface is a **marimo notebook**, with **Quarto** as the
default fallback when the work needs a staged narrative document, shareable
HTML/PDF, or a document-first EDA surface. The human reads, interacts with, and
approves work through the chosen surface.

## Table of Contents
1. [The Notebook as Review Surface](#notebook-review)
2. [Review by Mode](#review-by-mode)
3. [Runbook as Review Surface](#runbook)
4. [Self-Review Expectations](#self-review)
5. [State Machine (formal review)](#state-machine)
6. [Formal Workflow (formal review)](#formal-workflow)
7. [Data Access Rules](#data-access)
8. [Narrative Rules](#narrative)
9. [When Full Formality Is Worth It](#when-formal)

---

## 1. The Review Surface {#notebook-review}

The chosen review surface should:

- Show what ran (parameters, data sources, run IDs)
- Display key outputs (figures, tables, metrics)
- Include the AI's draft interpretation (in editable markdown cells)
- Provide comparison tables for multi-run experiments
- Allow drill-down into individual runs
- Be interactive enough for the mode: live controls in marimo, or structured
  staged sections in Quarto

The human approval happens *through* the notebook interaction and conversation.
At `explore` and early `experiment`, no separate review files are needed. The notebook + conversation
*is* the review loop.

### Surface choice

Prefer marimo when the human needs to adjust filters, choose runs, or explore
artifacts interactively. Prefer Quarto when the human needs a staged EDA
document, decision memo, or polished report artifact that reads clearly from top
to bottom.

### Exploration notebook as review surface

When the AI produces or updates an exploration notebook, that notebook is itself
the review artifact. The human opens it, runs it, reads the AI's interpretation,
and either approves or gives feedback conversationally.

### Exploration report as review surface

When the AI uses Quarto for exploration, the `.qmd` file and its rendered HTML
become the review artifact. The document should make the workflow legible:

- question and scope
- data source and acquisition notes
- EDA steps performed
- findings discovered so far
- open questions and caveats
- recommended next step

### Report notebook as review surface

For `experiment`+, the report notebook (`notebooks/report.py`) loads pre-computed
artifacts from `runs/` and presents them for review. The human selects runs,
compares metrics, and inspects figures — all within the notebook.

---

## 2. Review by Mode {#review-by-mode}

| Mode | Review surface | Approval mechanism |
|------|---------------|-------------------|
| **`explore`** | Chat message with inline figures, exploration notebook, or Quarto EDA doc | Conversational ("looks good", "try X instead") |
| **`experiment`** | marimo report app or Quarto report + comparison table | Conversational, optionally card.md |
| **`experiment` (formal)** | marimo report app or Quarto report + formal review files | `approval.json` / `feedback.json` in `review/` |
| **`operate`** | Orchestrator UI + notebook/report | CI/CD gates + human sign-off |

---

## 3. Runbook as Reviewability Artifact {#runbook}

The repo-level runbook (`runbook.md` at the project root) is the reproduction
guide for the entire pipeline. It is generated at promote time — not maintained
as a running log — by reading the project structure: configs, scripts,
notebooks, runs, and directory layout.

The runbook answers: "I just cloned this repo. How do I reproduce everything
from scratch?" It is the primary reviewability artifact because a human who can
reproduce the pipeline can verify any claim in it.

### What makes a good runbook

See `SKILL.md § Runbook` for the full specification. Key sections:

1. **Prerequisites** — env setup, data acquisition, external tools
2. **Pipeline overview** — ASCII diagram of the data flow
3. **Numbered steps** — one per major pipeline step, each with the exact
   command, expected runtime, and what to inspect afterward (including expected
   results so the human knows what "correct" looks like)
4. **Configuration reference** — table of config files and what they control
5. **Key directories** — paths, contents, git-tracked or not
6. **Troubleshooting** — known failure modes and fixes

### When to generate or update

- At stage promotion (`promote`)
- When the user asks for a handoff document
- When the pipeline structure changes materially (new scripts, new configs,
  new data sources)

The runbook is not an append-only log. When the pipeline changes, rewrite
the affected sections to match current state.

### Relationship to the review surface

The notebook or Quarto report is where the human *inspects results*. The
runbook is where the human *understands how those results were produced*. Both
are needed for a complete review:

- Runbook → "how to get from raw data to these artifacts"
- Notebook/report → "what do the artifacts show and what do they mean"

During `review`, summarize the runbook's pipeline steps in chat so the
human can see the reproduction path without opening a file. The full runbook
lives at the repo root for detailed reference.

---

## 4. Self-Review Expectations {#self-review}

Before presenting any step to the human, the AI verifies:

- Declared outputs exist and are non-empty in `runs/<run-id>/`
- Key metrics are plausible and internally consistent
- Figures are non-trivial and match the metrics summary
- No `NaN` or `Inf` values in important result columns
- Date ranges, row counts, or other coverage checks match the requested window
- Values in metrics match what the figures show visually

If blocking issues appear, fix them before presenting anything to the human.

At `explore` and early `experiment`, this is a mental checklist the AI runs before speaking.
With formal review, write `review/<stage>/review.json` with pass/fail per check.

During EDA, do not wait for the end of the run to report discoveries. Provide
interim updates whenever a meaningful step completes. A good interim update
contains:

- step attempted
- artifact or query produced
- concrete result
- caveat or uncertainty
- next action

---

## 5. State Machine (formal review) {#state-machine}

Every stage moves through a lifecycle:

```
STALE -> EXECUTED -> REVIEWED -> APPROVED
                 \-> REJECTED -> STALE
```

Rules:

- Never update a report with results from a stage that is not approved.
- Always self-review before presenting outputs to the human.
- Human approval covers both artifacts and interpretation text.
- Never overwrite an approved run; supersede it with a newer run.

---

## 6. Formal Workflow (formal review) {#formal-workflow}

Follow this sequence for each stale stage:

1. Run the stage (handwired `explore` run, Kedro pipeline, or DVC repro) and produce explicit outputs.
2. Write `review/<stage>/manifest.json` describing params, inputs, outputs.
3. Run self-review checks.
4. Write `review/<stage>/review.json`.
5. Draft `review/<stage>/card.md` for human review.
6. Present the card and recommendation (or update the report notebook).
7. If approved, write `review/<stage>/approval.json` and only then update the
   narrative.
8. If rejected, write `review/<stage>/feedback.json`, incorporate feedback,
   re-run.

For exact schemas, see `core-contracts.md`. These schemas are recommended
starting points — add or omit fields as your project needs.

---

## 7. Data Access Rules {#data-access}

Use small CLI tools in `src/<project>/tools/` for external systems. Each tool
should:

- Accept `--output PATH`
- Accept `--format csv|json` or infer from extension
- Read credentials from `.env`
- Print diagnostics to stderr
- Exit non-zero on failure

This keeps data acquisition separate from the core computation layer.

Rule of thumb: the first live data pull is part of the pipeline, not just a
setup chore. If the agent expects to rerun it, explain it, test it, or hand it
to the human later, it should exist as a reusable command, stage, or tool
rather than as an inline ad hoc snippet in chat.

---

## 8. Narrative Rules {#narrative}

The final report should read from saved artifacts only:

- `rawdata/` — immutable source data
- `runs/<run-id>/data/` — computed outputs
- `runs/<run-id>/figures/` — visual artifacts
- `review/<stage>/approval.json` — approved interpretation text (formal review)

Always materialize:

- per-run artifact folders under `runs/`
- machine-readable summaries (`metrics.json`)
- comparison tables (`runs/comparison.csv`)
- report-ready figures and tables

For EDA-stage work, also materialize a lightweight progress artifact when
useful, such as:

- `runs/<run-id>/notes.md`
- `runs/<run-id>/eda_summary.json`
- `reports/eda.qmd`

---

## 9. When Full Formality Is Worth It {#when-formal}

Use the full formal review workflow when:

- Multiple runs need to be compared over time
- The human wants explicit approval checkpoints
- The AI is advancing the project stage by stage
- Results will feed a polished report or decision memo

If the work is still lightweight, keep the same logic but do it conversationally
with the notebook as the shared review surface.
