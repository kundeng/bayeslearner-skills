# Artifact Strategy Reference

## Table of Contents
1. [Per-Run Artifact Folders](#per-run-folders)
2. [Comparison Table Schema](#comparison-table)
3. [Freshness & Caching Rules](#freshness-rules)
4. [DVC Integration Patterns](#dvc-integration)
5. [AI Self-Review Checklist](#ai-review)

---

## 1. Per-Run Artifact Folders {#per-run-folders}

Every experiment run produces a self-contained folder under `runs/`:

```
runs/<run-id>/
  config.yaml           # frozen config — exactly what params produced this run
  metrics.json          # machine-readable summary metrics
  figures/
    fig-timeseries.png
    fig-anomalies.png
    fig-precision-recall.png
  data/
    timeseries.csv
    discords.csv
    motifs.csv
  logs/
    run.log             # optional — stdout/stderr capture
```

**Run ID conventions:**

- Hydra auto: `outputs/2026-03-08/14-22-33` (Hydra default)
- Hydra sweep: `runs/sweeps/2026-03-08_14-30-00/resample_freq=1h,window_size=24`
- Timestamp: `2026-03-08_14-22-33`
- Parameter-based: `resample_freq=1h,window_size=24` (sweep subdirs)
- Named: `experiment_fast_test_001` (manual runs)

**Non-negotiable files:**

- `config.yaml` — without this, the run is not reproducible.
- `metrics.json` — without this, the run cannot be compared.

**Key layout rules:**

- All run artifacts live inside `runs/<run-id>/`. No separate `outputs/figures/`
  or `data/processed/` directories at the project root.
- `rawdata/` holds frozen file inputs that the analysis treats as given. This
  includes user-provided files, manually staged exports, or deliberately
  promoted snapshots from an external system.
- The first extract from a live API, database, warehouse, or MCP server is not
  automatically `rawdata/`. It begins life as an acquisition artifact of a
  specific run. Only move or copy it into `rawdata/` once you want that exact
  snapshot to become a stable reusable input.
- `rawdata/` is never written to implicitly by a run. Promotion into `rawdata/`
  should be an explicit step.
- Each run folder is self-contained and independently meaningful.

---

## 2. Comparison Table Schema {#comparison-table}

The comparison table (`runs/comparison.csv`) is a first-class artifact.
One row per run. Columns:

| Column | Source | Purpose |
|--------|--------|---------|
| `run_id` | folder name | Unique identifier |
| `timestamp` | config or folder | When the run happened |
| Key parameters | `config.yaml` | What settings were used |
| Key metrics | `metrics.json` | What the run produced |

Example:

```csv
run_id,resample_freq,window_size,threshold,total_incidents,discords_found,precision,recall,f1
2026-03-08_14-22-33,1h,24,3.0,12450,8,0.62,0.45,0.52
2026-03-08_14-25-01,1h,72,3.0,12450,5,0.80,0.30,0.44
2026-03-08_14-28-44,1h,168,3.0,12450,3,1.00,0.15,0.26
2026-03-08_15-01-12,30min,24,2.5,12450,14,0.43,0.70,0.53
```

This table answers:

- Under which settings does the method perform best?
- What is the tradeoff between sensitivity and false positives?
- Which parameter has the most impact on results?

**Build it automatically** after every sweep with
`python -m my_project.scripts.build_comparison runs/`.

At Stage 4, MLflow replaces manual comparison tables. See `references/mlflow-guide.md`.

---

## 3. Freshness & Caching Rules {#freshness-rules}

Some data is expensive to fetch. The workflow needs explicit rules about when
to reuse cached data vs. re-fetch.

**Example rule:** "Do not pull SNOW incident data from Splunk again within 48
hours because results won't materially change."

### Implementation

Track freshness with a metadata file next to the frozen input snapshot:

```json
// rawdata/incidents.meta.json
{
  "source": "splunk",
  "query": "index=* sourcetype=snow:incident",
  "fetched_at": "2026-03-08T14:00:00Z",
  "freshness_hours": 48,
  "row_count": 12450
}
```

The `src/<project>/analysis/data_loader.py` module (see `code-templates.md`)
uses `_is_fresh()` helper functions prefixed with `_` while the public `raw_data_cached` function
participates in the module's public API.

### DVC freshness (Stage 3)

DVC handles this natively when you intentionally materialize a frozen input snapshot:

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

## 4. DVC Integration Patterns {#dvc-integration}

When to add DVC (Stage 3):

### Stage caching — wrapping a Hydra script

```yaml
# dvc.yaml
stages:
  baseline:
    cmd: python -m my_project.scripts.run
    deps:
      - rawdata/incidents.csv
      - src/my_project/analysis/baseline.py
      - src/my_project/scripts/run.py
    params:
      - conf/config.yaml:
          - baseline.resample_freq
    outs:
      - runs/baseline/
```

### Stage caching — wrapping a Kedro pipeline

```yaml
# dvc.yaml
stages:
  baseline:
    cmd: kedro run --pipeline=baseline
    deps:
      - rawdata/incidents.csv
      - src/my_project/analysis/baseline.py
      - src/my_project/pipelines/baseline/pipeline.py
    params:
      - conf/base/parameters.yml:
          - baseline.resample_freq
    outs:
      - runs/baseline/
```

DVC skips the stage if inputs, code, and params haven't changed.

### How Hydra, Kedro, and DVC divide concerns

| Concern | Tool |
|---------|------|
| Config composition, sweeps | Hydra |
| Pipeline DAG execution, data catalog | Kedro (if used) |
| Persistent caching of expensive stages | DVC |
| Long-term experiment comparison | DVC experiments |
| Source data freshness rules | DVC frozen stages |
| Remote artifact sharing | DVC remotes |

All three coexist well. Hydra manages config; Kedro manages pipeline execution
(optional); DVC manages artifact caching and versioning.

---

## 5. AI Self-Review Checklist {#ai-review}

After every run, the AI should programmatically check:

### Data validation

- Row counts are plausible (not 0, not absurdly large)
- No unexpected NaN or Inf values in key columns
- Date ranges cover the expected window
- Categorical values match expected sets

### Metrics validation

- All metrics in `metrics.json` are finite numbers
- Precision, recall, F1 are in [0, 1]
- Counts are non-negative integers
- Results change meaningfully across parameter settings (not all identical)

### Figure validation (via vision)

- Figures are non-trivial (not blank, not all-zero)
- Axes are labeled and readable
- Time series cover the expected date range
- Anomaly markers (if any) are visible

### Cross-run validation

- Comparison table has one row per run
- No duplicate run IDs
- Metrics vary across runs (if all identical, something is wrong)
- Best config is identified and noted

**Report findings to the human** along with the comparison table and key figures.
The human reviews the same artifacts in the marimo report app.
