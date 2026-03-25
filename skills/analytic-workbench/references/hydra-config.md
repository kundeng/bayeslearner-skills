# Hydra Config Reference

Hydra is the **config layer** of the analytic workbench at Stage 2+. It owns
config composition, CLI overrides, and experiment sweeps. It produces a frozen
`DictConfig` that the handwired driver (or Kedro at Stage 3) consumes as a
plain dict. Hydra never touches DataFrames, figures, or business logic.

Most important rule: Stage 2 is an additive wiring upgrade over Stage 1.
Hydra should improve config injection and run management without changing the
underlying computation contract.

## Table of Contents
1. [Basic Structure](#basic-structure)
2. [Config Composition](#config-composition)
3. [Experiment Configs](#experiment-configs)
4. [Command-Line Overrides](#overrides)
5. [Multirun Sweeps](#multirun)
6. [Output Directory Conventions](#output-dirs)
7. [Integration with Analysis Modules](#integration)
8. [Integration with Kedro (Stage 3)](#kedro-integration)

---

## 1. Basic Structure {#basic-structure}

```
conf/
  config.yaml              # primary config
  experiment/
    fast_test.yaml          # quick single-param test
    full_sweep.yaml         # comprehensive sweep
  source/
    splunk.yaml             # data source variant
    csv_local.yaml          # local CSV variant
```

```yaml
# conf/config.yaml
defaults:
  - source: csv_local
  - _self_

baseline:
  resample_freq: "1h"
  date_column: opened_at

analysis:
  window_size: 24
  normalize: true
  anomaly_threshold: 3.0
  top_k_discords: 10

source:
  raw_data_path: rawdata/incidents.csv
```

Note: `defaults:` is composition metadata, not business data you read from
`cfg`. `_self_` means "merge the body of the current file here." Order matters:
later merges win on conflicts.

---

## 2. Config Composition {#config-composition}

Hydra composes configs by merging YAML files from the `defaults` list.
Each config group (e.g., `source/`) provides variants:

```yaml
# conf/source/splunk.yaml
source:
  type: splunk
  index: snow
  sourcetype: "snow:incident"
  earliest: "-12mon"
  latest: "now"

# conf/source/csv_local.yaml
source:
  type: csv
  raw_data_path: rawdata/incidents.csv
  date_column: opened_at
```

Switch source at the command line:

```bash
python -m my_project.scripts.run source=splunk
```

Key composition rules:

- `defaults:` is composition metadata, not business data you usually read from `cfg`
- `_self_` means "merge the body of the current file here"
- order matters: later merges win on conflicts
- group selections like `source: splunk` usually land under `cfg.source`
- `# @package _global_` changes placement so the file merges at the config root

Minimal precedence example:

```yaml
defaults:
  - source: csv_local
  - _self_

source:
  timeout: 30
```

In this case, the current file merges after `source: csv_local`, so `source.timeout: 30`
from the current file overrides the same field from `csv_local.yaml`.

---

## 3. Experiment Configs {#experiment-configs}

Experiment configs override multiple settings at once for named experiments:

```yaml
# conf/experiment/fast_test.yaml
# @package _global_
defaults:
  - override /source: csv_local

baseline:
  resample_freq: "4h"

analysis:
  window_size: 24
  top_k_discords: 3
```

```yaml
# conf/experiment/full_sweep.yaml
# @package _global_
defaults:
  - override /source: splunk

baseline:
  resample_freq: "1h"

analysis:
  window_size: 168
  top_k_discords: 20
```

Run a named experiment:

```bash
python -m my_project.scripts.run +experiment=fast_test
python -m my_project.scripts.run +experiment=full_sweep
```

---

## 4. Command-Line Overrides {#overrides}

```bash
# Override a single value
python -m my_project.scripts.run baseline.resample_freq=30min

# Override nested values
python -m my_project.scripts.run source.earliest="-6mon"

# Combine overrides
python -m my_project.scripts.run baseline.resample_freq=30min analysis.anomaly_threshold=2.5
```

Operator semantics:

- `key=value`: set an existing key; usually errors if the path does not exist
- `+key=value`: add a new key only if it is currently absent; errors if already present
- `++key=value`: create or replace; use carefully because it can hide typos
- `~key`: delete a key or remove a defaults-list selection

Two different kinds of override:

- `source=splunk` selects a config-group option, meaning Hydra loads a different config file
- `source.timeout=60` changes a field inside the already selected `source` subtree

Practical rule:

- use plain `key=value` by default
- use `+` when "must be new" is the point
- use `++` only when you explicitly want create-or-replace behavior

---

## 5. Multirun Sweeps {#multirun}

Sweep across parameter values with `--multirun` (or `-m`):

```bash
# Sweep one parameter
python -m my_project.scripts.run -m baseline.resample_freq=10min,30min,1h,4h

# Sweep two parameters (cartesian product)
python -m my_project.scripts.run -m \
  baseline.resample_freq=30min,1h \
  analysis.anomaly_threshold=2.0,3.0,5.0

# 2 x 3 = 6 runs, each in its own output directory
```

### Sweep output structure

```yaml
# Configure in config.yaml
hydra:
  sweep:
    dir: runs/sweeps/${now:%Y-%m-%d_%H-%M-%S}
    subdir: ${hydra.job.override_dirname}
```

Produces:

```
runs/sweeps/2026-03-08_14-30-00/
  baseline.resample_freq=30min,analysis.anomaly_threshold=2.0/
    config.yaml
    metrics.json
    figures/
  baseline.resample_freq=30min,analysis.anomaly_threshold=3.0/
    ...
```

---

## 6. Output Directory Conventions {#output-dirs}

Every run should save:

| File | Purpose |
|------|---------|
| `config.yaml` | Frozen config (Hydra saves this automatically) |
| `metrics.json` | Machine-readable metrics for comparison table |
| `figures/*.png` | Visual artifacts |
| `data/*.csv` | Data outputs (optional) |

The comparison table builder reads `metrics.json` from every run directory
to build the cross-run comparison table.

Important runtime detail:

- Hydra always creates a run directory and writes `.hydra/` metadata there
- With Hydra 1.2+ and `version_base=None`, `hydra.job.chdir` defaults to `False`
- Do not assume `Path(".")` is the run directory unless you explicitly enable
  `hydra.job.chdir=True`
- Prefer `HydraConfig.get().runtime.output_dir` when writing run artifacts

---

## 7. Integration with Analysis Modules {#integration}

Hydra is the config layer. Analysis modules are the computation layer. The
runner script bridges them:

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

    # Call analysis functions in DAG order (handwired driver pattern)
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

The key pattern:

1. Hydra composes config from YAML + CLI overrides
2. `OmegaConf.to_container(cfg, resolve=True)` flattens it to a plain dict
3. The handwired driver calls analysis functions in DAG order
4. Artifacts are saved to the Hydra output directory

Enforcement points:

- keep the Stage 1 runner boundary or an equivalent stable entrypoint
- convert config to plain Python objects near the boundary
- do not pass `DictConfig` or Hydra runtime objects deep into analysis modules
- keep notebooks, plain runners, and Hydra runners able to call the same core functions

---

## 8. Integration with Kedro (Stage 3) {#kedro-integration}

At Stage 3, if you add Kedro for pipeline DAG execution and data catalog, Hydra
still owns config composition and sweeps. Pass Hydra's composed config to Kedro
via `extra_params`:

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

This lets you keep Hydra's `--multirun` sweeps, config groups, and experiment
configs while using Kedro for pipeline execution, data catalog, and `kedro viz`.

```bash
# Single run with Kedro pipeline
python -m my_project.scripts.run_kedro

# Sweep with Kedro pipeline
python -m my_project.scripts.run_kedro -m \
  baseline.resample_freq=30min,1h \
  analysis.window_size=24,72,168
```
