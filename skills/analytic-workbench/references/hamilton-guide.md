# Hamilton Guide

Apache Hamilton builds DAGs from Python function signatures. The naming
discipline in `module-conventions.md` — function name = output, parameter
name = dependency — **is** Hamilton's programming model. The Driver replaces
manual call ordering with automatic DAG resolution, visualization, caching,
and selective execution.

Install: `pip install sf-hamilton` (add `[visualization]` for DAG images).

## When to Adopt

| Mode | Hamilton role |
|---|---|
| `probe` | Not needed. Throwaway code is fine. |
| `explore` | **Recommended.** Driver replaces handwired driver. |
| `experiment` | **Expected.** `@config.when` + `.with_cache()` + Hydra config. |
| `operate` | Materializers for I/O. Driver runs inside orchestrator tasks. |

## Driver

```python
from hamilton import driver
from my_project.analysis import baseline, features

dr = (
    driver.Builder()
    .with_modules(baseline, features)
    .with_config({"resample_freq": "1h"})
    .build()
)

results = dr.execute(
    ["summary_stats", "anomaly_scores"],
    inputs={"raw_data_path": "rawdata/events.csv"},
)
```

What the Driver gives you over a handwired driver:
- **Automatic DAG resolution** — no manual call ordering
- **Selective execution** — `dr.execute(["just_this"])` computes only the
  minimum subgraph
- **Visualization** — `dr.display_all_functions()` for full DAG,
  `dr.visualize_execution(["node"])` for what actually runs
- **Build-time validation** — `.build()` fails on type mismatches or missing
  annotations, catching errors before execution

## Materializers — Data Acquisition as DAG Nodes

This is the pattern that turns acquisition from hidden setup into visible,
cacheable, trackable DAG nodes. Hamilton materializers are the workbench
equivalent of Kedro's data catalog — without YAML configuration.

### Static materializers (recommended)

Use `from_` and `to` objects with `Builder.with_materializers()`. Loaders
and savers become real DAG nodes — visible in visualization, cacheable,
selectively executable.

```python
from hamilton import driver
from hamilton.io.materialization import from_, to
from my_project.analysis import baseline

materializers = [
    # Data acquisition: parquet file → DAG node "raw_df"
    from_.parquet(target="raw_df", path="rawdata/events.parquet"),

    # Artifact save: DAG node "model" → JSON file
    to.json(
        id="model__json",
        dependencies=["model"],
        path="runs/latest/model.json",
    ),
]

dr = (
    driver.Builder()
    .with_modules(baseline)
    .with_materializers(*materializers)
    .build()
)

# Execute: loads raw_df from parquet, runs pipeline, saves model to JSON
results = dr.execute(["model", "model__json"])
# results["model"]        ← the model object
# results["model__json"]  ← save metadata (path, format, etc.)
```

Why this matters for the workbench:
- **Acquisition is visible in the DAG** — `dr.display_all_functions()` shows
  the full path from raw data to outputs
- **Acquisition is cacheable** — `.with_cache()` skips re-reading unchanged
  data
- **I/O is decoupled from computation** — swap parquet for CSV or API source
  by changing the materializer, not the analysis functions
- **This replaces Kedro's data catalog** — same capability, no YAML, no
  framework ceremony

### Function-level materializers

For simpler cases, attach I/O directly to functions with `@load_from` /
`@save_to`:

```python
from hamilton.function_modifiers import load_from, save_to, source

@load_from.parquet(path=source("data_path"))
def raw_df(raw_df: pd.DataFrame) -> pd.DataFrame:
    """Load and validate raw data."""
    return raw_df

@save_to.json(path=source("model_path"))
def model(features: pd.DataFrame) -> XGBModel:
    """Train model."""
    return ...
```

Prefer static materializers when the same data feeds multiple nodes or when
you want to change I/O format without touching analysis code.

## Caching

`.with_cache()` stores results in `.hamilton_cache/` and skips nodes whose
code + inputs haven't changed.

```python
dr = driver.Builder().with_modules(baseline).with_cache().build()

dr.execute(["summary_stats"], inputs=params)  # computes everything
dr.execute(["summary_stats"], inputs=params)  # skips unchanged nodes
```

Cache key = `(node_name, code_version, dependency_data_versions)`. Changing a
function or its upstream inputs invalidates downstream cache. Add
`.hamilton_cache/` to `.gitignore`.

