# MLflow Guide

MLflow is the **experiment tracking and model lifecycle** layer for the analytic
workbench in `operate` mode. It replaces manual comparison tables with a tracking server,
adds a model registry, and provides a comparison UI.

Do not treat it as the whole workflow. The workflow is defined by
`analytic-workbench`; MLflow is one layer inside `operate`.

## Table of Contents
1. [What MLflow Provides](#what-it-provides)
2. [Setup](#setup)
3. [Experiment Tracking](#tracking)
4. [Integration with Kedro](#kedro-integration)
5. [Model Registry](#model-registry)
6. [Comparison UI](#comparison-ui)
7. [Integration with marimo](#marimo-integration)
8. [When to Add MLflow](#when-to-add)

---

## 1. What MLflow Provides {#what-it-provides}

| Concern | MLflow feature | Replaces |
|---------|---------------|----------|
| Experiment tracking | `mlflow.log_params()`, `mlflow.log_metrics()` | Manual `metrics.json` + comparison tables |
| Artifact storage | `mlflow.log_artifact()` | Manual `runs/<run-id>/` folders |
| Comparison | MLflow UI comparison view | `runs/comparison.csv` |
| Model lifecycle | Model registry, stages | Manual model file management |
| Reproducibility | Run metadata, source tracking | Manual `config.yaml` per run |

---

## 2. Setup {#setup}

```bash
pip install mlflow           # or add to pyproject.toml: pip install -e ".[tracking]"
```

Start the tracking server locally:

```bash
mlflow ui                    # opens at http://localhost:5000
mlflow server --backend-store-uri sqlite:///mlflow.db --default-artifact-root ./mlruns
```

For team use, deploy a shared tracking server with a database backend and
remote artifact storage (S3, GCS, Azure Blob).

---

## 3. Experiment Tracking {#tracking}

### Basic logging

```python
import mlflow

mlflow.set_experiment("incident-analysis")

with mlflow.start_run(run_name="baseline_1h"):
    # Log parameters
    mlflow.log_params({
        "resample_freq": "1h",
        "window_size": 24,
        "anomaly_threshold": 3.0,
    })

    # Run analysis
    stats = run_analysis(params)

    # Log metrics
    mlflow.log_metrics({
        "total_count": stats["total_count"],
        "mean": stats["mean"],
        "precision": stats["precision"],
        "recall": stats["recall"],
        "f1": stats["f1"],
    })

    # Log artifacts
    mlflow.log_artifact("runs/baseline/figures/fig-timeseries.png")
    mlflow.log_artifact("runs/baseline/data/timeseries.csv")
    mlflow.log_artifact("runs/baseline/config.yaml")
```

### Autologging

For supported frameworks (scikit-learn, xgboost, lightgbm, etc.):

```python
mlflow.autolog()             # automatically logs params, metrics, models
```

---

## 4. Integration with Kedro {#kedro-integration}

Use `kedro-mlflow` to connect Kedro pipelines with MLflow tracking:

```bash
pip install kedro-mlflow
kedro mlflow init            # creates mlflow.yml in conf/
```

```yaml
# conf/base/mlflow.yml
server:
  mlflow_tracking_uri: http://localhost:5000

tracking:
  experiment:
    name: incident-analysis
  run:
    id: null
    name: null
  params:
    dict_params_strategy: flatten
```

With `kedro-mlflow`, pipeline parameters are automatically logged and metrics
datasets can be configured to log to MLflow.

Alternatively, log manually in a pipeline node:

```python
def log_to_mlflow(summary_stats: dict, params: dict) -> None:
    """Log experiment results to MLflow."""
    import mlflow
    with mlflow.start_run():
        mlflow.log_params(params)
        mlflow.log_metrics(summary_stats)
```

---

## 5. Model Registry {#model-registry}

When the workbench produces ML models:

```python
with mlflow.start_run():
    # ... training code ...
    mlflow.sklearn.log_model(model, "model")

    # Register for lifecycle management
    mlflow.register_model(
        f"runs:/{mlflow.active_run().info.run_id}/model",
        "incident-anomaly-detector",
    )
```

Model stages: `None` → `Staging` → `Production` → `Archived`.

---

## 6. Comparison UI {#comparison-ui}

The MLflow UI (`http://localhost:5000`) provides:

- Side-by-side run comparison with metric charts
- Parameter diff across runs
- Artifact browsing (figures, data files)
- Search and filter by parameters or metrics

This replaces the manual `runs/comparison.csv` for team-scale work.

---

## 7. Integration with marimo {#marimo-integration}

marimo can query MLflow for review surfaces:

```python
@app.cell
def _():
    import mlflow
    mlflow.set_tracking_uri("http://localhost:5000")
    return mlflow,

@app.cell
def _(mlflow, pd):
    experiment = mlflow.get_experiment_by_name("incident-analysis")
    runs = mlflow.search_runs(experiment_ids=[experiment.experiment_id])
    runs[["run_id", "params.resample_freq", "metrics.f1", "metrics.precision"]]
    return runs,
```

The notebook can display MLflow data alongside local artifacts for human review.

---

## 8. When to Add MLflow {#when-to-add}

Add MLflow when at least one of these becomes painful without it:

- Manual comparison tables can't keep up with the number of experiments
- Multiple team members need to share and compare results
- You need a model registry for staging/production lifecycle
- You want automatic parameter/metric logging without custom scripts
- Stakeholders want a web UI to browse experiments

If none of that hurts yet, stay at `experiment` with Kedro + DVC + manual
comparison tables.
