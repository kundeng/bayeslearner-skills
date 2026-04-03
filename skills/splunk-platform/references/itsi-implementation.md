# ITSI Implementation Reference

Use this for:

- creating or importing ITSI entities and services
- configuring ITSI entity integrations and HEC inputs
- linking services to service templates
- creating KPI base searches as reusable building blocks
- creating ITSI correlation searches that feed Episode Review
- defining notable event aggregation policies and episode behavior
- diagnosing why ITSI object automation works in one environment and fails in another

Use this alongside:

- `python-sdk.md` when the deliverable is Python automation
- `rest-search-patterns.md` when you need exact HTTP behavior
- `platform-admin.md` when filesystem-backed config changes or upgrades are involved

## Strong Defaults

- Prefer supported ITSI object workflows over direct KV-store mutation.
- Prefer bulk import for onboarding many services or entities.
- Prefer recurring saved searches plus `itsiimportobjects` when the source of truth already lives in Splunk.
- Prefer creating ITSI correlation searches in the ITSI app, not by hand-editing `savedsearches.conf`.
- Prefer explicit event aggregation filters and split-by fields over broad catch-all policies.
- Prefer starting from existing ITSI roles, teams, and service templates instead of creating standalone custom object models.

## Object Model You Should Think In

The ITSI REST schema exposes object types including:

- `entity`
- `entity_type`
- `service`
- `base_service_template`
- `kpi_base_search`
- `kpi_template`
- `kpi_threshold_template`
- `home_view`
- `deep_dive`
- `glass_table`
- `notable_event_aggregation_policy`
- `maintenance_calendar`
- `team`

Important boundary:

- ITSI stores configuration in KV store collections under `SA-ITOA`, but the docs explicitly warn not to update those collections directly. Use documented ITSI REST endpoints and supported import flows instead.

## REST Recipes

Use these recipes when the user asks to create ITSI objects programmatically.

Primary interfaces:

- `https://<host>:8089/servicesNS/nobody/SA-ITOA/itoa_interface/<object_type>`
- `https://<host>:8089/servicesNS/nobody/SA-ITOA/event_management_interface/<object_type>`

Important object types for common work:

- `entity`
- `service`
- `kpi_base_search`
- `base_service_template`
- `notable_event_aggregation_policy`
- `correlation_search`

### Generic CRUD pattern for ITSI objects

The extracted ITSI REST reference shows a consistent pattern for `itoa_interface` objects:

- `GET /itoa_interface/<object_type>` to list/filter
- `POST /itoa_interface/<object_type>` to create
- `POST /itoa_interface/<object_type>/<key>?is_partial_data=1` to patch an object
- `POST /itoa_interface/<object_type>/bulk_update?is_partial_data=1` to patch many objects
- `DELETE /itoa_interface/<object_type>/<key>` to delete one object
- `GET /itoa_interface/<object_type>/count` to count matching objects

Practical rules:

- prefer `_key`-based deletion instead of filter-based deletion
- use `is_partial_data=1` for patch-style updates
- use `fields=` and `filter=` aggressively when reading objects

### Discover supported object types

```bash
curl -k -u admin:password \
  https://localhost:8089/servicesNS/nobody/SA-ITOA/itoa_interface/get_supported_object_types
```

### List objects with a filter

```bash
curl -k -u admin:password \
  "https://localhost:8089/servicesNS/nobody/SA-ITOA/itoa_interface/entity?fields=title,_key&filter={\"entity_type\":\"API\"}"
```

### Count matching objects

```bash
curl -k -u admin:password \
  "https://localhost:8089/servicesNS/nobody/SA-ITOA/itoa_interface/entity/count/?filter={\"title\":{\"$regex\":\".*mysql\"}}"
```

### Patch an existing object

```bash
curl -k -u admin:password \
  "https://localhost:8089/servicesNS/nobody/SA-ITOA/itoa_interface/entity/<_key>?is_partial_data=1" \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"description":"foo"}'
```

