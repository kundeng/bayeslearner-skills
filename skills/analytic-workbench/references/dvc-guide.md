# DVC Guide (Tier 3 Option)

DVC is one of two options at Tier 3 for adding reproducibility to the analytic
workbench. It wraps existing scripts (Hydra runners or Kedro pipelines) with
hash-based caching, experiment tracking, and remote artifact storage.

**DVC is additive.** It does not change your project structure, analysis
modules, or config system. It wraps the commands you already run and adds
caching and versioning on top.

The other Tier 3 option is Kedro (see `references/kedro-guide.md`). You can
use DVC alone, Kedro alone, or both together. They are complementary:
DVC adds caching/versioning, Kedro adds DAG runner/catalog/viz.

## Table of Contents
1. [Setup](#setup)
2. [Minimal dvc.yaml](#dvc-yaml)
3. [Core Commands](#core-commands)
4. [Experiments](#experiments)
5. [Caching and Freshness](#caching)
6. [Remotes](#remotes)
7. [When DVC Wraps Hydra Scripts](#wraps-hydra)
8. [When DVC Wraps Kedro Pipelines](#wraps-kedro)
9. [When to Add DVC](#when-to-add)

---

## 1. Setup {#setup}

```bash
pip install -e ".[dvc]"    # adds dvc[s3]
dvc init
```

Commit the DVC initialization files. Keep raw/generated data out of Git and in
DVC-tracked outputs or ignored folders.

---

## 2. Minimal `dvc.yaml` {#dvc-yaml}

### Wrapping a Hydra runner (Tier 2 → 3)

```yaml
stages:
  extract:
    cmd: python -m my_project.tools.fetch_data --output rawdata/incidents.csv
    deps:
      - src/my_project/tools/fetch_data.py
    params:
      - conf/config.yaml:
          - source
    outs:
      - rawdata/incidents.csv

  baseline:
    cmd: python -m my_project.scripts.run
    deps:
      - src/my_project/analysis/baseline.py
      - src/my_project/scripts/run.py
      - rawdata/incidents.csv
    params:
      - conf/config.yaml:
          - baseline.resample_freq
    outs:
      - runs/baseline/
```

### Wrapping a Kedro pipeline (if using both)

```yaml
stages:
  extract:
    cmd: python -m my_project.tools.fetch_data --output rawdata/incidents.csv
    deps:
      - src/my_project/tools/fetch_data.py
    outs:
      - rawdata/incidents.csv

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

Track tunable values in your config files, not inline shell constants.

---

## 3. Core Commands {#core-commands}

```bash
dvc status             # show stale stages
dvc repro              # run stale stages in DAG order
dvc repro STAGE        # run a target stage and its upstream deps
dvc repro -f           # force re-execution even when hashes match
dvc dag                # show the stage DAG
```

- `dvc status` shows stale stages.
- `dvc repro` runs stale stages in DAG order.
- `dvc repro STAGE` runs a target stage and its upstream dependencies.
- `-f` forces re-execution even when hashes match.

---

## 4. Experiments {#experiments}

Use DVC experiments when you want structured comparisons beyond ad hoc manual
parameter edits.

```bash
dvc exp run
dvc exp run -S baseline.resample_freq=30min
dvc exp run --queue -S analysis.window_size=24,72,168
dvc queue start --jobs 4
dvc exp show
dvc exp diff
dvc exp apply EXP_NAME
```

Good practice:

- Still write explicit per-run artifacts to `runs/`
- Still build a comparison table
- Use `dvc exp show` as a helper, not the only source of comparison truth

---

## 5. Caching and Freshness {#caching}

DVC hashes declared `deps`, `params`, and `outs`. If they did not change, the
stage is skipped. That makes it appropriate for policies like:

"Do not re-pull source data again for 48 hours unless the human asks for a
fresh run."

Encode that policy through stage design and parameterization:

```yaml
stages:
  extract:
    frozen: true
    cmd: python -m my_project.tools.fetch_data --output rawdata/incidents.csv
    outs:
      - rawdata/incidents.csv
```

Unfreeze when you want fresh data: `dvc repro --force extract`

---

## 6. Remotes {#remotes}

```bash
dvc remote add -d myremote s3://my-bucket/dvc-cache
dvc push
dvc pull
```

Use remote storage when cached artifacts need to be shared across machines or
recovered later.

---

## 7. When DVC Wraps Hydra Scripts {#wraps-hydra}

At Tier 3 without Kedro, DVC wraps Hydra-powered scripts directly:

```yaml
stages:
  baseline:
    cmd: python -m my_project.scripts.run baseline.resample_freq=1h
    deps:
      - src/my_project/analysis/baseline.py
      - src/my_project/scripts/run.py
      - rawdata/incidents.csv
    params:
      - conf/config.yaml:
          - baseline
    outs:
      - runs/baseline/
```

DVC tracks config changes via `params:`. Hydra composes the config. The
handwired driver executes the analysis.

---

## 8. When DVC Wraps Kedro Pipelines {#wraps-kedro}

If you use both DVC and Kedro at Tier 3:

| Concern | Tool |
|---------|------|
| Config composition, sweeps | Hydra |
| Pipeline DAG execution, data catalog | Kedro |
| Persistent caching of expensive stages | DVC |
| Long-term experiment comparison | DVC experiments |
| Source data freshness rules | DVC frozen stages |
| Remote artifact sharing | DVC remotes |

They coexist well. Kedro manages the pipeline and catalog; DVC manages
artifact caching and versioning; Hydra manages config composition.

---

## 9. When to Add DVC {#when-to-add}

Add DVC at Tier 3 when at least one of these becomes painful without it:

- Expensive upstream data pulls that shouldn't repeat unnecessarily
- Repeat runs with mostly unchanged inputs
- Disciplined comparison across many runs
- Remote sharing of cached artifacts
- Reproducible stage history that should survive the current workspace

If none of that hurts yet, stay at Tier 2 with Hydra + handwired driver +
explicit `runs/` folders + comparison tables.
