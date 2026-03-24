# Code Templates Reference

Complete working examples for each component of the analytic workbench.
Copy and adapt these to bootstrap a new project.

## Table of Contents
1. [Project Scaffold](#scaffold)
2. [Analysis Module (DAG-Friendly Naming)](#module)
3. [Handwired Driver (Tier 1)](#handwired-driver)
4. [Hydra Runner (Tier 2+)](#hydra-runner)
5. [marimo Exploration Notebook](#explore-notebook)
6. [marimo Report App](#report-app)
7. [Kedro Pipeline (Tier 3 Option)](#kedro-pipeline)
8. [Kedro Sweep Runner (Tier 3 Option)](#sweep-runner)
9. [Comparison Table Builder](#comparison-builder)
10. [Freshness-Aware Data Loader](#data-loader)
11. [pyproject.toml](#pyproject)

---

## 1. Project Scaffold {#scaffold}

```bash
# Replace my_project with your actual project name
mkdir -p src/my_project/analysis src/my_project/scripts src/my_project/tools \
         notebooks rawdata runs tests
touch src/my_project/__init__.py src/my_project/analysis/__init__.py
```

Create `.gitignore`:

```
rawdata/
runs/
__pycache__/
*.pyc
.env
*.egg-info/
.venv/
conf/local/
mlruns/
```

Then install in editable mode:

```bash
python -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
```

---

## 2. Analysis Module (DAG-Friendly Naming) {#module}

Every module in `src/<project>/analysis/` follows DAG-friendly conventions:
function name = output name, parameters = dependencies, type hints on everything.

```python
# src/my_project/analysis/baseline.py
"""Time series construction from raw data."""
import pandas as pd
import numpy as np
from typing import Dict, Any


def raw_data(raw_data_path: str) -> pd.DataFrame:
    """Load raw data from CSV."""
    return pd.read_csv(raw_data_path, parse_dates=True)


def timeseries_hourly(
    raw_data: pd.DataFrame,
    date_column: str,
    resample_freq: str,
) -> pd.Series:
    """Resample raw data to fixed-frequency counts."""
    df = raw_data.copy()
    df[date_column] = pd.to_datetime(df[date_column], errors="coerce")
    ts = df.set_index(date_column).resample(resample_freq).size()
    ts.name = "count"
    return ts


def summary_stats(timeseries_hourly: pd.Series) -> Dict[str, float]:
    """Descriptive statistics for the time series."""
    return {
        "total_periods": len(timeseries_hourly),
        "total_count": int(timeseries_hourly.sum()),
        "mean": float(timeseries_hourly.mean()),
        "median": float(timeseries_hourly.median()),
        "std": float(timeseries_hourly.std()),
        "max": int(timeseries_hourly.max()),
        "zero_rate": float((timeseries_hourly == 0).mean()),
    }


def timeseries_figure(
    timeseries_hourly: pd.Series,
    resample_freq: str,
) -> "matplotlib.figure.Figure":
    """Create a time series plot. Returns the figure object."""
    import matplotlib.pyplot as plt
    fig, ax = plt.subplots(figsize=(14, 4))
    ax.plot(timeseries_hourly.index, timeseries_hourly.values, linewidth=0.5)
    ax.set_title(f"Event Count ({resample_freq} bins)")
    ax.set_ylabel("Count")
    ax.set_xlabel("Time")
    plt.tight_layout()
    return fig
```

Notice:

- `raw_data` takes a path and returns a DataFrame — data loading is a DAG node.
- `timeseries_hourly` depends on `raw_data` by parameter name.
- `summary_stats` depends on `timeseries_hourly` by parameter name.
- No I/O in core logic except the explicit `raw_data` loader.
- Figures are returned as objects, not saved to disk inside the function.

---

## 3. Handwired Driver (Tier 1) {#handwired-driver}

The driver calls analysis functions in DAG order. Every step visible, every
dependency explicit. No framework dependency.

```python
# src/my_project/scripts/run.py
"""Handwired driver — calls analysis functions in DAG order."""
from pathlib import Path
import json
import yaml
from my_project.analysis.baseline import (
    raw_data,
    timeseries_hourly,
    summary_stats,
    timeseries_figure,
)


def run(params: dict, output_dir: str) -> dict:
    """Execute analysis pipeline and save artifacts."""
    out = Path(output_dir)
    out.mkdir(parents=True, exist_ok=True)
    (out / "figures").mkdir(exist_ok=True)
    (out / "data").mkdir(exist_ok=True)

    # Call functions in dependency order
    df = raw_data(raw_data_path=params["raw_data_path"])
    ts = timeseries_hourly(
        raw_data=df,
        date_column=params["date_column"],
        resample_freq=params["resample_freq"],
    )
    stats = summary_stats(timeseries_hourly=ts)
    fig = timeseries_figure(
        timeseries_hourly=ts,
        resample_freq=params["resample_freq"],
    )

    # Save artifacts
    ts.to_csv(out / "data" / "timeseries.csv")
    fig.savefig(out / "figures" / "fig-timeseries.png", dpi=150)
    json.dump(stats, open(out / "metrics.json", "w"), indent=2)
    with open(out / "config.yaml", "w") as f:
        yaml.dump(params, f)

    return stats


if __name__ == "__main__":
    params = {
        "raw_data_path": "rawdata/events.csv",
        "date_column": "opened_at",
        "resample_freq": "1h",
    }
    run(params, "runs/manual_001")
```

---

## 4. Hydra Runner (Tier 2+) {#hydra-runner}

At Tier 2, Hydra composes config from YAML + CLI overrides and the handwired
driver executes analysis functions in DAG order.

```python
# src/my_project/scripts/run.py
"""Hydra-powered runner — composes config, calls analysis functions."""
import hydra
from hydra.core.hydra_config import HydraConfig
from omegaconf import DictConfig, OmegaConf
from pathlib import Path
import json
from my_project.analysis.baseline import (
    raw_data,
    timeseries_hourly,
    summary_stats,
    timeseries_figure,
)


@hydra.main(version_base=None, config_path="../../conf", config_name="config")
def main(cfg: DictConfig) -> float:
    out = Path(HydraConfig.get().runtime.output_dir)
    (out / "figures").mkdir(parents=True, exist_ok=True)
    (out / "data").mkdir(parents=True, exist_ok=True)

    # Hydra config → plain dict
    params = OmegaConf.to_container(cfg, resolve=True)

    # Call analysis functions in DAG order
    df = raw_data(raw_data_path=params["source"]["raw_data_path"])
    ts = timeseries_hourly(
        raw_data=df,
        date_column=params["baseline"]["date_column"],
        resample_freq=params["baseline"]["resample_freq"],
    )
    stats = summary_stats(timeseries_hourly=ts)
    fig = timeseries_figure(
        timeseries_hourly=ts,
        resample_freq=params["baseline"]["resample_freq"],
    )

    # Save artifacts to Hydra output directory
    ts.to_csv(out / "data" / "timeseries.csv")
    fig.savefig(out / "figures" / "fig-timeseries.png", dpi=150)
    json.dump(stats, open(out / "metrics.json", "w"), indent=2)
    OmegaConf.save(cfg, out / "config.yaml")

    return stats.get("total_count", 0)


if __name__ == "__main__":
    main()
```

```bash
# Single run
python -m my_project.scripts.run

# Override parameters
python -m my_project.scripts.run baseline.resample_freq=30min

# Multirun sweep
python -m my_project.scripts.run -m \
  baseline.resample_freq=30min,1h \
  analysis.anomaly_threshold=2.0,3.0,5.0
```

---

## 5. marimo Exploration Notebook {#explore-notebook}

The notebook is a thin UI shell. All computation goes through analysis module
functions. Notebooks live in `notebooks/` (outside `src/`).

```python
# notebooks/explore.py
import marimo

app = marimo.App(width="medium")


@app.cell
def _():
    import marimo as mo
    from my_project.analysis.baseline import (
        raw_data,
        timeseries_hourly,
        summary_stats,
        timeseries_figure,
    )
    return mo, raw_data, timeseries_hourly, summary_stats, timeseries_figure


@app.cell
def _(mo):
    mo.md("# Interactive Exploration")
    return


@app.cell
def _(mo):
    freq = mo.ui.dropdown(
        options=["10min", "30min", "1h", "4h", "1d"],
        value="1h",
        label="Resample frequency",
    )
    data_path = mo.ui.text(
        value="rawdata/events.csv",
        label="Data path",
    )
    mo.hstack([freq, data_path])
    return freq, data_path


@app.cell
def _(raw_data, data_path):
    df = raw_data(raw_data_path=data_path.value)
    df
    return df,


@app.cell
def _(df, freq, timeseries_hourly):
    ts = timeseries_hourly(
        raw_data=df,
        date_column="opened_at",
        resample_freq=freq.value,
    )
    ts
    return ts,


@app.cell
def _(ts, summary_stats, mo):
    stats = summary_stats(timeseries_hourly=ts)
    mo.md(f"**Total periods:** {stats['total_periods']:,} | "
          f"**Mean:** {stats['mean']:.2f} | "
          f"**Zero rate:** {stats['zero_rate']:.1%}")
    return stats,


@app.cell
def _(ts, freq, timeseries_figure):
    fig = timeseries_figure(timeseries_hourly=ts, resample_freq=freq.value)
    fig
    return


if __name__ == "__main__":
    app.run()
```

Run: `marimo edit notebooks/explore.py`

---

## 5. marimo Report App {#report-app}

Loads pre-computed artifacts from `runs/`. No computation, only display.

```python
# notebooks/report.py
"""Review surface — loads artifacts from runs/, no computation."""
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
def _(pd, Path):
    comp_path = Path("runs") / "comparison.csv"
    if comp_path.exists():
        comparison = pd.read_csv(comp_path)
    else:
        comparison = pd.DataFrame({"status": ["No comparison table found"]})
    comparison
    return comparison,


@app.cell
def _(mo, comparison):
    if "run_id" in comparison.columns:
        run_selector = mo.ui.dropdown(
            options=comparison["run_id"].tolist(),
            label="Inspect run",
        )
        run_selector
    return run_selector,


@app.cell
def _(run_selector, json, Path, mo):
    run_dir = Path("runs") / run_selector.value
    if not run_dir.exists():
        mo.md("Run directory not found")
    else:
        metrics_path = run_dir / "metrics.json"
        if metrics_path.exists():
            metrics = json.loads(metrics_path.read_text())
            mo.tree(metrics)

        figs = sorted((run_dir / "figures").glob("*.png"))
        if figs:
            mo.vstack([mo.image(src=str(f)) for f in figs])
    return


if __name__ == "__main__":
    app.run()
```

Run: `marimo run notebooks/report.py`

---

## 7. Kedro Pipeline (Tier 3 Option) {#kedro-pipeline}

At Tier 3, you can optionally replace the handwired driver with a Kedro
pipeline. The analysis functions don't change — only the wiring. Hydra still
owns config composition and sweeps.

```python
# src/my_project/pipelines/baseline/pipeline.py
"""Kedro pipeline — wires analysis functions into a DAG."""
from kedro.pipeline import Pipeline, node
from my_project.analysis.baseline import (
    raw_data,
    timeseries_hourly,
    summary_stats,
    timeseries_figure,
)


def create_pipeline(**kwargs) -> Pipeline:
    return Pipeline([
        node(
            func=raw_data,
            inputs="params:source.raw_data_path",
            outputs="raw_data",
            name="load_raw_data",
        ),
        node(
            func=timeseries_hourly,
            inputs=[
                "raw_data",
                "params:baseline.date_column",
                "params:baseline.resample_freq",
            ],
            outputs="timeseries_hourly",
            name="resample_timeseries",
        ),
        node(
            func=summary_stats,
            inputs="timeseries_hourly",
            outputs="summary_stats",
            name="compute_summary",
        ),
        node(
            func=timeseries_figure,
            inputs=[
                "timeseries_hourly",
                "params:baseline.resample_freq",
            ],
            outputs="timeseries_figure",
            name="plot_timeseries",
        ),
    ])
```

```yaml
# conf/base/parameters.yml
baseline:
  resample_freq: "1h"
  date_column: opened_at

source:
  raw_data_path: rawdata/incidents.csv

analysis:
  window_size: 24
  normalize: true
  anomaly_threshold: 3.0
  top_k_discords: 10
```

```yaml
# conf/base/catalog.yml
timeseries_hourly:
  type: pandas.CSVDataset
  filepath: runs/${run_id}/data/timeseries.csv

summary_stats:
  type: json.JSONDataset
  filepath: runs/${run_id}/metrics.json

timeseries_figure:
  type: matplotlib.MatplotlibWriter
  filepath: runs/${run_id}/figures/fig-timeseries.png
  save_args:
    dpi: 150
```

```bash
# Run the pipeline
kedro run --pipeline=baseline

# Override parameters
kedro run --pipeline=baseline --params="baseline.resample_freq:30min"
```

---

## 8. Kedro Sweep Runner (Tier 3 Option) {#sweep-runner}

```python
# src/my_project/scripts/sweep.py
"""Parameter sweep across multiple Kedro configurations."""
from kedro.framework.session import KedroSession
from pathlib import Path
import itertools


def sweep(param_grid: dict, pipeline_name: str = "baseline"):
    """Run all combinations of parameters."""
    keys = list(param_grid.keys())
    values = list(param_grid.values())

    for combo in itertools.product(*values):
        overrides = dict(zip(keys, combo))
        run_id = ",".join(f"{k}={v}" for k, v in overrides.items())
        print(f"Running: {run_id}")

        with KedroSession.create(extra_params=overrides) as session:
            session.run(pipeline_name=pipeline_name)


if __name__ == "__main__":
    sweep({
        "baseline.resample_freq": ["10min", "30min", "1h", "4h"],
        "analysis.window_size": [24, 72, 168],
    })
```

```bash
python -m my_project.scripts.sweep
python -m my_project.scripts.build_comparison runs/
```

---

## 9. Comparison Table Builder {#comparison-builder}

```python
# src/my_project/scripts/build_comparison.py
"""Aggregate metrics from all runs into a single comparison table."""
import json
import pandas as pd
from pathlib import Path
import yaml
import sys


def build_comparison(runs_dir: str) -> pd.DataFrame:
    rows = []
    for run_dir in sorted(Path(runs_dir).iterdir()):
        if not run_dir.is_dir():
            continue
        metrics_path = run_dir / "metrics.json"
        if not metrics_path.exists():
            continue

        metrics = json.loads(metrics_path.read_text())
        row = {"run_id": run_dir.name}

        config_path = run_dir / "config.yaml"
        if config_path.exists():
            try:
                with open(config_path) as f:
                    cfg = yaml.safe_load(f)
                if isinstance(cfg, dict):
                    row["resample_freq"] = cfg.get("baseline", {}).get(
                        "resample_freq", cfg.get("resample_freq", "")
                    )
            except Exception:
                pass

        row.update(metrics)
        rows.append(row)

    df = pd.DataFrame(rows)
    out_path = Path(runs_dir) / "comparison.csv"
    df.to_csv(out_path, index=False)
    print(f"Comparison table: {out_path} ({len(df)} runs)")
    return df


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python -m my_project.scripts.build_comparison <runs_dir>")
        sys.exit(1)
    build_comparison(sys.argv[1])
```

---

## 10. Freshness-Aware Data Loader {#data-loader}

A data loader with freshness tracking, following the same module conventions.

```python
# src/my_project/analysis/data_loader.py
"""Load data with freshness-aware caching."""
import json
from datetime import datetime, timezone, timedelta
from pathlib import Path
import pandas as pd


def _fetch_metadata_path(data_path: str) -> str:
    """Convention: metadata file sits next to the data file."""
    return str(Path(data_path).with_suffix(".meta.json"))


def _is_fresh(data_path: str, freshness_hours: int = 48) -> bool:
    """Check if cached data is still fresh enough to reuse."""
    meta_path = _fetch_metadata_path(data_path)
    if not Path(meta_path).exists() or not Path(data_path).exists():
        return False
    meta = json.loads(Path(meta_path).read_text())
    fetched = datetime.fromisoformat(meta["fetched_at"])
    return datetime.now(timezone.utc) - fetched < timedelta(hours=freshness_hours)


def _record_fetch(data_path: str, row_count: int, source: str = "") -> None:
    """Record when data was fetched for freshness tracking."""
    meta = {
        "source": source,
        "fetched_at": datetime.now(timezone.utc).isoformat(),
        "row_count": row_count,
        "data_path": data_path,
    }
    Path(_fetch_metadata_path(data_path)).write_text(json.dumps(meta, indent=2))


def raw_data_cached(
    raw_data_path: str,
    freshness_hours: int,
) -> pd.DataFrame:
    """Load cached data if fresh, otherwise signal that a fetch is needed."""
    if _is_fresh(raw_data_path, freshness_hours):
        return pd.read_csv(raw_data_path)

    raise FileNotFoundError(
        f"Data at {raw_data_path} is stale or missing. "
        f"Run the appropriate fetch tool first: "
        f"python -m my_project.tools.fetch_data --output {raw_data_path}"
    )
```

Note: helper functions prefixed with `_` keep
private helpers out of the public DAG API. Only `raw_data_cached` is a public
node.

---

## 11. pyproject.toml {#pyproject}

See `references/environment-setup.md` for the full template including optional
dependency groups for Hydra, Kedro, DVC, MLflow, AutoML, and more.