Essential for `experiment` mode: shared upstream nodes (data loading, feature
engineering) don't recompute on every sweep run.

## Key Decorators

### `@config.when` — Variant Selection

Swap implementations based on config. Essential for experiment mode.

```python
from hamilton.function_modifiers import config

@config.when(task="binary_classification")
def base_model__binary(features: pd.DataFrame) -> XGBClassifier:
    return XGBClassifier().fit(features)

@config.when(task="continuous_regression")
def base_model__regression(features: pd.DataFrame) -> XGBRegressor:
    return XGBRegressor().fit(features)

# Driver selects at build time:
dr = driver.Builder().with_modules(models).with_config({"task": "binary_classification"}).build()
```

The `__suffix` is stripped — both produce node `base_model`. Use
`@config.when_not()` for defaults, `@config.when_in()` for multiple values.

### `@extract_fields` — Decompose Structured Outputs

```python
from hamilton.function_modifiers import extract_fields

@extract_fields({"X_train": pd.DataFrame, "X_test": pd.DataFrame,
                 "y_train": pd.Series, "y_test": pd.Series})
def train_test_split(features: pd.DataFrame, target: pd.Series) -> dict:
    ...
```

Each field becomes a separate DAG node — downstream functions can depend on
`X_train` directly.

### `@check_output` — Data Validation

```python
from hamilton.function_modifiers import check_output

@check_output(data_type=float, range=(0, 1), allow_nans=False, importance="fail")
def probability_scores(features: pd.DataFrame, model: object) -> pd.Series:
    return model.predict_proba(features)[:, 1]
```

Separates validation from business logic. `importance="fail"` halts execution;
`"warn"` logs and continues.

### `@tag` — Metadata

```python
from hamilton.function_modifiers import tag

@tag(owner="data-science", pii="false", stage="feature-engineering")
def user_tenure_days(signup_date: pd.Series) -> pd.Series:
    return (pd.Timestamp.now() - signup_date).dt.days
```

## Hamilton + Hydra (`experiment`)

Hydra manages config composition and sweeps. Hamilton consumes the resolved
config. Together they replace Kedro's pipeline + config system.

```python
import hydra
from omegaconf import OmegaConf
from hamilton import driver
from my_project.analysis import baseline

@hydra.main(config_path="conf", config_name="config")
def main(cfg):
    params = OmegaConf.to_container(cfg, resolve=True)
    dr = (
        driver.Builder()
        .with_modules(baseline)
        .with_config(params)
        .with_cache()
        .build()
    )
    results = dr.execute(["summary_stats", "model_metrics"], inputs=params)
```

## Hamilton in the Review Surface

Hamilton's visualization and selective execution are designed to feed the
human review surface — marimo notebooks or Quarto docs. This is how the
human steers the analysis.

### Explore notebook (marimo)

The marimo explore notebook is the primary `explore`-mode review surface.
Hamilton's Driver runs inside it, and DAG visualization is an inline review
artifact.

```python
# notebooks/explore.py — marimo cell
import importlib
from hamilton import driver
import my_project.analysis.baseline as baseline

importlib.reload(baseline)
dr = driver.Builder().with_modules(baseline).build()

# Show the human the full DAG — cheapest review artifact
dr.display_all_functions()
```

```python
# Next cell: execute and present results for human steering
results = dr.execute(
    ["summary_stats", "timeseries_figure"],
    inputs=params,
)
results["timeseries_figure"]  # marimo renders matplotlib figures inline
```

```python
# Next cell: present metrics for human review
import marimo as mo
mo.tree(results["summary_stats"])
```

The pattern: Hamilton computes, marimo displays, the human redirects.

### Report app (marimo)

At `experiment`, the report app loads pre-computed artifacts from `runs/` and
presents comparison tables. Hamilton DAG images saved during pipeline runs
(`dr.visualize_execution(...)`) become reviewable artifacts.

```python
# notebooks/report.py — marimo cell
import marimo as mo
from pathlib import Path

run_dir = Path("runs") / run_selector.value
dag_img = run_dir / "figures" / "dag-execution.png"
if dag_img.exists():
    mo.image(src=str(dag_img))
```

### Quarto doc

