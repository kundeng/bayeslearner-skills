---
name: ck
description: Use when searching code with ck/seek for exact grep-style matches, semantic search, lexical search, hybrid search, index management, JSONL output for agents, or MCP server mode.
metadata:
  short-description: Semantic, lexical, and hybrid code search
---

# ck

Use `ck` (seek) when the task is about finding code by meaning or by exact text, especially in large repos where index-backed search helps.

## Search modes

| Mode | Flag | Index needed | Best for |
|------|------|-------------|----------|
| Regex (default) | `--regex` or none | No | Exact identifiers, literals, paths |
| Semantic | `--sem` | Auto-built | Conceptual queries ("error handling", "retry logic") |
| Lexical | `--lex` | Auto-built | Ranked full-text phrases |
| Hybrid | `--hybrid` | Auto-built | Keyword precision + semantic recall |

## When to use

- Use `ck --sem` for conceptual searches like "error handling", "authentication logic", or "retry logic".
- Use `ck --lex` when you want BM25-ranked full-text search.
- Use `ck --hybrid` when you want keyword precision plus semantic recall.
- Use plain `ck` with `-n`, `-r`, `-i`, `-w`, `-F`, `-C`, `-A`, and `-B` for grep-compatible exact search.
- Use `--jsonl` for agent pipelines and `--serve` when an MCP client should query the repo directly.

## When not to use

- Do not use semantic search for exact identifiers, literal strings, paths, or config keys. Use grep-style search instead.
- Do not guess at stale index state; check `--status` or `--status-verbose`, and rebuild with `--index` when results look off.
- Do not use `--serve` unless the workflow really needs MCP integration.

## Workflow

1. Start with the narrowest useful search.
   - `ck "TODO" src/`
   - `ck -n -r "fn main" .`
2. Switch to meaning-based search when exact text is missing.
   - `ck --sem "error handling" src/`
3. Tighten or broaden results with scores, thresholds, and limits.
   - `ck --sem --scores --threshold 0.7 "validation" src/`
   - `ck --hybrid --limit 5 "timeout" src/`
   - `ck --sem --limit 5 --threshold 0.8 "auth" src/`
4. Improve relevance with reranking.
   - `ck --sem "retry logic" --rerank src/`
   - `ck --sem "login" --rerank-model bge src/`
5. Use JSONL or JSON for tools and agents.
   - `ck --jsonl --sem --no-snippet "authentication" src/`
   - `ck --json --sem --limit 5 "bug fix" src/`
6. Check or manage the index when needed.
   - `ck --status .`
   - `ck --status-verbose .`
   - `ck --index --model nomic-v1.5 .`
   - `ck --index --model jina-code .`
   - `ck --switch-model nomic-v1.5 .`
   - `ck --clean-orphans .`
   - `ck --clean .`
   - `ck --add path/to/file.rs`
7. Expose ck to an MCP client when asked for agent integration.
   - `ck --serve`

## Defaults

- Semantic search defaults: top 10 results, threshold >= 0.6.
- `--topk` and `--limit` are aliases for limiting result count.
- Hybrid RRF scores are in 0.01–0.05 range (lower than semantic 0.0–1.0).

## Quick reference

- Exact text: `ck "pattern" path/`
- Semantic: `ck --sem "what the code does" path/`
- Lexical: `ck --lex "multi word phrase" path/`
- Hybrid: `ck --hybrid "keyword + concept" path/`
- Agent JSONL: `ck --jsonl --sem "concept" path/ --no-snippet`
- Agent JSON: `ck --json --limit 5 "query" path/`

## Practical notes

- `ck` is grep-compatible, but semantic and lexical modes auto-index the target path.
- `.ck/` is a cache directory. It can be rebuilt safely with `--index` or removed with `--clean`.
- Use `--exclude`, `--no-ignore`, or `--no-ckignore` only when you need to override default file filtering.
- Available embedding models: `nomic-v1.5` (8k context), `jina-code` (code-specialized).
