# Splunk REST API And Search Patterns

Use this for:

- raw REST integrations
- `search/jobs`, `search/jobs/export`, and v2 search endpoints
- exact HTTP behavior that the SDK abstracts away
- cases where you need streaming results or tighter control over namespaces and params

## Default Choice

- Use the **SDK** when it cleanly covers the use case.
- Use **raw REST** when you need streaming export, exact endpoint behavior, or language/tooling neutrality.

For new automation, prefer server-side code that can authenticate once and then
issue narrow, explicit requests.

## Core Endpoints

- `POST /services/search/jobs`
  Use to create a search job and get a SID back.
- `GET /services/search/jobs/{sid}`
  Use to poll job state and inspect metadata.
- `GET /services/search/jobs/{sid}/results`
  Use for completed job results.
- `GET /services/search/jobs/{sid}/events`
  Use when you need raw events rather than transformed results.
- `POST /services/search/v2/jobs/export`
  Prefer for streaming-style export in new code when the v2 path is available.

## Mode Selection

### Managed search job

Use when you need:

- a persistent SID
- polling/retry logic
- access to job metadata
- paging over results

Default path:

1. create job
2. poll until done
3. fetch `results` or `events`

### Export / streaming

Use when you need:

- line-by-line or chunked streaming
- no persistent job object
- lower orchestration overhead
- direct export into files, pipelines, or parsers

Do not use export when you need later re-query of the same SID or job-level introspection.

## Request Defaults

- Include explicit `earliest_time` and `latest_time`.
- Prefix plain searches with `search ` when required.
- Request structured output such as JSON/JSON rows where possible.
- Set timeouts deliberately.
- Validate TLS in real deployments. Do not normalize `verify=False` as a best practice.

## Namespace Guidance

- Use the correct app/owner namespace when touching saved searches, views, configs, or knowledge objects.
- For broad inventory tasks, expect `/servicesNS/-/-/...` or equivalent wildcard paths.
- For automation that changes objects, scope namespaces tightly to the intended app and owner.

## Safe Search Defaults

Good defaults for automation and MCP:

- `search`
- `stats`
- `timechart`
- `tstats`
- `metadata`
- `rest`
- `table`
- `fields`
- `head`
- `sort`
- `where`

Escalate carefully for write-side or side-effecting commands:

- `outputlookup`
- `collect`
- `sendemail`
- `delete`
- `run`
- `script`

## Example: Managed Search Job

```python
import os
import requests

base = "https://splunk.example.com:8089"
headers = {"Authorization": f"Bearer {os.environ['SPLUNK_TOKEN']}"}

create = requests.post(
    f"{base}/services/search/jobs",
    headers=headers,
    data={
        "search": "search index=_internal | stats count by sourcetype",
        "earliest_time": "-24h",
        "latest_time": "now",
        "output_mode": "json",
    },
    timeout=120,
)
sid = create.json()["sid"]
```

## Example: Streaming Export

```python
import os
import requests

resp = requests.post(
    "https://splunk.example.com:8089/services/search/v2/jobs/export",
    headers={"Authorization": f"Bearer {os.environ['SPLUNK_TOKEN']}"},
    data={
        "search": "search index=main | head 1000",
        "earliest_time": "-1d",
        "latest_time": "now",
        "output_mode": "json_rows",
    },
    stream=True,
    timeout=300,
)

for chunk in resp.iter_lines():
    if chunk:
        print(chunk.decode("utf-8"))
```

## Cloud Caveats

- Splunk Cloud may require Support enablement for some REST/API access.
- Do not assume Enterprise-only admin endpoints are available in Cloud.
- When building for Cloud customers, bias toward app-safe and documented endpoints.

## Sources

- https://help.splunk.com/en/splunk-enterprise/search/search-manual/9.3/export-search-results/export-data-using-the-splunk-sdks
- https://help.splunk.com/en/splunk-enterprise/leverage-rest-apis/rest-api-tutorials/10.0/rest-api-tutorials/creating-searches-using-the-rest-api
- https://docs.splunk.com/Documentation/SplunkCloud/latest/RESTREF/RESTsearch
- https://github.com/splunk/splunk-sdk-python