### Bulk patch many objects

```bash
curl -k -u admin:password \
  "https://localhost:8089/servicesNS/nobody/SA-ITOA/itoa_interface/entity/bulk_update?is_partial_data=1" \
  -X POST \
  -H "Content-Type: application/json" \
  -d '[{"_key":"object-1","description":"foo"}]'
```

### Read back a specific object

```bash
curl -k -u admin:password \
  "https://localhost:8089/servicesNS/nobody/SA-ITOA/itoa_interface/entity?filter={\"title\":\"bar\"}"
```

The extracted response shows the shape you can expect from an entity readback, including:

- `_key`
- `title`
- `identifier.fields`
- `identifier.values`
- `informational.fields`
- `informational.values`
- `services`
- `object_type`

### Delete safely

```bash
curl -k -u admin:password \
  https://localhost:8089/servicesNS/nobody/SA-ITOA/itoa_interface/entity/60d9300f-0942-4bda-bdec-5ad4baf633b6 \
  -X DELETE
```

The docs explicitly warn that bad filter syntax can delete all rows for the object type. For destructive operations, prefer `_key` endpoints over filter deletes.

## Entity REST Recipes

### Create a single entity

This example is directly present in the extracted ITSI REST reference:

```bash
curl -k -u admin:password \
  https://localhost:8089/servicesNS/nobody/SA-ITOA/itoa_interface/entity \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "component":["PerProcess"],
    "informational":{"fields":["info"],"values":["field"]},
    "_version":"3.0.0",
    "title":"PerProcess",
    "object_type":"entity",
    "_type":"entity",
    "identifier":{"fields":["component"],"values":["PerProcess"]}
  }'
```

Expected response shape:

```json
{"_key":"8b12efff-d81d-409e-8607-35d504e7b4a1"}
```

### Entity payload guidance

Minimum useful fields from the extracted example and schema:

- `title`
- `object_type: "entity"`
- `_type: "entity"`
- `identifier.fields`
- `identifier.values`

Often useful:

- `informational.fields`
- `informational.values`
- `sec_grp`
- entity-specific alias fields such as `host`

### Verify the created entity

```bash
curl -k -u admin:password \
  "https://localhost:8089/servicesNS/nobody/SA-ITOA/itoa_interface/entity?fields=title,_key&filter={\"title\":\"PerProcess\"}"
```

## Service REST Recipes

### Create a service

The extracted docs expose the service schema and a service-shaped template, but not a short standalone create example. The reliable pattern is:

1. create a minimal service payload with `POST /itoa_interface/service`
2. read it back
3. patch in additional KPI or dependency fields with `is_partial_data=1`

Minimal service recipe:

```bash
curl -k -u admin:password \
  https://localhost:8089/servicesNS/nobody/SA-ITOA/itoa_interface/service \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "title":"API Service",
    "object_type":"service",
    "_type":"service",
    "_version":"4.21.0",
    "enabled":1,
    "sec_grp":"default_itsi_security_group",
    "base_service_template_id":""
  }'
```

Use this as a starting point, then patch richer service content after the object exists.

Fields called out by the schema excerpt in the extracted docs:

- `_key`
- `base_service_template_id`
- service dependency arrays such as `services_depends_on`

### Link a service to a service template

The extracted reference includes a dedicated endpoint:

```bash
curl -k -u admin:password \
  -X POST \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  --data '{"_key":"491b90d8-62f3-4aeb-be9e-6ccb0b7e63b8"}' \
  https://localhost:8089/servicesNS/nobody/SA-ITOA/itoa_interface/service/6b0dda59-de86-4b9d-8817-460b5091d28c/base_service_template
```

Read the currently linked template:

```bash
curl -k -u admin:password \
  https://localhost:8089/servicesNS/nobody/SA-ITOA/itoa_interface/service/6b0dda59-de86-4b9d-8817-460b5091d28c/base_service_template
```

