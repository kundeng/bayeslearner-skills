# marimo Patterns Reference

marimo is the **frontend layer** of the analytic workbench. It owns display,
interactivity, and layout. For complex computations, it's recommended to keep
business logic in reusable Python modules under `src/<project>/analysis/`.

Notebooks live in `notebooks/` at the project root — outside `src/`.

## Table of Contents
1. [Philosophy: marimo as Frontend](#philosophy)
2. [Notebook Structure](#notebook-structure)
3. [Interactive Exploration (`explore`+)](#interactive-exploration)
4. [Report App (`experiment`+)](#report-app)
5. [UI Elements for Parameter Tuning](#ui-elements)
6. [State and Stateful Interactions](#state)
7. [Script Mode and CLI Arguments](#script-mode)
8. [App Deployment](#app-deployment)
9. [Integration with Hamilton and Analysis Modules](#integration)
10. [Displaying Artifacts](#displaying-artifacts)
11. [Anti-Patterns](#anti-patterns)

---

## 1. Philosophy: marimo as Frontend {#philosophy}

A recommended best practice: **marimo displays, computation modules compute.**

Compatibility rule:

- Notebook surfaces should survive later-mode wiring upgrades.
- `experiment` should not require moving business logic back into notebooks.
- A notebook should be able to call the same reusable functions whether config
  comes from widget values, plain files, or Hydra-composed config.

A well-structured marimo notebook can:

- Gather parameters from UI widgets
- Call reusable module functions directly at `explore`/`experiment`, or load
  pipeline-produced artifacts in later modes
- Display those results (figures, tables, metrics, markdown)

Alternatively, a marimo notebook can directly call reusable functions from
analysis modules, or import and execute pure Python logic. The key principle is
to prefer keeping heavy computation, transforms, and business logic **outside**
the notebook, rather than embedding it in notebook cells.

While it's useful to avoid computation in cells, there are cases where inline
examples or small exploratory calculations in a notebook make sense (e.g.,
illustrating a concept, quick interactive prototyping). The spirit of the rule
is: **if computation is meant to be reused, tested, or long-lived, it belongs
in a module.**

---

## 2. Notebook Structure {#notebook-structure}

marimo notebooks are plain Python files. Each cell is a function decorated with
`@app.cell`, and marimo determines execution order from variable dependencies,
not from top-to-bottom position in the file.

```python
# notebooks/explore.py
import marimo

__generated_with = "0.11.0"
app = marimo.App(width="medium")


@app.cell
def _():
    import marimo as mo
    import pandas as pd
    import matplotlib.pyplot as plt
    from pathlib import Path
    return mo, pd, plt, Path


@app.cell
def _(mo):
    mo.md("# Interactive Exploration")
    return


@app.cell
def _(pd, Path):
    data_path = Path("rawdata/incidents.csv")
    df = pd.read_csv(data_path, parse_dates=["opened_at"])
    df
    return df, data_path


@app.cell
def _(df, mo):
    preview = mo.ui.slider(10, 100, value=25, step=5, label="Preview rows")
    preview
    return preview,


@app.cell
def _(df, preview):
    df.head(preview.value)
    return


if __name__ == "__main__":
    app.run()
```

**Key rules:**

- Each cell is a function; referenced return values become dependencies.
- The last expression is displayed automatically.
- Keep imports in a dedicated cell and return them.
- Return only the variables later cells should depend on.
- Put reusable logic in modules; keep notebooks as orchestration and review
  surfaces.

**Validation rules:**

- A notebook is not "validated" just because Python syntax parses or `import
  marimo` succeeds.
- Prefer verifying the notebook through marimo execution paths rather than
  private/internal marimo APIs.
- Treat `__generated_with` as informational, not proof that your current runtime
  behaves the same way as the version that generated the file.
- When fixing a notebook bug, confirm the actual user-facing failure mode first
  (cell error, missing file, bad cwd, variable redefinition, widget mismatch),
  then patch only that issue.

---

## 3. Interactive Exploration (`explore`+) {#interactive-exploration}

When a UI element changes, marimo re-runs only the cells that depend on that
widget's `.value`. The common pattern is: controls -> filtered data -> derived
metrics -> charts.

```python
@app.cell
def _(mo):
    freq = mo.ui.dropdown(
        options=["15min", "1h", "4h"],
        value="1h",
        label="Resample frequency",
    )
    priority = mo.ui.multiselect(
        options=["P1", "P2", "P3", "P4"],
        value=["P1", "P2"],
        label="Priority filter",
    )
    mo.hstack([freq, priority])
    return freq, priority


@app.cell
def _(df, priority):
    filtered = df[df["priority"].isin(priority.value)]
    filtered
    return filtered,


@app.cell
def _(filtered, freq, pd):
    ts = (
        filtered
        .set_index("opened_at")
        .resample(freq.value)
        .size()
        .rename("incident_count")
        .reset_index()
    )
    ts
    return ts,


@app.cell
def _(ts, mo):
    mo.stop(ts.empty, mo.md("No data for the current filter selection."))
    return


@app.cell
def _(ts, plt, freq):
    fig, ax = plt.subplots(figsize=(12, 4))
    ax.plot(ts["opened_at"], ts["incident_count"], linewidth=1.0)
    ax.set_title(f"Incident Count by {freq.value}")
    ax.set_ylabel("Count")
    fig
    return
```

Useful pattern: guard expensive or invalid downstream work with `mo.stop(...)`
so empty selections fail fast and the notebook stays readable.

---

## 4. Report App (`experiment`+) {#report-app}

The report app loads pre-computed artifacts from `runs/`. It does **no
computation** — only display and navigation.

```python
# notebooks/report.py
import marimo

app = marimo.App(width="full")


@app.cell
def _():
    import marimo as mo
    import pandas as pd
    import json
    from pathlib import Path
    return mo, pd, json, Path


@app.cell
def _(mo):
    mo.md("# Experiment Comparison Report")
    return


@app.cell
def _(mo, pd, Path):
    args = mo.cli_args()
    runs_root = Path(args.get("runs_dir", "runs"))
    # Load comparison table
    comp_path = runs_root / "comparison.csv"
    if comp_path.exists():
        comparison = pd.read_csv(comp_path)
    else:
        comparison = pd.DataFrame({"status": ["No comparison table found"]})
    comparison
    return comparison, runs_root


@app.cell
def _(mo, comparison):
    run_selector = None
    if "run_id" in comparison.columns:
        run_selector = mo.ui.dropdown(
            options=comparison["run_id"].tolist(),
            label="Inspect run",
        )
        run_selector
    return run_selector,


@app.cell
def _(run_selector, runs_root, json, mo):
    mo.stop(run_selector is None, mo.md("No comparison table with `run_id` found."))
    run_dir = runs_root / run_selector.value
    if not run_dir.exists():
        mo.md("Run directory not found")
    else:
        # Show metrics
        metrics_path = run_dir / "metrics.json"
        if metrics_path.exists():
            metrics = json.loads(metrics_path.read_text())
            mo.tree(metrics)

        # Show figures
        figs = sorted((run_dir / "figures").glob("*.png"))
        if figs:
            mo.vstack([mo.image(src=str(f)) for f in figs])
    return
```

Pattern: computation happens in pipeline scripts; app mode is for selection,
inspection, and approval.

Additional report-app rules:

- Do not hardcode a single `run_id` unless the user explicitly wants a fixed
  report for one run. Prefer a selector, CLI arg, or clearly declared default.
- Resolve artifact paths carefully. marimo may be launched from a directory
  other than the notebook's parent, so naive relative paths often break.
- If data was pulled from a live external system, describe it as a run snapshot
  rather than immutable raw input.

---

## 5. UI Elements for Parameter Tuning {#ui-elements}

Use widgets to expose the parameters humans actually need to inspect. Favor a
small control surface over a notebook full of hidden constants.

```python
@app.cell
def _(mo):
    threshold = mo.ui.slider(0.0, 10.0, value=3.0, step=0.1, label="Threshold")
    window = mo.ui.number(6, 336, value=72, step=6, label="Window (hours)")
    normalize = mo.ui.checkbox(label="Normalize counts", value=True)
    metric = mo.ui.dropdown(
        options=["count", "mean_duration", "assignment_changes"],
        value="count",
        label="Metric",
    )
    lookback = mo.ui.text(value="-30d", label="Lookback window")

    controls = mo.vstack([
        mo.md("## Controls"),
        mo.hstack([threshold, window]),
        mo.hstack([normalize, metric]),
        lookback,
    ])
    controls
    return threshold, window, normalize, metric, lookback
```

Other common workbench widgets:

```python
# Date selection
mo.ui.date(label="Start date")

# Free text for paths or search filters
mo.ui.text(value="rawdata/events.csv", label="Input path")

# Longer analyst notes or adhoc query fragments
mo.ui.text_area(label="Notes")

# Layout
mo.hstack([slider, dropdown, checkbox])  # horizontal
mo.vstack([chart1, chart2])              # vertical
mo.tabs({"Overview": tab1, "Details": tab2})  # tabbed
mo.accordion({"Section A": content_a})   # collapsible
```

Pattern: keep widgets in one cell, derived parameters in another cell, and
heavy computation downstream. That makes dependency flow obvious.

---

## 6. State and Stateful Interactions {#state}

For interactions that need to persist across reactive updates (selections,
accumulated results, user annotations), use `mo.state()`:

```python
@app.cell
def _(mo):
    get_selected, set_selected = mo.state([])
    return get_selected, set_selected


@app.cell
def _(mo, comparison, set_selected):
    # Table with row selection
    table = mo.ui.table(
        comparison,
        selection="multi",
        on_change=lambda rows: set_selected(rows),
    )
    table
    return table,


@app.cell
def _(get_selected, mo):
    selected = get_selected()
    if selected:
        mo.md(f"**{len(selected)} runs selected** for detailed comparison")
    return selected,
```

Use `mo.state()` sparingly — most interactions work through reactive widget
values without explicit state.

---

## 7. Script Mode and CLI Arguments {#script-mode}

The same notebook can support both browser-based exploration and batch-style
execution. This is useful when a marimo notebook is also the review surface for
Kedro runs, DVC stages, or CI-produced artifacts.

```bash
# Launch the notebook UI
marimo edit notebooks/explore.py

# Execute non-interactively
marimo run notebooks/explore.py

# Pass arguments through to mo.cli_args()
marimo run notebooks/explore.py -- --freq 4h --window 168 --priority P1
```

Access CLI arguments inside a cell:

```python
@app.cell
def _(mo):
    args = mo.cli_args()
    freq = args.get("freq", "1h")
    window = int(args.get("window", "72"))
    priority = args.get("priority", "P1")
    return args, freq, window, priority

@app.cell
def _(mo, freq, window, priority):
    mo.md(
        f"Running with `freq={freq}`, `window={window}`, `priority={priority}`"
    )
    return
```

Pattern: use CLI args for batch defaults, but still expose widgets in notebook
mode so an analyst can override and inspect results interactively.

For run-backed report notebooks, a good default is:

- accept `--run-id` through CLI args
- fall back to a visible notebook-level default
- render a clear error if the target run directory or expected files are missing
- never silently substitute another dataset

---

## 8. App Deployment {#app-deployment}

marimo notebooks can be deployed as standalone web apps:

```bash
# Local app server
marimo run notebooks/report.py --host 0.0.0.0 --port 8080

# Hide code, show only outputs
marimo run notebooks/report.py --include-code false
```

For the workbench, the report app is the primary deployment target. It reads
from `runs/` and presents the comparison table, per-run drill-down, and
figures. The human reviews here; the AI reviews programmatically.

---

## 9. Integration with Hamilton and Analysis Modules {#integration}

marimo serves as both **authoring surface** and **review surface** for
Hamilton-based analysis. The integration works across all modes.

### Probe: authoring Hamilton functions in marimo cells

At `probe`, define functions with Hamilton naming discipline directly in
marimo cells. Use `ad_hoc_utils.create_temporary_module()` to wrap them into
a Hamilton DAG on the fly — no files, no project structure, instant
visualization.

```python
@app.cell
def _():
    import pandas as pd

    def raw_data(raw_data_path: str) -> pd.DataFrame:
        return pd.read_csv(raw_data_path, parse_dates=True)

    def timeseries_hourly(raw_data: pd.DataFrame, resample_freq: str) -> pd.Series:
        return raw_data.resample(resample_freq).size()

    def summary_stats(timeseries_hourly: pd.Series) -> dict:
        return {"mean": timeseries_hourly.mean(), "total": timeseries_hourly.sum()}

    return raw_data, timeseries_hourly, summary_stats


@app.cell
def _(raw_data, timeseries_hourly, summary_stats):
    from hamilton import ad_hoc_utils, driver

    temp_module = ad_hoc_utils.create_temporary_module(
        raw_data, timeseries_hourly, summary_stats,
        module_name="probe_baseline",
    )
    dr = driver.Builder().with_modules(temp_module).build()
    dr.display_all_functions()  # human sees the DAG immediately
    return dr,


@app.cell
def _(dr):
    results = dr.execute(
        ["summary_stats", "timeseries_hourly"],
        inputs={"raw_data_path": "rawdata/events.csv", "resample_freq": "1h"},
    )
    results["summary_stats"]
    return results,
```

The notebook is the authoring tool — functions are written in cells. It is
simultaneously the review surface — the human sees the DAG and results inline.
When the human approves and promotes to `explore`, the functions move to
`src/<project>/analysis/baseline.py` **unchanged**.

### Explore+: importing Hamilton modules

At `explore` and beyond, functions live in modules. The notebook imports and
runs them via the Hamilton Driver.

```python
@app.cell
def _():
    import importlib
    from hamilton import driver
    import my_project.analysis.baseline as baseline

    importlib.reload(baseline)
    dr = driver.Builder().with_modules(baseline).build()
    dr.display_all_functions()
    return dr, baseline


@app.cell
def _(dr, freq, priority):
    results = dr.execute(
        ["summary_stats", "timeseries_hourly"],
        inputs={"raw_data_path": "rawdata/events.csv",
                "resample_freq": freq.value},
    )
    return results,


@app.cell
def _(results, mo):
    mo.tree(results["summary_stats"])
    return
```

The transition from probe to explore is a one-line change: replace
`ad_hoc_utils.create_temporary_module(...)` with `import baseline`.

### Presentation patterns

Two good patterns for workbenches:

```python
# Keep notebook-only presentation logic local
@app.cell
def _(results, mo):
    stats = results["summary_stats"]
    mo.md(f"**Total count:** {stats['total']:,.0f} | **Mean:** {stats['mean']:.1f}")
    return

# Put reusable data logic in modules — never in cells
# The module functions are the same whether called from
# marimo, a Hydra runner, or an orchestrator task.
```

When the module changes, rerun the notebook and re-evaluate the outputs. The
notebook renders Hamilton's outputs; the module holds the computation.

---

## 10. Displaying Artifacts {#displaying-artifacts}

marimo handles common analysis outputs directly, so the clean pattern is to
return data objects from cells and let the notebook render them.

```python
# DataFrames render as interactive tables
comparison.head(20)

# Markdown for analyst commentary
mo.md(f"**Total incidents:** {len(df):,}")

# Dicts / JSON-like objects render as inspectable structures
metrics

# Matplotlib figures display when they are the last expression
fig, ax = plt.subplots(figsize=(10, 3))
ax.plot(ts.index, ts.values)
ax.set_title("Hourly incidents")
fig

# Images from previous pipeline stages
mo.image(src="runs/figures/anomalies.png")

# Compose multiple outputs into one review surface
mo.vstack([
    mo.hstack([summary_table, diagnostics_table]),
    fig,
    mo.md("### Analyst Notes"),
    notes,
])
```

Pattern: use plain Python objects as the interface between cells. Keep file I/O
at the edges, metrics in structured dicts/DataFrames, and final review surfaces
composed with `mo.hstack`, `mo.vstack`, and `mo.tabs`.

---

## 11. Anti-Patterns {#anti-patterns}

**Computation in cells.** Prefer to move pandas transforms, statistical
calculations, or model fitting code to `src/<project>/analysis/` modules and
call them through the notebook. If you find yourself writing more than a few
lines of non-display code in a cell, it belongs in a module.

**Syntax-only validation.** `ast.parse`, import checks, or library version
prints do not prove that a marimo notebook actually runs. Validate the notebook
through marimo-visible execution behavior before telling the user it is ready.

**Using internal marimo APIs as contracts.** Private classes and methods may
disappear between versions. Avoid building workflow guidance around internal
APIs.

**Direct data loading everywhere.** While it's sometimes acceptable to load data
in a notebook cell for exploration, create a reusable function in an analysis
module so the loading logic can be tested and reused. Prefer resolving input
paths from an explicit base directory, CLI arg, or clearly declared notebook
constant rather than assuming the notebook's working directory.

**Assuming notebook cwd.** Paths that work when the agent runs a file from repo
root may fail when marimo launches from elsewhere. Make run/artifact resolution
explicit and user-visible.

**Variable redefinition across cells.** marimo's graph model expects one clear
binding path. Reusing the same variable name in multiple cells creates confusing
cell errors and makes dependency flow harder to reason about.

**Fat notebooks.** If your notebook has more than ~20 cells, it's likely doing
too much. Split into separate notebooks (explore, report) or move logic to
modules.

**Mixing explore and report.** Keep exploration notebooks (that run live
computation) separate from report notebooks (that load pre-computed artifacts).
They serve different purposes and different audiences.
