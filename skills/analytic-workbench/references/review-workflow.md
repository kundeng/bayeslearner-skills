# Review Workflow Reference

The review workflow is how AI-produced analysis gets validated by a human. The
primary review surface is a **marimo notebook** — not JSON files. The human
reads, interacts with, and approves work through the notebook.

## Table of Contents
1. [The Notebook as Review Surface](#notebook-review)
2. [Review by Tier](#review-by-tier)
3. [Self-Review Expectations](#self-review)
4. [State Machine (Tier 3+)](#state-machine)
5. [Formal Workflow (Tier 3+)](#formal-workflow)
6. [Data Access Rules](#data-access)
7. [Narrative Rules](#narrative)
8. [When Full Formality Is Worth It](#when-formal)

---

## 1. The Notebook as Review Surface {#notebook-review}

The marimo notebook is the primary artifact the human reviews. It should:

- Show what ran (parameters, data sources, run IDs)
- Display key outputs (figures, tables, metrics)
- Include the AI's draft interpretation (in editable markdown cells)
- Provide comparison tables for multi-run experiments
- Allow drill-down into individual runs
- Be interactive — the human can adjust filters, select runs, explore

The human approval happens *through* the notebook interaction and conversation.
At Tier 1-2, no separate review files are needed. The notebook + conversation
*is* the review loop.

### Exploration notebook as review surface

When the AI produces or updates an exploration notebook, that notebook is itself
the review artifact. The human opens it, runs it, reads the AI's interpretation,
and either approves or gives feedback conversationally.

### Report notebook as review surface

For Tier 2+, the report notebook (`notebooks/report.py`) loads pre-computed
artifacts from `runs/` and presents them for review. The human selects runs,
compares metrics, and inspects figures — all within the notebook.

---

## 2. Review by Tier {#review-by-tier}

| Tier | Review surface | Approval mechanism |
|------|---------------|-------------------|
| **1** | Chat message with inline figures, or exploration notebook | Conversational ("looks good", "try X instead") |
| **2** | marimo report app + comparison table | Conversational, optionally card.md |
| **3** | marimo report app + formal review files | `approval.json` / `feedback.json` in `review/` |
| **4** | Orchestrator UI + notebook | CI/CD gates + human sign-off |

---

## 3. Self-Review Expectations {#self-review}

Before presenting any stage to the human, the AI verifies:

- Declared outputs exist and are non-empty in `runs/<run-id>/`
- Key metrics are plausible and internally consistent
- Figures are non-trivial and match the metrics summary
- No `NaN` or `Inf` values in important result columns
- Date ranges, row counts, or other coverage checks match the requested window
- Values in metrics match what the figures show visually

If blocking issues appear, fix them before presenting anything to the human.

At Tier 1-2, this is a mental checklist the AI runs before speaking.
At Tier 3+, write `review/<stage>/review.json` with pass/fail per check.

---

## 4. State Machine (Tier 3+) {#state-machine}

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

## 5. Formal Workflow (Tier 3+) {#formal-workflow}

Follow this sequence for each stale stage:

1. Run the stage (handwired Tier 1 run, Kedro pipeline, or DVC repro) and produce explicit outputs.
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

## 6. Data Access Rules {#data-access}

Use small CLI tools in `src/<project>/tools/` for external systems. Each tool
should:

- Accept `--output PATH`
- Accept `--format csv|json` or infer from extension
- Read credentials from `.env`
- Print diagnostics to stderr
- Exit non-zero on failure

This keeps data acquisition separate from the core computation layer.

---

## 7. Narrative Rules {#narrative}

The final report should read from saved artifacts only:

- `rawdata/` — immutable source data
- `runs/<run-id>/data/` — computed outputs
- `runs/<run-id>/figures/` — visual artifacts
- `review/<stage>/approval.json` — approved interpretation text (Tier 3+)

Always materialize:

- per-run artifact folders under `runs/`
- machine-readable summaries (`metrics.json`)
- comparison tables (`runs/comparison.csv`)
- report-ready figures and tables

---

## 8. When Full Formality Is Worth It {#when-formal}

Use the full Tier 3+ review workflow when:

- Multiple runs need to be compared over time
- The human wants explicit approval checkpoints
- The AI is advancing the project stage by stage
- Results will feed a polished report or decision memo

If the work is still lightweight, keep the same logic but do it conversationally
with the notebook as the shared review surface.