### Generate a service template from an existing service

The extracted REST reference says `templatize` is supported for service and KPI base search objects.

```bash
curl -k -u admin:password \
  https://localhost:8089/servicesNS/nobody/SA-ITOA/itoa_interface/service/<_key>/templatize
```

Use this when the fastest safe path is:

- create or refine one service manually
- derive a reusable template
- stamp that template onto additional services

## KPI Base Search REST Recipes

### Treat KPI base searches as first-class ITSI objects

The extracted schema explicitly lists `kpi_base_search` as a supported object type and notes that a service template can contain inherited KPI base search references.

Use the same CRUD pattern:

```bash
curl -k -u admin:password \
  https://localhost:8089/servicesNS/nobody/SA-ITOA/itoa_interface/kpi_base_search \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "title":"CPU Base Search",
    "object_type":"kpi_base_search",
    "_type":"kpi_base_search",
    "_version":"4.21.0"
  }'
```

Because base-search payloads get detailed quickly, a strong pattern is:

1. create one base search manually in ITSI
2. call `templatize`
3. reuse that returned JSON as the seed payload for automation

```bash
curl -k -u admin:password \
  https://localhost:8089/servicesNS/nobody/SA-ITOA/itoa_interface/kpi_base_search/<_key>/templatize
```

That is safer than inventing the full base-search shape from memory.

## Aggregation Policy REST Recipes

### Object family

Aggregation policies live under `event_management_interface`, not `itoa_interface`.

Use:

- `GET /event_management_interface/notable_event_aggregation_policy`
- `POST /event_management_interface/notable_event_aggregation_policy`
- `POST /event_management_interface/notable_event_aggregation_policy/<key>?is_partial_data=1`
- `GET /event_management_interface/notable_event_aggregation_policy/count`

The current Splunk docs describe `event_management_interface/<object_type>` as the generic CRUD surface for event-management objects, including aggregation policies and correlation searches.

### Create a notable event aggregation policy

The local extracts are stronger on aggregation-policy behavior than short create payloads, so this recipe uses the documented generic event-management upsert pattern plus the filtering/split-by semantics from the Event Analytics docs.

```bash
curl -k -u admin:password \
  https://localhost:8089/servicesNS/nobody/SA-ITOA/event_management_interface/notable_event_aggregation_policy \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "title":"Disk Alerts By Host",
    "object_type":"notable_event_aggregation_policy",
    "description":"Group disk alerts into host-local episodes",
    "rule_condition":"AND",
    "filtering_criteria":[
      {"field":"description","operator":"matches","value":"*disk*"}
    ],
    "split_by_fields":["host"],
    "disabled":0
  }'
```

Treat the field names above as a starter shape, then validate against the exact 4.21 schema in the ITSI REST API docs for your target object model.

### Patch an existing aggregation policy

```bash
curl -k -u admin:password \
  "https://localhost:8089/servicesNS/nobody/SA-ITOA/event_management_interface/notable_event_aggregation_policy/<_key>?is_partial_data=1" \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"split_by_fields":["host","application"]}'
```

### Verify policy behavior

After creation, verify three things:

- the policy exists through the REST readback
- the policy is enabled
- Episode Review shows events grouping the way the filter and split-by logic intended

## Correlation Search REST Recipes

Correlation searches also live under `event_management_interface`.

Read them with:

```spl
| rest splunk_server=local /servicesNS/nobody/SA-ITOA/event_management_interface/correlation_search report_as=text
```

Important manual-step rule from the docs:

- do not create correlation searches by editing `savedsearches.conf`
- create them in the ITSI app so they appear in the lister and behave correctly

For agent workflows, that means:

- document the manual UI path for humans
- automate only when the environment already uses the supported ITSI correlation-search REST/UI surface

## Python Pattern

If the user wants Codex or Claude to write Python automation, use `requests` or `splunklib` for auth, but call these ITSI endpoints explicitly.

Example helper:

