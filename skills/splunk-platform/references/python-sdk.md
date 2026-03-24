# Splunk Python SDK Reference

Use this for:

- Python CLIs, jobs, and back-end services that talk to Splunk
- `splunklib` usage
- search job lifecycle management
- parsing results into JSON/CSV/DataFrames
- safe agent-facing Splunk backends

This is the default automation path for Splunk unless the user has a strong JS
or in-app reason not to use Python.

## Default Stack

- `splunklib.client` for connection, jobs, and object APIs
- `splunklib.results` for parsing streamed results
- `requests` only when you need exact raw REST or export behavior

## When Python Is The Right Tool

Use Python when the deliverable is:

- a CLI under `tools/`
- notebook/export support code
- a service that runs searches and returns structured results
- a validation or audit script
- an MCP server implementation

Do not build a Splunk app if all you need is one of the above.

## Authentication Defaults

### Bearer token

Default for automation:

```python
import os
import splunklib.client as client

service = client.connect(
    host="splunk.example.com",
    port=8089,
    splunkToken=os.environ["SPLUNK_TOKEN"],
    autologin=True,
)
```

### Username/password

Use only when token auth is unavailable:

```python
service = client.connect(
    host="splunk.example.com",
    port=8089,
    username=os.environ["SPLUNK_USER"],
    password=os.environ["SPLUNK_PASSWORD"],
    autologin=True,
)
```

Keep secrets out of source code and notebooks.

## Search Mode Selection

### `oneshot`

Use only for small, bounded results. Good for quick discovery queries and
short admin lookups. Bad for large exports.

### blocking job

Use when you want the SDK to wait for completion and then fetch results. Good
for moderate searches in CLIs.

### async job

Use when you need:

- progress polling
- retries
- result paging
- access to job metadata
- long-running searches

### raw export

Use raw REST export when you need streaming semantics. See
`rest-search-patterns.md` for endpoint details.

## Result Parsing Pattern

```python
import io
from splunklib import results

reader = results.JSONResultsReader(io.BytesIO(job.results(output_mode="json")))
rows = [item for item in reader if isinstance(item, dict)]
```

Keep parsing separate from downstream normalization. That makes the same code
reusable for CLI output, notebooks, CSV export, and MCP tools.

## Recommended Structure

- `connect()` builds the authenticated service
- `build_search()` applies time bounds and guards
- `run_search()` handles mode selection
- `parse_results()` normalizes rows
- `write_output()` handles CSV/JSON files

Do not mix query construction, execution, parsing, and file output in one large
function.

## SDK Vs Raw REST

Use the SDK for:

- most search jobs
- saved searches and other object APIs
- moderate result sets
- simpler code and less endpoint plumbing

Use raw REST for:

- export streaming
- exact output modes and transport control
- unsupported SDK edge cases

## Safe Search Construction

- Add `earliest_time` and `latest_time`.
- Prefix with `search ` when the query is not already generating.
- Add limits or paging.
- Bias toward read-only SPL.
- Reject or explicitly gate side-effecting commands for agent-facing tools.

## Good Fits

- inventory script for indexes/apps/users
- export script for notebooks
- lookup of saved searches or dashboards
- MCP server tool implementation
- admin audit that emits JSON/CSV

## Poor Fits

- browser-side code
- dashboard rendering logic
- full add-on packaging

For those, route to JS SDK, dashboard, or UCC references instead.

## Sources

- https://github.com/splunk/splunk-sdk-python
- https://help.splunk.com/en/splunk-enterprise/search/search-manual/9.3/export-search-results/export-data-using-the-splunk-sdks
- https://help.splunk.com/en/splunk-enterprise/leverage-rest-apis/rest-api-tutorials/10.0/rest-api-tutorials/creating-searches-using-the-rest-api
