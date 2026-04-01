# Examples Overview

## Tested End-to-End Examples

These examples use the NER graph model (`references/runner/`):

- **`revspin/`** — Table extraction with click-to-sort, numeric pagination, and multi-row extraction via `expand: elements`. Includes quality gate. **~200 records.**
  - `revspin_durable.yaml` — NER profile: state checks, click actions, page expansion, element expansion with 15 text extractions per row
  - `run_revspin_durable.py` — original Python runner (kept for reference)
  - `revspin_durable_top2pages.csv` — original output from Python runner

- **`splunk-itsi-admin/`** — Multi-page doc site scraper: BFS expansion discovers all TOC links, second resource extracts title + body from each page. Assembles into markdown.
  - `profile.yaml` — two-resource NER profile with BFS URL discovery → page extraction
  - `run.mjs` — custom Node.js runner (pre-dates the generic runner)
  - `output/` — generated markdown and JSONL

## Template Fragments

Short, composable YAML snippets in `templates/`:

| Template | NER concepts demonstrated |
|---|---|
| `pagination.yaml` | `expand: { over: pages }` with next-button strategy |
| `table-extract.yaml` | Table extraction with header-based column mapping |
| `matrix.yaml` | `expand: { over: combinations }` with auto-discover |
| `element-click.yaml` | Click actions with uniqueness tracking + nested expansion |
| `sort-verify.yaml` | Action + child state check as transition verification |
| `chaining.yaml` | Multi-resource pipeline with BFS expansion |
| `ai-extract.yaml` | AI extraction on captured HTML via `input` field reference |
| `ai-enrich.yaml` | Deterministic extraction + AI classification via `categories` |

Combine template fragments — they are composable pieces, not alternatives.