```python
import os
import requests

BASE = os.environ["SPLUNK_BASE_URL"].rstrip("/")
HEADERS = {
    "Authorization": f"Bearer {os.environ['SPLUNK_TOKEN']}",
    "Content-Type": "application/json",
}

def post_itsi(path: str, payload: dict):
    resp = requests.post(
        f"{BASE}{path}",
        headers=HEADERS,
        json=payload,
        timeout=120,
    )
    resp.raise_for_status()
    return resp.json()
```

Entity example:

```python
entity = {
    "title": "PerProcess",
    "object_type": "entity",
    "_type": "entity",
    "_version": "3.0.0",
    "identifier": {"fields": ["component"], "values": ["PerProcess"]},
    "informational": {"fields": ["info"], "values": ["field"]},
    "component": ["PerProcess"],
}

created = post_itsi("/servicesNS/nobody/SA-ITOA/itoa_interface/entity", entity)
print(created["_key"])
```

## Manual Steps To Pair With Automation

When writing instructions for humans alongside code, document these checkpoints:

1. Confirm the operator has `itoa_admin` or `itoa_team_admin` plus any required Global-team write access.
2. For entity integrations, confirm HEC is enabled and the token/index settings are correct.
3. For recurring service/entity onboarding, create the saved search in the `itsi` app and verify it appears in the import workflow.
4. For correlation searches, create or verify them in the ITSI app, not by editing conf files directly.
5. After automation runs, verify objects in the ITSI UI as well as through REST readback.

## Entities And Services

### Entity creation modes

The extracted ITSI docs call out three supported manual creation/import paths:

- create a single entity
- import entities from a search
- import entities from a CSV file

After the initial import, set up recurring imports to create new entities and update existing ones.

Operational constraint from the docs:

- all entities live in the Global team
- only users with write access to the Global team can create single entities
- only users with the `itoa_admin` role can import entities from CSV or search

### Entity integrations

Use entity integrations when the goal is not just "make objects exist" but also "continuously discover entities and collect the right metrics and dashboards for them."

Examples called out in the extracted material:

- Unix and Linux
- Windows
- VMware vSphere
- Splunk Infrastructure Monitoring

These integrations give ITSI enough entity context to power Entity Overview, Event Data Search, and Entity Analytics.

### HEC setup for entity integrations

ITSI entity integrations rely on HEC for some data sources. The extracted docs include a concrete configuration path.

If you need one token for broad ITSI integration intake, configure:

- `sourcetype = itsi_im_metrics`
- `App context = Splunk_TA_Infrastructure`
- allowed indexes including `main` and `itsi_im_metrics`
- default index `itsi_im_metrics`

Concrete `inputs.conf` stanza from the docs:

```ini
[http://<token_name>]
disabled = 0
index = itsi_im_metrics
indexes = itsi_im_metrics, main
sourcetype = itsi_im_metrics
token = <string>
```

If the user is on Splunk Cloud and HEC is not already enabled, the docs say to involve Splunk Support.

### Best path for bulk creation

For many services or entities, use ITSI's supported import flow instead of trying to hand-construct every object over raw REST.

Use cases:

- create many services from CMDB or inventory search results
- associate entities to services
- link imported services to service templates
- keep imports recurring from a saved search

### Search-driven import workflow

ITSI supports importing services from:

- ad hoc searches
- saved searches
- ITSI module searches

When importing from a search:

- search results must be tabular
- a `service_title`-style column drives service creation
- entity columns can create entities and associate them to services
- template-link columns can attach service templates during import

The underlying supported mechanism is the `itsiimportobjects` workflow. Imported events are tracked in the `itsi_import_objects` index with sourcetype `itsi_import_objects:csv`.

### Concrete saved-search pattern

When you want recurring imports, create a saved search in the `itsi` app and trigger the ITSI import action from its results.

Practical rules pulled from the docs:

