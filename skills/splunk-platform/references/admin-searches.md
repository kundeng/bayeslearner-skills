# Splunk Admin And Discovery Searches

Use this for:
- listing indexes, hosts, sources, sourcetypes
- inspecting users and current auth context
- auditing knowledge objects
- quick discovery of what exists in a Splunk instance

This reference absorbs the useful operational content that used to live in the
old `splunk-quick-searches` skill.

## Preferred Patterns

- `| rest /services/...` for config and object inspection
- `| metadata type=...` for hosts/sources/sourcetypes discovery
- `| tstats` when the task needs efficient summary-style aggregation
- raw event search only when you need event content, not inventory

## Core Ready-Made Searches

### Server info

```spl
| rest /services/server/info
| fields version build serverName os_name cpu_arch numberOfCores physicalMemoryMB licenseState kvStoreStatus server_roles health_info
```

### List indexes

```spl
| rest /services/data/indexes count=0
| fields title disabled frozenTimePeriodInSecs maxTotalDataSizeMB currentDBSizeMB totalEventCount datatype repFactor splunk_server
```

### Metadata discovery

```spl
| metadata type=sourcetypes index=*
| eval firstTimeIso=if(isnull(firstTime), "Never", strftime(firstTime, "%Y-%m-%dT%H:%M:%SZ"))
| eval lastTimeIso=if(isnull(lastTime), "Never", strftime(lastTime, "%Y-%m-%dT%H:%M:%SZ"))
```

### Current user

```spl
| rest splunk_server=local /services/authentication/current-context
| fields username roles defaultApp capabilities
```

### Saved searches

```spl
| rest /services/saved/searches count=0
| eval name=coalesce(name,title)
| fields name search cron_schedule disabled is_scheduled actions eai:acl.app eai:acl.owner
```

### Views / dashboards

```spl
| rest /services/data/ui/views count=0
| eval name=coalesce(name,title), is_dashboard=isDashboard
| fields name label is_dashboard eai:acl.app eai:acl.owner
```

### KV store stats

```spl
| rest /services/server/introspection/kvstore/collectionstats
| mvexpand data
| spath input=data
```

### Installed apps

```spl
| rest /services/apps/local count=0
| fields title version disabled visible configured author description
```

### Roles

```spl
| rest /services/authorization/roles count=0
| fields title imported_roles srchIndexesAllowed srchIndexesDefault srchFilter cumulativeSrchJobsQuota
```

### Macros

```spl
| rest /servicesNS/-/-/admin/macros count=0
| eval name=coalesce(name,title)
| fields name definition iseval disabled eai:acl.app eai:acl.owner
```

### Lookups

```spl
| rest /servicesNS/-/-/data/transforms/lookups count=0
| eval name=coalesce(name,title)
| fields name filename external_cmd collection match_type eai:acl.app eai:acl.owner
```

### Field extractions

```spl
| rest /servicesNS/-/-/data/props/extractions count=0
| eval name=coalesce(name,title)
| fields name attribute value type eai:acl.app eai:acl.owner
```

### Data models

```spl
| rest /services/datamodel/model count=0
| fields title acceleration eai:acl.app eai:acl.owner description
```

### Host volume by index

```spl
| tstats count where index=* by index host
| sort - count
```

## Safe Defaults

- Prefer read-only SPL.
- Avoid destructive commands in automation.
- Scope queries by index/time where possible.
- Prefer wildcard namespace REST searches for inventory and narrow namespaces for follow-up changes.

## High-Value Audit Areas

- indexes and retention/storage
- hosts/sources/sourcetypes present in the environment
- users, roles, and current auth context
- saved searches, alerts, macros, lookups, field extractions
- dashboards, views, and data models
- KV store health and collection sizes
- installed apps and add-ons

## Search Selection Guidance

- Use `metadata` for fast source/host/sourcetype discovery.
- Use `rest` when you need config objects or knowledge objects.
- Use `tstats` when the question is volume/distribution and accelerated stats
  can answer it efficiently.
- Use raw event searches only when you need actual event content.

## Knowledge Object Audit Order

Default order:

1. saved searches and alerts
2. dashboards/views
3. macros
4. lookups
5. field extractions
6. data models
7. apps and ownership/ACL context

That usually tells you more about how a Splunk environment behaves than event
sampling does.

## Key Admin Areas

- server info and instance health
- index inventory
- user and role context
- saved searches, alerts, macros, lookups, field extractions
- dashboards and views
- KV store collection stats

## Sources

- Splunk REST API reference: https://docs.splunk.com/Documentation/Splunk/latest/RESTREF
- Dashboard and object inspection can be done via `/services/...` endpoints surfaced through `rest`
