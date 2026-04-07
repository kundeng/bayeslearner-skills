---
name: ck
description: Use when searching code with ck/seek for exact grep-style matches, semantic search, lexical search, hybrid search, index management, JSONL output for agents, or MCP server mode.
metadata:
  short-description: Semantic, lexical, and hybrid code search
---

# ck

Use `ck` when the task is about finding code by meaning or by exact text, especially in large repos where index-backed search helps.

## When to use

- Use `ck --sem` for conceptual searches like "error handling", "authentication logic", or "retry logic".
- Use `ck --lex` when you want ranked full-text search.
- Use `ck --hybrid` when you want keyword precision plus semantic recall.
- Use plain `ck`, `-n`, `-R`, `-i`, `-w`, `-F`, `-C`, `-A`, and `-B` for grep-compatible exact search.
- Use `--jsonl` for agent pipelines and `--serve` when an MCP client should query the repo directly.

## When not to use

- Do not use semantic search for exact identifiers, literal strings, paths, or config keys. Use grep-style search instead.
- Do not guess at stale index state; check `--status` or rebuild with `--index` / `--reindex` when results look off.
- Do not use `--serve` unless the workflow really needs MCP integration.

## Workflow

1. Start with the narrowest useful search.
   - `ck "TODO" src/`
   - `ck -n -R "fn main" .`
2. Switch to meaning-based search when exact text is missing.
   - `ck --sem "error handling" src/`
3. Tighten or broaden results with scores and thresholds.
   - `ck --sem --scores --threshold 0.7 "validation" src/`
   - `ck --hybrid --topk 5 "timeout" src/`
4. Pull whole code units when a line snippet is not enough.
   - `ck --sem --full-section "retry logic" src/`
5. Use JSONL for tools and agents.
   - `ck --jsonl --sem --no-snippet "authentication" src/`
6. Check or manage the index when needed.
   - `ck --status .`
   - `ck --index --model bge-small .`
   - `ck --switch-model nomic-v1.5 .`
   - `ck --clean-orphans .`
   - `ck --add path/to/file.rs`
7. Expose ck to an MCP client when asked for agent integration.
   - `ck --serve`

## Default patterns

- Exact text: `ck "pattern" path/`
- Semantic: `ck --sem "what the code does" path/`
- Lexical: `ck --lex "multi word phrase" path/`
- Hybrid: `ck --hybrid "keyword + concept" path/`
- Agent output: `ck --jsonl --sem "concept" path/ --no-snippet`

## Practical notes

- `ck` is grep-compatible, but semantic and lexical modes may auto-index the target path.
- `.ck/` is a cache. It can be rebuilt safely.
- Use `--exclude`, `--no-ignore`, or `--no-ckignore` only when you need to override default file filtering.
