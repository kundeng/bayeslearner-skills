# Module Conventions Reference

Analysis modules are **pure Python functions** following a DAG-friendly naming
discipline. The conventions produce readable, testable, DAG-shaped code that
works with the handwired driver (`explore`/`experiment`) and slots directly into Kedro
pipelines when needed.

## Table of Contents
1. [Core Rules](#core-rules)
2. [Naming Discipline](#naming)
3. [The Handwired Driver (`explore`)](#handwired-driver)
4. [Module Layout](#module-layout)
5. [Data Loading](#data-loading)
6. [Figures and Artifacts](#figures)
7. [Testing](#testing)
8. [Transition to Kedro](#kedro-transition)
9. [Anti-Patterns](#anti-patterns)

---

## 1. Core Rules {#core-rules}

Every function in `src/<project>/analysis/` follows these rules:

- **Function name = output name.** `timeseries_hourly` produces `timeseries_hourly`.
- **Parameter names = dependency names.** If a function takes `raw_data`, it
  depends on whatever produces `raw_data`.
- **Type hints on everything.** Parameters and return types are always annotated.
- **Pure functions.** No side effects, no global state, no file I/O inside
  business logic (except explicit data loaders at the DAG boundary).
- **Small, output-oriented functions.** Each function produces one named thing.
  Prefer many small functions over fewer large ones.
- **Helper functions prefixed with `_`.** Private helpers that aren't DAG nodes
  start with `_`. This keeps the public API clean and makes the public graph
  surface obvious.

Compatibility rule:

- Later modes may change wiring, config injection, caching, or orchestration,
  but they should preserve the computation contract established here.
- Functions in `analysis/` should not depend on notebook widget state, Hydra
  objects, Kedro context, or other mode-specific runtime objects.

---

## 2. Naming Discipline {#naming}

The function name is the public API of the module. Choose names that describe
*what the function produces*, not what it does internally.

```python
# Good: name describes the output
def timeseries_hourly(raw_data: pd.DataFrame, resample_freq: str) -> pd.Series:
    ...

def summary_stats(timeseries_hourly: pd.Series) -> dict[str, float]:
    ...

def anomaly_scores(timeseries_hourly: pd.Series, window_size: int) -> pd.Series:
    ...

# Bad: name describes the action, not the output
def process_data(df: pd.DataFrame) -> pd.DataFrame:
    ...

def run_analysis(ts: pd.Series, params: dict) -> dict:
    ...
```

Key consequences:

- The dependency graph is readable from function signatures alone.
- `summary_stats` depends on `timeseries_hourly` because it takes a parameter
  named `timeseries_hourly`.
- Parameters that don't match any function name are runtime inputs (config
  values, file paths, etc.).

---

## 3. The Driver (`explore`) {#handwired-driver}

At `explore`, the **Hamilton Driver** is the recommended way to execute your
analysis modules. Because the naming discipline above is Hamilton's programming
model, switching from a handwired driver to Hamilton is a wiring change — the
analysis functions stay identical. See `references/hamilton-guide.md` for full
details.

### Hamilton Driver (recommended)

```python
# src/my_project/scripts/run.py
"""Hamilton driver — automatic DAG resolution from module functions."""
from pathlib import Path
import json
import yaml
from hamilton import driver
from my_project.analysis import baseline

def run(params: dict, output_dir: str) -> dict:
    """Execute analysis pipeline and save artifacts."""
    out = Path(output_dir)
    out.mkdir(parents=True, exist_ok=True)
    (out / "figures").mkdir(exist_ok=True)
    (out / "data").mkdir(exist_ok=True)

    dr = driver.Builder().with_modules(baseline).build()

    # Hamilton resolves the DAG and executes only what's needed
    results = dr.execute(
        ["summary_stats", "timeseries_hourly", "timeseries_figure"],
        inputs=params,
    )

    # Save artifacts
    results["timeseries_hourly"].to_csv(out / "data" / "timeseries.csv")
    results["timeseries_figure"].savefig(out / "figures" / "fig-timeseries.png", dpi=150)
    json.dump(results["summary_stats"], open(out / "metrics.json", "w"), indent=2)
    with open(out / "config.yaml", "w") as f:
        yaml.dump(params, f)

    # Visualize the execution graph for review
    dr.visualize_execution(
        ["summary_stats", "timeseries_figure"],
        out / "figures" / "dag-execution.png",
    )

    return results["summary_stats"]


if __name__ == "__main__":
    params = {
        "raw_data_path": "rawdata/events.csv",
        "date_column": "opened_at",
        "resample_freq": "1h",
    }
    run(params, "runs/manual_001")
```

Why Hamilton over handwired:

- **Automatic DAG resolution** — no manual call ordering to maintain
- **Selective execution** — request only the nodes you need
- **Visualization** — DAG images are the cheapest review artifact
- **Caching** — add `.with_cache()` to skip redundant computation across reruns
- All I/O still happens in the driver, not in analysis functions
- This driver defines a stable boundary that later stages preserve

### Handwired fallback

If Hamilton is unavailable or the project is too small to justify a dependency,
a plain Python driver is acceptable:

```python
# Handwired driver — calls analysis functions in DAG order manually.
df = raw_data(raw_data_path=params["raw_data_path"])
ts = timeseries_hourly(raw_data=df, date_column=params["date_column"], resample_freq=params["resample_freq"])
stats = summary_stats(timeseries_hourly=ts)
```

The handwired driver works because the naming discipline makes the call order
obvious. But as the DAG grows, manual ordering becomes error-prone and you
lose visualization and caching. Prefer Hamilton.

---

## 4. Module Layout {#module-layout}

```
src/
  my_project/
    __init__.py
    analysis/
      __init__.py
      baseline.py          # time series construction
      features.py          # feature engineering
      models.py            # model fitting (if applicable)
      evaluation.py        # metrics and scoring
      data_loader.py       # freshness-aware data loading
    scripts/
      run.py               # Handwired driver (`explore`/`experiment`) or Kedro runner
      build_comparison.py  # Sweep comparison table builder
    tools/
      fetch_data.py        # Data access CLI
```

Group functions by domain or pipeline stage. One module per logical stage.
Keep modules focused — if a module has more than ~10 public functions, split it.

---

## 5. Data Loading {#data-loading}

Data loading is a function like any other — it produces a named output.

```python
def raw_data(raw_data_path: str) -> pd.DataFrame:
    """Load raw data from CSV."""
    return pd.read_csv(raw_data_path, parse_dates=True)
```

For live systems, separate **acquisition** from **loading**:

- acquisition belongs in `src/<project>/tools/` or an explicit pipeline stage
- loading belongs in `src/<project>/analysis/` as functions that read saved data
- notebooks and reports should call the reusable loader, not embed fetch logic

Bad pattern:

- a notebook cell or chat reply that directly calls the API and then tells the
  human to rerun the snippet later

Preferred pattern:

- `python -m my_project.tools.fetch_data --output runs/<run-id>/data/source.parquet`
- analysis modules load the saved artifact
- reports read only saved artifacts

For freshness-aware loading, use helper functions prefixed with `_`:

```python
def _is_fresh(data_path: str, freshness_hours: int = 48) -> bool:
    """Check if cached data is still fresh enough to reuse."""
    meta_path = Path(data_path).with_suffix(".meta.json")
    if not meta_path.exists() or not Path(data_path).exists():
        return False
    meta = json.loads(meta_path.read_text())
    fetched = datetime.fromisoformat(meta["fetched_at"])
    return datetime.now(timezone.utc) - fetched < timedelta(hours=freshness_hours)


def raw_data_cached(raw_data_path: str, freshness_hours: int) -> pd.DataFrame:
    """Load cached data if fresh, otherwise raise."""
    if _is_fresh(raw_data_path, freshness_hours):
        return pd.read_csv(raw_data_path)
    raise FileNotFoundError(
        f"Data at {raw_data_path} is stale or missing. "
        f"Run: python -m my_project.tools.fetch_data --output {raw_data_path}"
    )
```

If the acquisition step is expensive or reused across runs, escalate it into a
first-class stage rather than a hidden helper. The agent should tell the human
that this promotion is happening and why.

---

## 6. Figures and Artifacts {#figures}

Functions return figure objects. They never save to disk.

```python
def timeseries_figure(
    timeseries_hourly: pd.Series,
    resample_freq: str,
) -> "matplotlib.figure.Figure":
    """Create a time series plot."""
    import matplotlib.pyplot as plt
    fig, ax = plt.subplots(figsize=(14, 4))
    ax.plot(timeseries_hourly.index, timeseries_hourly.values, linewidth=0.5)
    ax.set_title(f"Event Count ({resample_freq} bins)")
    ax.set_ylabel("Count")
    ax.set_xlabel("Time")
    plt.tight_layout()
    return fig
```

The driver (or Kedro pipeline) saves figures to `runs/<run-id>/figures/`.

---

## 7. Testing {#testing}

Module functions are pure functions — test them directly with pytest.

```python
# tests/test_baseline.py
import pandas as pd
from my_project.analysis.baseline import timeseries_hourly, summary_stats


def test_timeseries_hourly_resamples():
    df = pd.DataFrame({
        "opened_at": pd.date_range("2026-01-01", periods=48, freq="30min"),
        "id": range(48),
    })
    ts = timeseries_hourly(raw_data=df, date_column="opened_at", resample_freq="1h")
    assert len(ts) == 24
    assert ts.sum() == 48


def test_summary_stats_structure():
    ts = pd.Series([1, 2, 3, 0, 5], name="count")
    stats = summary_stats(timeseries_hourly=ts)
    assert "total_count" in stats
    assert "mean" in stats
    assert stats["total_count"] == 11
```

Testing layers:

- **Unit tests**: individual functions with synthetic data
- **Integration tests**: handwired driver with small real data
- **Validation tests**: check output constraints (ranges, types, no NaN)

---

## 8. Transition to Kedro {#kedro-transition}

Because module functions follow the same output-and-dependency naming discipline,
they map directly to Kedro nodes:

```python
# Before (`explore`/`experiment` handwired driver):
df = raw_data(raw_data_path=params["raw_data_path"])
ts = timeseries_hourly(raw_data=df, ...)

# After (Kedro pipeline):
from kedro.pipeline import Pipeline, node

Pipeline([
    node(raw_data, inputs="params:raw_data_path", outputs="raw_data"),
    node(timeseries_hourly, inputs=["raw_data", "params:date_column", "params:resample_freq"], outputs="timeseries_hourly"),
    node(summary_stats, inputs="timeseries_hourly", outputs="summary_stats"),
])
```

The analysis functions don't change. Only the wiring moves from a handwired
`run()` function to a Kedro pipeline definition. See `references/kedro-guide.md`.

---

## 9. Anti-Patterns {#anti-patterns}

**Nested call chains.** Never write A calling B calling C calling D. Each
function should take its dependencies as parameters, not call other functions
in the chain directly.

```python
# Bad: nested calls create hidden dependencies
def final_result(raw_path):
    df = load_data(raw_path)
    ts = resample(df)
    scored = score(ts)
    return summarize(scored)

# Good: flat functions, driver wires them
def raw_data(raw_data_path: str) -> pd.DataFrame: ...
def timeseries_hourly(raw_data: pd.DataFrame, ...) -> pd.Series: ...
def anomaly_scores(timeseries_hourly: pd.Series, ...) -> pd.Series: ...
def summary_stats(anomaly_scores: pd.Series) -> dict: ...
```

**Giant multi-purpose functions.** If a function does loading, cleaning,
resampling, and scoring, split it. Each function should produce one thing.

**I/O inside business logic.** Functions in `analysis/` never read files or
save results. Data loading happens at the boundary (`raw_data`). Saving happens
in the driver or pipeline.

**Computation in notebook cells.** Put reusable logic in `src/<project>/analysis/`
modules. Keep notebooks as orchestration and display surfaces.

**Untyped functions.** Always add type hints. They serve as documentation and
make the dependency graph self-describing.