- title saved searches as `IT Service Intelligence - <custom text>` so they appear in the ITSI import UI
- set the app to `IT Service Intelligence (itsi)`
- make the saved search visible to all apps if the ITSI workflow needs to discover it
- restart Splunk after creating the saved search so it is reflected in `savedsearches.conf`

### Example recurring-import search

```spl
| inputlookup cmdb_hosts.csv
| eval service_title=coalesce(service_title, application)
| eval entity_title=coalesce(entity_title, host)
| table service_title entity_title team description
```

Use this as the producer search and let the ITSI import workflow handle object creation and updates on a schedule.

### Example search for service/entity onboarding

```spl
| inputlookup cmdb_hosts.csv
| rename application as service_title host as entity_title owner_team as team
| table service_title entity_title team description
```

Use the ITSI import UI or a scheduled import flow to map:

- `service_title` to service name
- `entity_title` to entity creation/association
- `team` to the service team
- extra columns to template parameters or entity-rule values

### Conflict-resolution decisions matter

When using import flows, choose conflict handling deliberately:

- `Skip Over Existing Entities` when source data is append-only
- `Update Existing Entities` when you want merges
- `Replace Existing Entities` when the source of truth should overwrite imported entity state

Also choose the conflict-resolution field carefully because ITSI uses that field to decide whether two imported rows refer to the same entity.

## Service Templates And KPIs

Use service templates when you need:

- repeatable KPI definitions across many services
- shared entity-rule logic
- centralized changes to commonly structured services

Import guidance:

- if you link imported services to a template, ITSI applies the template's KPIs and entity rules
- if a service already exists, ITSI can replace the service's entity rules with the template's rules
- if the template has configurable entity-rule values, your import search must provide those columns

### KPI base searches

Treat KPI base searches as reusable search definitions shared across KPIs.

Use them when:

- several KPIs read from the same dataset
- you want one place to evolve the search logic
- service templates should stamp out KPI families consistently

Do not duplicate near-identical SPL across each KPI when a base search is the real reusable unit.

## Event Aggregation Policies

Use notable event aggregation policies when the goal is to correlate many notable events into meaningful episodes.

Core design steps:

1. Define filtering criteria that decide which events a policy should process.
2. Define split-by fields that decide when matching events belong in separate episodes.
3. Keep a default policy in mind for events not matched by more specific policies.

### Filtering rules

Filtering criteria are effectively grouped WHERE-like clauses over notable-event fields.

Practical rules from the docs:

- field-value matching is exact, including capitalization and spaces
- `*` wildcards are allowed
- combine predicates with `AND`
- start a new rule block with `OR`
- if you filter on original event fields that conflict with fields in `itsi_tracked_alerts`, use the `orig_` prefix such as `orig_sourcetype`

### Split-by fields

Use split-by fields to avoid giant cross-system episodes.

Good defaults:

- split by `host` when incidents should stay host-local
- split by `datacenter`, `application`, or service-identifying fields when each combination deserves its own episode

Bad default:

- no split-by logic on a broad policy that matches many teams or systems

### Concrete policy design example

If the operational goal is "group disk alerts per host":

- filter on a description or source field that identifies disk alerts
- split by `host`
- avoid adding unrelated storage and CPU alerts into the same policy unless that is actually desired episode behavior

If the goal is "group incidents by application and site":

- filter on the event class for application-impacting alerts
- split by `application` and `datacenter`

## Correlation Searches And Episode Workflow

Event Analytics in ITSI follows a concrete pipeline:

1. ingest or search source data
2. create notable events through correlation searches or multi-KPI alerts
3. group notable events into episodes with aggregation policies
4. take automated or manual actions from Episode Review

### Correlation-search rules that matter

From the extracted docs:

- create correlation searches directly in the ITSI app
- do not manually edit `$SPLUNK_HOME/etc/apps/itsi/local/savedsearches.conf` for correlation searches because they will not appear on the correlation-search lister page

Good fit:

