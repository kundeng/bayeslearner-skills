# Splunk MCP Integration

Use this for:
- exposing Splunk to LLM tools through MCP
- building or reviewing a Splunk MCP server
- reasoning about AI-safe query guardrails

## Positioning

There does not appear to be a formal Splunk product doc for MCP comparable to
the SDK or UCC docs. The strongest current implementation reference is the
Splunk-hosted GitHub repo `splunk/splunk-mcp-server2`, which labels itself
"Unofficial."

Treat this area as implementation guidance, not stable platform contract.

## Core Concerns

- read-only-by-default tool design
- SPL validation and guardrails
- transport choice: stdio vs SSE/HTTP
- output sanitization for sensitive fields
- small, composable tools instead of one opaque "run anything" endpoint

## Recommended Tool Surface

- list indexes
- get index info
- list knowledge objects
- get metadata for hosts/sources/sourcetypes
- run validated search queries
- get server/user info
- explain/query-generation helpers only with guardrails

## Strong Default Shape

Use Python for the MCP server unless the broader platform already standardizes
on Node. Python lines up well with `splunklib`, admin scripts, and structured
result shaping.

Recommended separation:

- metadata tools
- search execution tools
- explanatory/generative helpers
- admin/system info tools

Do not collapse them into one high-privilege endpoint.

## Design Guidance

- Keep tools narrow and composable.
- Separate metadata discovery tools from raw search tools.
- Validate SPL against a safe command allowlist for read-mostly use cases.
- Return machine-readable structures, not only free-form text.
- Prefer server-side credential handling and never let prompts inject auth material.

## Validation Guidance

- require explicit earliest/latest times or apply bounded defaults
- reject obviously side-effecting SPL unless the tool is explicitly privileged
- constrain row counts
- normalize namespaces and object types
- log executed queries for auditability

## Safe Defaults

- read-only by default
- explicit max rows
- JSON/tabular output
- one tool per administrative concern
- user-facing helper tools separate from execution tools

## What Not To Do

- do not expose raw credentials to prompts
- do not let an LLM choose arbitrary admin endpoints without validation
- do not return full unbounded event payloads by default
- do not merge generation and execution in one tool without inspection points

## Sources

- https://github.com/splunk/splunk-mcp-server2
- https://deepwiki.com/livehybrid/splunk-mcp