For narrative EDA or stakeholder reports, embed Hamilton DAG images and
results as static artifacts:

```markdown
## Pipeline Structure
![DAG](runs/latest/figures/dag-execution.png)

## Results
{{< embed runs/latest/metrics.json >}}
```

Analysis logic lives in `.py` modules; notebooks and docs wire and display.

## Mode Bridge: Notebook Authoring → Hamilton Module

The hardest part of the workbench is the transition from `probe` to `explore`
— from throwaway cell code to reusable modules. Hamilton's `ad_hoc_utils`
eliminates this friction: functions defined in marimo cells become a Hamilton
DAG *immediately*, with full visualization, caching, and selective execution.
Promotion to `explore` is a file move, not a rewrite.

### Probe in marimo with Hamilton naming discipline

Even at `probe`, write functions with Hamilton naming discipline. It costs
nothing and pays off immediately — you get DAG visualization and selective
execution without committing to a project structure.

```python
# marimo cell: define functions with Hamilton naming discipline
import pandas as pd

def raw_data(raw_data_path: str) -> pd.DataFrame:
    """Load raw data from CSV."""
    return pd.read_csv(raw_data_path, parse_dates=True)

def timeseries_hourly(raw_data: pd.DataFrame, resample_freq: str) -> pd.Series:
    """Resample to hourly counts."""
    return raw_data.resample(resample_freq).size()

def summary_stats(timeseries_hourly: pd.Series) -> dict:
    """Compute summary statistics."""
    return {"mean": timeseries_hourly.mean(), "total": timeseries_hourly.sum()}
```

```python
# marimo cell: wrap into Hamilton module on the fly
from hamilton import ad_hoc_utils, driver

temp_module = ad_hoc_utils.create_temporary_module(
    raw_data, timeseries_hourly, summary_stats,
    module_name="probe_baseline",
)
dr = driver.Builder().with_modules(temp_module).build()

# Human sees the DAG shape immediately
dr.display_all_functions()
```

```python
# marimo cell: execute and present for human review
results = dr.execute(
    ["summary_stats", "timeseries_hourly"],
    inputs={"raw_data_path": "rawdata/events.csv", "resample_freq": "1h"},
)
results["summary_stats"]
```

The functions are plain Python — no Hamilton imports, no decorators, no
framework dependency inside the business logic. The `ad_hoc_utils` wrapper
is one line in the notebook cell.

### Promote to explore: file move, not rewrite

When the human approves the probe findings and work is worth keeping:

1. Move the functions to `src/<project>/analysis/baseline.py` — **unchanged**
2. Replace `ad_hoc_utils.create_temporary_module(...)` with
   `import my_project.analysis.baseline as baseline`
3. The Driver call is identical: `driver.Builder().with_modules(baseline).build()`
4. The marimo notebook becomes the `explore` review surface

```python
# marimo cell after promotion — only the import changed
import importlib
from hamilton import driver
import my_project.analysis.baseline as baseline

importlib.reload(baseline)
dr = driver.Builder().with_modules(baseline).build()
dr.display_all_functions()
results = dr.execute(["summary_stats"], inputs=params)
```

The same notebook that was the probe's authoring surface becomes the explore's
review surface. The same functions that were prototyped in cells become the
module that Hamilton, Hydra, and eventually the orchestrator all consume.

### Why this matters

- **Naming discipline is free.** It costs nothing at probe and eliminates
  rewriting at promote.
- **Promotion is a file move.** No code changes, no new abstractions, no
  framework migration.
- **The notebook is dual-purpose.** Authoring surface at probe, review surface
  at explore — same artifact.
- **The human sees the DAG from day one.** Even throwaway probes get
  visualization if the functions follow naming discipline.

## Anti-Patterns

- **Skipping naming discipline at `probe`** — costs nothing, saves a rewrite
  at promote. Even if you don't use Hamilton Driver, name functions as outputs.
- **Driver logic in analysis functions** — Driver belongs in scripts/notebooks
- **Skipping visualization** — the DAG image is the cheapest review artifact
- **No caching during sweeps** — shared upstream recomputes every run
- **`@config.when` for runtime branching** — config selects DAG shape at build
  time; use normal Python for runtime logic
- **I/O inside analysis functions** — use materializers or driver-level I/O;
  keep `src/<project>/analysis/` pure
