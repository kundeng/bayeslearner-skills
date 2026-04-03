# Hydra Config Reference

Hydra is the **config layer** of the analytic workbench at `experiment`+. It owns
config composition, CLI overrides, and experiment sweeps. It produces a frozen
`DictConfig` that the Hamilton Driver consumes via
`driver.Builder().with_config(params)`. Hydra never touches DataFrames,
figures, or business logic.

Most important rule: `experiment` is an additive wiring upgrade over `explore`.
Hydra should improve config injection and run management without changing the
underlying computation contract.

## Table of Contents
1. [Basic Structure](#basic-structure)
2. [Config Composition](#config-composition)
3. [Experiment Configs](#experiment-configs)
4. [Command-Line Overrides](#overrides)
5. [Multirun Sweeps](#multirun)
6. [Output Directory Conventions](#output-dirs)
7. [Integration with Hamilton](#hamilton-integration)

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

## 7. Integration with Hamilton {#hamilton-integration}

Hydra is the config layer. Hamilton is the execution layer. The runner
script bridges them:

```python
# src/my_project/scripts/run.py
"""Hydra config → Hamilton Driver execution."""
import hydra
from hydra.core.hydra_config import HydraConfig
from omegaconf import DictConfig, OmegaConf
from pathlib import Path
import json

from hamilton import driver
from hamilton.io.materialization import to
from my_project.analysis import baseline


@hydra.main(version_base=None, config_path="../../conf", config_name="config")
def main(cfg: DictConfig) -> float:
    out = Path(HydraConfig.get().runtime.output_dir)
    (out / "figures").mkdir(parents=True, exist_ok=True)
    (out / "data").mkdir(parents=True, exist_ok=True)

    params = OmegaConf.to_container(cfg, resolve=True)

    # Hamilton handles DAG resolution, caching, and selective execution
    dr = (
        driver.Builder()
        .with_modules(baseline)
        .with_config(params)
        .with_cache()
        .build()
    )

    results = dr.execute(
        ["summary_stats", "timeseries_hourly", "timeseries_figure"],
        inputs=params,
    )

    # Save artifacts to Hydra output directory
    results["timeseries_hourly"].to_csv(out / "data" / "timeseries.csv")
    results["timeseries_figure"].savefig(out / "figures" / "fig-timeseries.png", dpi=150)
    json.dump(results["summary_stats"], open(out / "metrics.json", "w"), indent=2)
    dr.visualize_execution(
        ["summary_stats", "timeseries_figure"],
        out / "figures" / "dag-execution.png",
    )

    return results["summary_stats"].get("total_count", 0)


if __name__ == "__main__":
    main()
```

The key pattern:

1. Hydra composes config from YAML + CLI overrides
2. `OmegaConf.to_container(cfg, resolve=True)` flattens to a plain dict
3. Hamilton Driver resolves the DAG automatically — no manual call ordering
4. `.with_cache()` skips unchanged upstream nodes across sweep runs
5. Artifacts and DAG visualization saved to Hydra output directory

This combination replaces Kedro for most workbench use cases:
- Hamilton provides DAG resolution, visualization, and caching
- Hydra provides config composition and sweeps
- Together they cover pipeline execution, I/O (via materializers), config
  management, and experiment comparison — without Kedro's ceremony

Enforcement points:

- convert config to plain Python objects near the boundary
- do not pass `DictConfig` or Hydra runtime objects into analysis modules
- keep notebooks, plain runners, and Hydra runners able to call the same
  core functions via the same Hamilton modules
