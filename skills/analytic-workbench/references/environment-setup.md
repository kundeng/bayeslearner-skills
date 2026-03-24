# Environment Setup Reference

## Table of Contents
1. [Environment Management](#env-management)
2. [pyproject.toml](#pyproject)
3. [Base Dependencies](#base-deps)
4. [Library Decision Rules](#library-rules)
5. [Optional Packages by Domain](#optional-packages)
6. [Scaffold Commands](#scaffold)

---

## 1. Environment Management {#env-management}

Use any Python environment manager. The skill does not prescribe one.

| Tool | Notes |
|------|-------|
| **uv** | Fast, modern. `uv venv && uv pip install -e .` |
| **conda / mamba** | Good for heavy native deps (BLAS, CUDA). `conda create -n wb python=3.12` |
| **poetry** | Lockfile-based. `poetry install` |
| **venv + pip** | Built-in. `python -m venv .venv && pip install -e .` |

Pick one and document it in the project README. The important thing is that the
project is installable via `pip install -e .` from `pyproject.toml`.

---

## 2. pyproject.toml {#pyproject}

Every project uses `pyproject.toml` as the single source of truth for metadata
and dependencies. Do not use bare `requirements.txt` as the primary definition.

```toml
[project]
name = "my-analysis"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = [
    "marimo",
    "polars",
    "duckdb",
    "pandas",
    "matplotlib",
    "pyyaml",
]

[project.optional-dependencies]
hydra = ["hydra-core", "omegaconf"]
kedro = ["kedro", "kedro-viz"]
automl = ["pycaret"]
forecasting = ["prophet", "neuralprophet"]
ml = ["scikit-learn", "xgboost", "lightgbm", "shap"]
timeseries = ["stumpy", "statsmodels"]
tracking = ["mlflow", "kedro-mlflow"]
dvc = ["dvc[s3]"]
dev = ["pytest", "ruff"]

[build-system]
requires = ["setuptools>=68"]
build-backend = "setuptools.backends._legacy:_Backend"

[tool.setuptools.packages.find]
where = ["src"]
```

Install the project in editable mode:

```bash
pip install -e ".[dev]"                          # Tier 1
pip install -e ".[hydra,dev]"                    # Tier 2
pip install -e ".[hydra,kedro,dev]"              # Tier 3 (with Kedro)
pip install -e ".[hydra,dvc,dev]"                # Tier 3 (with DVC)
pip install -e ".[hydra,kedro,dvc,dev]"          # Tier 3 (both)
pip install -e ".[hydra,kedro,dvc,tracking,dev]" # Tier 4
```

Generate a lockfile for reproducibility if your tool supports it (`uv lock`,
`pip freeze > requirements.lock`, `poetry lock`).

---

## 3. Base Dependencies {#base-deps}

Always installed (Tier 1):

| Package | Purpose |
|---------|---------|
| `marimo` | Reactive notebook / app frontend |
| `polars` | Fast dataframe transforms |
| `duckdb` | SQL analytics over files |
| `pandas` | Wide compatibility, common ecosystem default |
| `matplotlib` | Figures and charts |
| `pyyaml` | Config loading for handwired driver |

Added at Tier 2:

| Package | Purpose |
|---------|---------|
| `hydra-core` | Config composition, CLI overrides, multirun sweeps |
| `omegaconf` | Structured config (Hydra dependency, also useful standalone) |

Added at Tier 3 (choose one or both):

| Package | Purpose |
|---------|---------|
| `kedro` | Pipeline DAG, data catalog |
| `kedro-viz` | Interactive pipeline visualization |

Also at Tier 3:

| Package | Purpose |
|---------|---------|
| `dvc[s3]` | Stage caching, experiment tracking, remotes |

Added at Tier 4:

| Package | Purpose |
|---------|---------|
| `mlflow` | Experiment tracking, model registry |
| `kedro-mlflow` | Kedro-MLflow integration |

---

## 4. Library Decision Rules {#library-rules}

| Library | Use when | Avoid when |
|---------|----------|------------|
| **polars** | Fast transforms, lazy evaluation, large-ish data | Kedro catalog friction (some datasets expect pandas) |
| **duckdb** | SQL-oriented analytics, joins across CSVs/parquets, >1GB | Simple column transforms better as polars/pandas |
| **pandas** | Kedro catalog I/O (default), small-medium data, rich ecosystem | Performance-critical transforms on large data |

Prefer polars for transforms, pandas at Kedro catalog boundaries, duckdb for
ad hoc SQL queries over files.

---

## 5. Optional Packages by Domain {#optional-packages}

Install as needed. Add to `[project.optional-dependencies]` in pyproject.toml.

### AutoML & model screening

| Package | Use when |
|---------|----------|
| **pycaret** | Rapid model screening, baseline comparisons, AutoML |
| **auto-sklearn** | Sklearn-compatible AutoML (Linux only) |
| **FLAML** | Lightweight AutoML, fast search |

### Forecasting

| Package | Use when |
|---------|----------|
| **prophet** | Time-series with strong seasonality, holidays |
| **neuralprophet** | Prophet-like with neural network components |
| **statsforecast** | Fast statistical forecasting (ETS, ARIMA, Theta) |

### Machine learning

| Package | Use when |
|---------|----------|
| **scikit-learn** | Classification, regression, clustering, preprocessing |
| **xgboost** | Gradient-boosted trees, tabular data |
| **lightgbm** | Large tabular datasets, faster than xgboost on many tasks |
| **shap** | Model explainability, feature importance visualization |

### Time-series analysis

| Package | Use when |
|---------|----------|
| **stumpy** | Matrix profile: motifs, discords, anomaly detection |
| **statsmodels** | Statistical tests, ARIMA, decomposition |
| **tsfresh** | Automated time-series feature extraction |

### Visualization

| Package | Use when |
|---------|----------|
| **plotly** | Interactive charts in notebooks |
| **seaborn** | Statistical visualization |
| **altair** | Declarative grammar-of-graphics |

---

## 6. Scaffold Commands {#scaffold}

Bootstrap a new project:

```bash
# Tier 1: plain modules + handwired driver
mkdir -p src/my_project/analysis src/my_project/scripts src/my_project/tools \
         notebooks rawdata runs tests
touch src/my_project/__init__.py src/my_project/analysis/__init__.py

# Tier 2+: add Hydra config directory
mkdir -p conf/source conf/experiment

# Tier 3 (if adding Kedro): add pipeline structure
mkdir -p src/my_project/pipelines conf/base conf/local
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

Create `pyproject.toml` using the template in section 2, then:

```bash
python -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
```
