# Kedro Guide

Kedro is one of two options in `experiment` mode for adding pipeline structure to the
analytic workbench. It replaces the handwired driver with a DAG runner, adds a
data catalog for managing I/O, and provides pipeline visualization via
`kedro viz`.

**Kedro does NOT replace Hydra.** Hydra (`experiment`+) owns config composition,
CLI overrides, and `--multirun` sweeps. Kedro receives config from Hydra via
`extra_params` and handles pipeline execution, data catalog, and visualization.

The other option is DVC (see `references/dvc-guide.md`). You can use
Kedro alone, DVC alone, or both together. They are complementary.

## Table of Contents
1. [What Kedro Provides](#what-it-provides)
2. [Setup](#setup)
3. [Pipeline Definition](#pipelines)
4. [Data Catalog](#catalog)
5. [Running Pipelines](#running)
6. [Visualization](#visualization)
7. [Config: Hydra Delegates to Kedro](#config)
8. [Parameter Sweeps (via Hydra)](#sweeps)
9. [Integration with marimo](#marimo-integration)
10. [Integration with DVC](#dvc-integration)
11. [Project Structure](#project-structure)
12. [When to Add Kedro](#when-to-add)
13. [Common Mistakes](#common-mistakes)

---

## 1. What Kedro Provides {#what-it-provides}

| Concern | Kedro feature | Replaces |
|---------|--------------|----------|
| Pipeline DAG | `Pipeline`, `node()` | Handwired driver |
| Data I/O | Data catalog (`catalog.yml`) | Manual file reads/writes |
| Visualization | `kedro viz` | Hand-drawn dependency sketches |
| CLI | `kedro run`, `kedro catalog list` | Custom scripts |

What Kedro does **not** provide (Hydra handles these):

| Concern | Tool |
|---------|------|
| Config composition / config groups | Hydra |
| `--multirun` parameter sweeps | Hydra |
| Experiment configs | Hydra |
| Auto output directories | Hydra |

---

## 2. Setup {#setup}

```bash
pip install -e ".[kedro]"    # adds kedro, kedro-viz
```

For the analytic workbench, you adapt an existing `src/` package rather than
using `kedro new`. Create the pipeline directories manually:

```bash
mkdir -p src/my_project/pipelines/baseline
touch src/my_project/pipelines/__init__.py
touch src/my_project/pipelines/baseline/__init__.py
```

---

## 3. Pipeline Definition {#pipelines}

Kedro pipelines wire your existing analysis functions into a DAG. The functions
themselves don't change — only the wiring moves from the handwired driver to
Kedro's `Pipeline` definition.

```python
# src/my_project/pipelines/baseline/pipeline.py
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

Key points:

- `func` is your existing analysis function — unchanged from `explore`.
- `inputs` uses parameter names that match the function signature.
- `params:` prefix reads from Kedro's parameter store (populated by Hydra).
- `outputs` names become available as inputs to downstream nodes.
- The pipeline is a list of nodes — order doesn't matter, Kedro resolves
  the DAG from dependencies.

### Pipeline registry

```python
# src/my_project/pipeline_registry.py
from my_project.pipelines.baseline.pipeline import create_pipeline as baseline


def register_pipelines():
    return {
        "baseline": baseline(),
        "__default__": baseline(),
    }
```

---

## 4. Data Catalog {#catalog}

The data catalog declares how named datasets are stored and loaded, separating
I/O from business logic.

```yaml
# conf/base/catalog.yml
raw_data:
  type: pandas.CSVDataset
  filepath: rawdata/incidents.csv
  load_args:
    parse_dates: [opened_at]

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

Benefits:

- Analysis functions never touch file paths or I/O libraries.
- Switching from CSV to Parquet is a catalog change, not a code change.
- The catalog is the single source of truth for where data lives.

### MemoryDataset (default)

Datasets not listed in the catalog are treated as `MemoryDataset` — they exist
only in memory during the pipeline run. Fine for intermediate results.

---

## 5. Running Pipelines {#running}

```bash
# Run the default pipeline
kedro run

# Run a specific pipeline
kedro run --pipeline=baseline

# Run specific nodes
kedro run --nodes="load_raw_data,resample_timeseries"

# Run from a specific node onward
kedro run --from-nodes="resample_timeseries"
```

### Programmatic execution

```python
from kedro.framework.session import KedroSession

with KedroSession.create() as session:
    result = session.run(pipeline_name="baseline")
```

---

## 6. Visualization {#visualization}

```bash
pip install kedro-viz
kedro viz                    # opens browser with interactive DAG
kedro viz --autoreload       # watches for changes
```

`kedro viz` shows the full pipeline DAG, data catalog entries, parameter
values, and node metadata. Use it to:

- Verify pipeline wiring after changes
- Communicate pipeline structure to stakeholders
- Debug unexpected dependencies

---

## 7. Config: Hydra Delegates to Kedro {#config}

Hydra owns config composition, sweeps, and experiment configs. With Kedro, pass
Hydra's composed config to Kedro via `extra_params`:

```python
# src/my_project/scripts/run_kedro.py
"""Hydra config → Kedro pipeline execution."""
import hydra
from omegaconf import DictConfig, OmegaConf
from kedro.framework.session import KedroSession


@hydra.main(version_base=None, config_path="../../conf", config_name="config")
def main(cfg: DictConfig) -> None:
    params = OmegaConf.to_container(cfg, resolve=True)

    with KedroSession.create(extra_params=params) as session:
        session.run(pipeline_name="baseline")


if __name__ == "__main__":
    main()
```

This means:

- Hydra's `conf/config.yaml`, config groups, and experiment configs work as-is
- `--multirun` sweeps work: each sweep invocation creates a Kedro session
- Kedro nodes access parameters via `params:baseline.resample_freq` as normal
- `kedro run` still works standalone for quick runs without Hydra

### Kedro's own config (`conf/base/`)

Kedro has its own config system (`conf/base/parameters.yml`). When using Hydra,
you can either:

1. **Use Hydra exclusively** via `extra_params` (recommended — single config source)
2. **Use Kedro config for defaults** and override with Hydra's `extra_params`

Keep `conf/base/catalog.yml` for the data catalog (Hydra doesn't manage I/O).
Credentials go in `conf/local/credentials.yml` (gitignored).

---

## 8. Parameter Sweeps (via Hydra) {#sweeps}

Kedro has no built-in `--multirun` or sweep capability. Use Hydra for sweeps:

```bash
# Sweep with Kedro pipeline execution
python -m my_project.scripts.run_kedro -m \
  baseline.resample_freq=30min,1h \
  analysis.window_size=24,72,168
```

Or use a Python sweep script:

```python
# src/my_project/scripts/sweep.py
"""Parameter sweep across multiple Kedro configurations."""
from kedro.framework.session import KedroSession
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

After the sweep, build the comparison table:
`python -m my_project.scripts.build_comparison runs/`

---

## 9. Integration with marimo {#marimo-integration}

marimo remains the human review surface. It can either:

**A. Load pre-computed artifacts** (report mode):

```python
@app.cell
def _(pd, Path):
    comparison = pd.read_csv(Path("runs") / "comparison.csv")
    comparison
    return comparison,
```

**B. Run Kedro pipelines interactively** (exploration mode):

```python
@app.cell
def _():
    from kedro.framework.session import KedroSession
    return KedroSession,

@app.cell
def _(KedroSession, freq):
    with KedroSession.create(
        extra_params={"baseline.resample_freq": freq.value}
    ) as session:
        result = session.run(pipeline_name="baseline")
    return result,
```

Pattern: use mode A for review, mode B for interactive exploration.

---

## 10. Integration with DVC {#dvc-integration}

In `experiment` mode, DVC can wrap Kedro runs for caching and versioning:

```yaml
# dvc.yaml
stages:
  baseline:
    cmd: kedro run --pipeline=baseline
    deps:
      - src/my_project/analysis/baseline.py
      - src/my_project/pipelines/baseline/pipeline.py
      - rawdata/incidents.csv
    params:
      - conf/base/parameters.yml:
          - baseline.resample_freq
    outs:
      - runs/baseline/
```

DVC handles persistent caching and remote sharing. Kedro handles pipeline
execution and data catalog. They coexist well.

---

## 11. Project Structure {#project-structure}

```
src/
  my_project/
    __init__.py
    analysis/                # Pure functions (unchanged from `explore`)
      __init__.py
      baseline.py
      features.py
    pipelines/               # Kedro pipeline definitions
      __init__.py
      baseline/
        __init__.py
        pipeline.py
    scripts/
      run.py                 # Hydra runner (`experiment`, still works)
      run_kedro.py           # Hydra + Kedro runner (with Kedro)
      sweep.py
      build_comparison.py
    tools/
      fetch_data.py
notebooks/                   # marimo notebooks
  explore.py
  report.py
conf/
  config.yaml                # Hydra primary config
  source/                    # Hydra config groups
  experiment/                # Hydra experiment configs
  base/
    catalog.yml              # Kedro data catalog
  local/
    credentials.yml          # Kedro credentials (gitignored)
```

Key: `analysis/` modules are pure functions that work at any stage.
`pipelines/` wires them into Kedro DAGs. Analysis code never imports Kedro.

---

## 12. When to Add Kedro {#when-to-add}

Add Kedro to `experiment` mode when at least one of these becomes painful without it:

- The handwired driver is growing long and hard to maintain
- You want a data catalog to manage I/O declaratively
- You want pipeline visualization for communication or debugging
- You need partial pipeline execution (`--from-nodes`, `--to-nodes`)

If none of that hurts yet, stay at `experiment` without Kedro with Hydra + handwired driver.

---

## 13. Common Mistakes {#common-mistakes}

- **Using Kedro's config instead of Hydra's.** Hydra owns composition, sweeps,
  and experiment configs. Kedro receives parameters via `extra_params`. Keep
  `catalog.yml` and `credentials.yml` in Kedro's `conf/base/` and `conf/local/`.
- **Putting business logic in pipeline definitions.** Pipeline files should
  only wire functions — all logic belongs in `analysis/` modules.
- **Over-cataloging.** Not every intermediate result needs a catalog entry.
  MemoryDataset (the default) is fine for ephemeral intermediate data.
- **Coupling analysis modules to Kedro.** Functions in `analysis/` should
  never import from `kedro`. They're plain Python — testable and reusable
  without the framework.