- monitoring service health scores
- ingesting third-party alerts as notable events
- normalizing external alerts into ITSI fields before aggregation

### Episode actions

Aggregation policies are not the whole workflow. ITSI also supports:

- episode action rules
- shipped actions like email or host ping
- ticketing integrations such as ServiceNow or Remedy
- custom actions through the notable event action SDK

If the task is "create aggregation policies," check whether the user also needs the downstream episode-action rules, because they are usually part of the same operational design.

### Event aggregation troubleshooting hooks

When grouping behaves unexpectedly, verify:

- the policy is enabled
- filtering criteria actually match the incoming notable-event field values
- split-by fields exist and have the expected raw values
- original event fields are referenced with `orig_` when required
- the default policy is not catching events you intended another policy to own

## Roles, Teams, And Access Control That Affect Build Work

This matters even for coding tasks because broken permissions can look like broken code.

Standard ITSI roles:

- `itoa_user`
- `itoa_analyst`
- `itoa_team_admin`
- `itoa_admin`

Important operational consequences:

- `itoa_team_admin` and `itoa_admin` cover service, KPI, entity, and notable-event aggregation-policy administration
- global objects often also require write access to the Global team
- team scoping affects what data is visible inside glass tables, deep dives, and service analyzers

When a custom role needs write access to ITSI views or collections, docs call out four areas:

1. capabilities in `authorize.conf`
2. access to ITSI indexes
3. view-level access in `itsi/metadata/local.meta`
4. KV-store collection access in `SA-ITOA/metadata/local.meta`

Concrete example from the docs:

- to let a custom role write deep dives, it needs the write capability, write access to the `saved_deep_dives_lister` view, and write access to the `itsi_pages` collection

## Files And Settings Worth Checking

When implementation or automation fails, inspect these before blaming the code:

- `$SPLUNK_HOME/etc/apps/itsi/local/authorize.conf`
- `$SPLUNK_HOME/etc/apps/itsi/metadata/local.meta`
- `$SPLUNK_HOME/etc/apps/SA-ITOA/metadata/local.meta`
- `savedsearches.conf` entries for recurring import searches
- `inputs.conf` for HEC token configuration used by entity integrations

Index access for custom ITSI roles often needs:

- `anomaly_detection`
- `itsi_grouped_alerts`
- `itsi_notable_archive`
- `itsi_notable_audit`
- `itsi_summary`
- `itsi_summary_metrics`
- `itsi_tracked_alerts`
- optionally `snmptrapd`

## Code-First Delivery Pattern

If the user asks for code to automate ITSI setup, prefer this order:

1. generate or validate the source search producing service/entity rows
2. create or update the saved search in the `itsi` app when recurring imports are needed
3. automate supported REST or UI-adjacent object creation for templates and policies
4. verify resulting objects from ITSI, not by direct KV-store inspection

For Python implementations, keep separate functions for:

- authentication
- source-search creation or execution
- import or object-creation submission
- verification reads
- permission diagnostics

## Sources

- Extracted repo material: `skills/wise-scraper/examples/splunk-itsi-admin/output/splunk-itsi-administer-4.21.md`
- Extracted repo material: `skills/wise-scraper/tests/output/splunk-itsi-entity-events_itsi_pages_flat.md`
- Extracted repo material: `skills/wise-scraper/tests/output/splunk-itsi-docs_itsi_pages_flat.md`
- https://help.splunk.com/en/splunk-it-service-intelligence/splunk-it-service-intelligence/visualize-and-assess-service-health/4.18/create-services/import-services-from-a-search-in-itsi
- https://help.splunk.com/en/splunk-it-service-intelligence/splunk-it-service-intelligence/detect-and-act-on-notable-events/4.21/event-aggregation/configure-episode-filtering-and-breaking-criteria-in-itsi
- https://help.splunk.com/en/splunk-it-service-intelligence/splunk-it-service-intelligence/leverage-rest-apis/4.21/itsi-rest-api-schema/itsi-rest-api-schema
