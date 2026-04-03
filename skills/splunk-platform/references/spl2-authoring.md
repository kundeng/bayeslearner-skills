# SPL2 Authoring Reference

Write correct SPL2 modules, searches, custom functions, custom types, and views.
Use this reference when the task involves writing, reviewing, or converting SPL2 code.

## When to Use SPL2

SPL2 is used in: Search & Reporting app (Search bar + module editor), Edge Processor
pipelines, Ingest Processor pipelines, Splunk Extension for VS Code, and REST API
endpoints. SPL2 requires Splunk Cloud Platform 10.2.2510+ or Splunk Enterprise 10.2+
(*nix only).

If the user's environment is pre-10.2, write SPL (not SPL2). Ask if unsure.

### What SPL2 Does NOT Support

- **SQL-style window functions**: no `OVER`, `PARTITION BY`, `row_number()`, `rank()`,
  `lag()`, `lead()`. Use `eventstats` (partition-like) or `streamstats` (running window)
  as partial substitutes. For full windowing, use `spl1` to embed SPL or post-process
  in Python/SQL.
- **`top`, `rare`, `chart`, `transaction`** and many other SPL commands — use `spl1` for these.

---

## Module Structure

A **module** is a file containing one or more SPL2 statements. Modules live inside
**namespaces** (analogous to folders). Statement types:

| Type | Syntax |
|------|--------|
| Search | `$name = FROM main \| where status=200` |
| Function | `function fname($x) { return $x * 2; }` |
| Type | `type id_number = int where ($value BETWEEN 100000 AND 999999)` |
| Import | `import de_threats from /emea/germany` |
| Export | Mark statements for export so other modules can import them |

### Naming Searches

Every search in a module **must** have a unique name starting with `$` + a letter:

```
$all_events = FROM main
$errors_only = FROM main | where status >= 400
```

In the standalone Search bar, the `$name =` prefix is not required — you can type
the search directly. But in the module editor, it is mandatory.

### Import / Export

```
// Import a single item
import de_threats from /emea/germany

// Import with relative path (up one level)
import shared_func from ../utils

// Path components starting with numbers need single quotes
import idx from /envs.splunk.'007wt23fe01'.indexes
```

Datasets in the same namespace are automatically available without import.

### Annotations

```
@run_as_owner;
```

Placed at the top of a module to enable RBAC-enforced views. Users can execute
searches in the module without direct access to underlying datasets.

### Namespace Hierarchy

Namespaces are **logical containers managed by the Splunk data orchestrator**, not
filesystem paths. Think of them like Splunk app namespaces, not directory trees.

- **Namespaces** = folders (can be nested, use dot notation internally)
- **Modules** = files inside folders
- Datasets (indexes, lookups) in the same namespace are automatically available
- Imported items are **pointers**, not copies — they execute against their source data

Path semantics:

| Path | Meaning |
|------|---------|
| `/emea/germany` | Fully qualified: namespace `emea`, child `germany` |
| `../` | Up one namespace level (relative) |
| `../../` | Up two namespace levels |
| `~indexes` | Shortcut for the built-in indexes namespace |
| `~/apps.app_name.lookups` | Shortcut to lookups in a specific app |
| `/envs.splunk.'007wt23fe01'.indexes` | Numeric path component (single-quoted) |

The `~` symbol is a **shortcut for `envs.splunk.<stack_name>`** — your Splunk
instance root. It is NOT the user's home namespace.

```
import main from ~indexes
// equivalent to: import main from /envs.splunk.<stack_name>.indexes

import * as address from ~/apps.my_app.lookups
import my_report from ~/apps.'search'.savedsearches
```

### Built-in Namespaces

All SPL2 namespaces start with `envs.splunk.<stack_name>`:

| Namespace suffix | Contains |
|------------------|----------|
| `.indexes` | All indexes on the instance |
| `.shunits` | Search head units in the stack |
| `.shunits.<sh_name>.apps` | All apps on that search head |
| `.shunits.<sh_name>.apps.<app>.lookups` | Lookups defined in the app |
| `.shunits.<sh_name>.apps.<app>.savedsearches` | Saved searches, reports, alerts |

### System-Provided Modules (Pipeline-Only)

Edge/Ingest Processor pipelines can import from system modules:

```
import route from /splunk.ingest.commands
import logs_to_metrics from /splunk/ingest/commands
```

Known system-provided commands: `route`, `logs_to_metrics`, `decrypt`, `ocsf`.
There is **no documented discovery command** for listing all system modules —
consult the Ingest Processor and Edge Processor docs.

---

## Syntax Rules — Critical Differences from SPL

### Quoting Rules (Most Common Mistake)

| Quote type | Purpose | Example |
|------------|---------|---------|
| Double quotes `"` | **All string values** | `WHERE user="ladron"`, `WHERE sourcetype="syslog"` |
| Single quotes `'` | **Field names** with special chars, spaces, dashes, wildcards | `SELECT 'host*' FROM main`, `AS 'Avg Usage'` |
| Backticks `` ` `` | **Search literals** (implicit AND between terms) | `` WHERE `invalid user sshd[5258]` `` |

**SPL2 is strict about this.** SPL is loose about quoting; SPL2 is not.

### Wildcards

| Context | Wildcard chars | Example |
|---------|---------------|---------|
| `where` and `eval` (LIKE operator) | `%` (multi-char), `_` (single-char) | `where ip like "192.%"` |
| All other commands | `*` (asterisk) | `fields 'host*'`, `search index=main host=www*` |

### Comments

```
// Single-line comment
/* Multi-line
   comment */
```

### Case Sensitivity for Clauses

Clause keywords must be **all uppercase or all lowercase**, never mixed:

- Valid: `FROM`, `from`, `GROUP BY`, `group by`, `ORDER BY`, `order by`
- Invalid: `Group By`, `Order By`, `From`

### Escape Character

Use backslash `\` to escape special characters in search strings.

### Named Function Arguments

Optional but improves readability:

```
round(num:2.555, precision:2)
if(predicate:code=200, true_value:"OK", false_value:"Error")
```

### Dot Notation for Nested Data

```
// Object access
| eval city = address.city
| eval city = address["city"]

// Array access (brackets only)
| eval first = items[0]
```

---

## Generating Commands — Starting a Search

### `from` Command (SQL-style, preferred for new SPL2)

Supports clauses: `FROM`, `WHERE`, `GROUP BY`, `SELECT`, `HAVING`, `ORDER BY`.
Two valid orderings:

```
// Start with FROM (recommended)
FROM main WHERE earliest=-5m@m AND latest=@m
  GROUP BY host
  SELECT sum(bytes) AS total, host
  HAVING total > 1048576

// Start with SELECT
SELECT sum(bytes) AS total, host
  FROM main
  WHERE earliest=-5m@m
  GROUP BY host
```

Time bounds go in `WHERE` using `earliest=` and `latest=`:

```
FROM main WHERE earliest=-24h@h AND latest=@h
```

### `search` Command (SPL-style)

```
search index=main host=www3 action IN(addtocart, purchase)
search (code=10 OR code=29 OR code=43) host!="localhost" xqp>5
```

In the Search bar, `search` is implied when the first token is `index=`:
`index=main` works without the `search` keyword. In the module editor,
`search` must be explicit.

---

## Core Processing Commands

### Filtering

```
| where status >= 400
| where ipaddress like "192.%"
| where host="www1" AND action="purchase"
| where ipaddress=clientip          // field-to-field comparison
| dedup host                        // remove duplicate values
| head 50                           // first N results
| head while (action="purchase") null=true 50
```

### Field Selection

```
| fields host, src                  // keep only these
| fields - format, 'tmp_*'         // remove these (supports wildcards)
| table host, action                // output as table
| rename 'ip-add' AS IPAddress     // rename (single quotes for special chars)
```

### Eval — Compute New Fields

```
| eval velocity = distance / time
| eval error = if(status == 200, "OK", "Problem")
| eval full_name = first . " " . last         // string concatenation
| eval status_group = case(
    status < 300, "success",
    status < 400, "redirect",
    status < 500, "client_error",
    true, "server_error")
```

### Stats — Aggregation

```
| stats sum(bytes) BY host
| stats count() AS user_count BY action, clientip
| stats avg(duration) AS avg_dur, max(duration) AS max_dur BY status
```

**Important:** `count()` requires parentheses in SPL2. `stats count` alone is invalid.

### Sorting

```
| sort surname, -firstname          // prefix - for descending
```

Default sort is **lexicographical** — numbers sort by first digit (10 before 9).
Use `num()` or cast to get numeric sorting if needed.

### Time-Based Analysis

```
| timechart span=1m avg(CPU) BY host
| bin span=5m _time | stats avg(thruput) BY _time, host
| eventstats avg(duration) AS avgdur BY date_minute
| streamstats count() BY host
```

### Rex — Field Extraction via Regex

```
| rex field=savedsearch_id "(?<user>\\w+);(?<app>\\w+);(?<SavedSearchName>\\w+)"
```

Regex flavor is **PCRE** (Perl Compatible), not JavaScript.

### Joins, Unions, and Lookups

```
// Union multiple datasets
| union customers, orders, vendors

// Join
| join left=L right=R where L.product_id=R.product_id vendors

// Lookup
| lookup users uid OUTPUTNEW username, department
```

**Join limitations:**
- Right-side dataset capped at **50,000 rows**
- No interval/time-based join syntax
- No explicit `LEFT`/`RIGHT`/`FULL OUTER` keywords — SPL2 join is inner-join-like

For multi-source enrichment (e.g., correlating NAC + firewall + DNS), prefer
**lookup-based enrichment** chains over joins. Use `union` to combine datasets,
`lookup` for field enrichment, and views/modules to package reusable pipeline stages.

### Branch — Parallel Processing

Each branch must end with `into`. Nothing follows `branch` in the pipeline.

```
| from main
| branch
    [stats count() BY host | where count > 50 | select host | into popular_hosts],
    [stats count() BY source | where count > 100 | select source | into popular_sources]
```

### Into / Thru — Writing Output

```
| into mode=append mytable          // terminal — ends pipeline
| thru actions | eval field=expr    // writes AND passes data through
```

### Subsearches (append / appendcols / appendpipe)

```
| appendpipe [stats sum(user_count) AS 'User Count' BY action | eval user = "TOTAL"]
```

Default limits: max 5000 rows, 60-second timeout for subsearches.

### Embedded SPL — spl1 Command

For SPL commands not natively supported in SPL2:

```
// Use backtick syntax for inline SPL
from sample_data_index | stats sum(bytes) BY host | `addinfo`

// Or use spl1 explicitly
from main | spl1 "top 5 clientip BY categoryId"
```

`spl1` is **not supported in pipelines** (Edge/Ingest Processor).

### makeresults — Generate Test Data

```
| makeresults count=5
| streamstats count
| eval _time = _time - (count * 86400)
```

### Data Reshaping

```
| expand bridges              // array field → separate rows
| flatten bridges             // object keys → separate fields (first level)
| fillnull value="unknown" host, kbps
| replace str="aug" replacement="August" start_month, end_month
| convert dur2sec(xdelay), dur2sec(delay)
```

---

## Custom Eval Functions

Define reusable logic in modules. Parameters use `$` prefix.

### Basic Function

```
function severity_label($code) {
    return case(
        $code >= 500, "critical",
        $code >= 400, "error",
        $code >= 300, "warning",
        true, "info");
}

// Usage:
$labeled = FROM main | eval severity = severity_label(status)
```

### Typed Function

```
function to_original(
    $day: int, $month: string, $year: string,
    $time: string, $vendor: int, $code: string, $account: long
) {
    return "[${$day}/${$month}/${$year}:${$time}] VendorID=${$vendor} Code=${$code} AcctID=${$account}";
}
```

### Function Returning Regex

```
function original_regex(): regex {
    return /\[(?P<tmp_day>\d+)\/(?P<tmp_month>[A-z][a-z]*)\/(?P<tmp_year>\d+):(?P<tmp_time>\d+:\d+:\d+)\]\s+VendorID=(?P<tmp_vendor>\d+)\s+Code=(?P<tmp_code>[A-Z])\s+AcctID=(?P<tmp_acct>\d+)/;
}
```

### Using Custom Functions

```
$formatted = FROM raw_data | eval format_type = get_format(raw_field)
$parsed = FROM raw_data | rex field=raw_field original_regex()
```

Custom functions can be used in `eval`, `where`, type definitions, and other functions.

---

## Custom Command Functions

Two types:

- **Generating**: creates events, used as first command (like `from`, `makeresults`)
- **Non-generating**: processes piped data (like `stats`, `eval`)

---

## Custom Data Types

### Constrained Scalar Types

```
type id_number = int where ($value BETWEEN 100000 AND 999999)
type emp_type = string WHERE $value IN ("Full-time", "Part-time", "Contractor", "Intern")
```

### Regex-Validated Types

```
type email_address = string WHERE match($value, /(?P<Email>[a-zA-Z][a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})/);
type original_format = string WHERE match($value, original_regex());
```

### Structured (Object) Types

```
type customer_record = {
    customer: id_number,
    name: string,
    email: email_address,
    vip_member: boolean
}
```

### Type Checking in Expressions

```
// IS operator — checks against custom types
| where customer IS id_number
| where tojson() IS personnel_record

// Built-in type checks
| where isint(customer)
| where isstr(name)
| where isnull(value)
| where isnotnull(value)
```

`$value` in type definitions refers to the value being validated.

### Built-in Data Types

`string`, `number`, `int`, `double`, `long`, `boolean`, `array`, `object`, `regex`

---

## Views

A **view** is a named search exported from a module. Other modules import and use it
as a virtual dataset. Views are RBAC-enforced.

```
// In module: /security/curated
@run_as_owner;

$sanitized_logs = FROM main
  | fields - ssn, credit_card, password
  | where sourcetype="access_log"

// Export $sanitized_logs as a view

// In another module:
import sanitized_logs from /security/curated
$analysis = FROM sanitized_logs | stats count() BY status
```

---

## Expressions Quick Reference

### String Templates

Embed expressions in double-quoted strings with `${}`:

```
| eval message = "Host ${host} had ${count} errors"
| eval formatted = "[${$day}/${$month}/${$year}]"
```

### Predicate Expressions (return TRUE/FALSE)

```
status >= 400                     // comparison
status BETWEEN 200 AND 299       // range
action IN ("purchase", "view")   // set membership
host IS id_number                // type check
name like "John%"                // pattern match (LIKE)
NOT (status=200) AND host="www1" // boolean logic
```

### Search Literals

Backtick-enclosed terms with implicit AND:

```
WHERE `invalid user sshd[5258]`
// equivalent to: WHERE _raw LIKE "%invalid%" AND _raw LIKE "%user%" AND ...
```

---

## Pipeline Patterns (Edge Processor / Ingest Processor)

Pipelines have strict constraints — only a subset of SPL2 is available.

### Pipeline Structure

```
import route from /splunk.ingest.commands

$pipeline = | from $source
  | eval index = "staging"
  | into $destination;
```

### Pipeline Variables

| Variable | Role |
|----------|------|
| `$source` | Input data stream — always `\| from $source` at pipeline start |
| `$destination` | Output sink — always `\| into $destination` at pipeline end |
| `$pipeline` | The statement name for the pipeline definition |

`$source` and `$destination` are reserved names in Edge/Ingest pipelines.
Specialized variants exist: `$metrics_destination`, `$s3_destination`.

When a module **exports** `$pipeline`, downstream importers pipe data into it —
`$source` then represents whatever the upstream caller provides. If you hardcode
`FROM main` instead of `from $source`, the pipeline loses this composability.

### Available Pipeline Commands

`eval`, `fields`, `rename`, `rex`, `where`, `expand`, `flatten`, `lookup`,
`mvexpand`, `branch`, `into`, `from`, `thru`, `route`, `decrypt`, `ocsf`

### NOT Available in Pipelines

`stats`, `sort`, `search`, `dedup`, `join`, `head`, `table`, `timechart`,
`eventstats`, `streamstats`, `spl1`, `makeresults`, `appendpipe`, and most
aggregation/reporting commands.

### Route Command (pipeline-only)

```
import route from /splunk.ingest.commands

$pipeline = | from $source
  | route NOT (tojson() IS personnel), [
      | eval index = "staging"
      | into $destination
  ]
  | eval index = "personnel"
  | into $destination;
```

---

## SPL2 Command Quick Reference

### Commands Supported in SPL2

| | | | | |
|---|---|---|---|---|
| addinfo | expand | lookup | rex | timechart |
| append | fields | makemv | route | timewrap |
| appendcols | fieldsummary | makeresults | search | tstats |
| appendpipe | fillnull | mstats | sort | typer |
| branch | flatten | mvcombine | spath | union |
| bin | from | mvexpand | spl1 | untable |
| concat | head | nomv | stats | where |
| convert | into | ocsf | streamstats | |
| dedup | iplocation | rename | table | |
| eval | join | replace | tags | |
| eventstats | loadjob | reverse | thru | |

### Notable Commands NOT in SPL2

`top`, `rare`, `chart`, `transaction`, `inputlookup`, `outputlookup`,
`multisearch`, `map`, `collect` — use `spl1` to embed these when needed.

---

## Multi-Source Enrichment Patterns

SPL2 has no interval/time-based join. Use these patterns instead for correlating
data across indexes (e.g., NAC + Firewall + DNS).

### Pattern 1: Lookup-Chain Enrichment (Simplest)

Pre-compute mappings as lookups, then chain them in the final search:

```
$report = FROM datamodel:Network_Traffic
  | where action="allowed"
  | stats count() BY src_ip, dest_ip
  | lookup nac_ip_mapping.csv src_ip OUTPUT mac, device_type
  | where isnotnull(mac)
  | lookup device_inventory.csv mac OUTPUT manufacturer, model
  | lookup dns_cache.csv src_ip OUTPUT domain
  | table mac, manufacturer, model, src_ip, dest_ip, domain, count
```

### Pattern 2: Union + Stats Bucketing (Time-Correlated)

Union multiple sources, bucket by time, aggregate on shared key:

```
$correlated = union nac_summary, firewall_summary, dns_summary
  | bin span=5m _time
  | stats values(mac) AS mac, values(dest_ip) AS dest_ip,
          values(domain) AS domain BY src_ip, _time
```

### Pattern 3: Summary Index + Custom Data Model (Near-Realtime)

For recurring reports over large time windows:

1. Scheduled searches write pre-enriched results to a summary index
2. Custom data model unions the summary datasets under a common schema
3. `tstats` queries against the accelerated DM for near-realtime access

SPL2 modules can package each enrichment step as an exported view,
making the pipeline stages independently testable and reusable.

---

## Common Pitfalls — Avoid These

1. **Unquoted strings**: `WHERE user=admin` is wrong → `WHERE user="admin"`
2. **Mixed-case clauses**: `Group By` is invalid → use `GROUP BY` or `group by`
3. **count without parens**: `stats count` is invalid → `stats count()`
4. **`*` wildcard in where/eval**: use `like` with `%` instead → `where host like "www%"`
5. **Missing search name in module editor**: `FROM main` alone fails → `$name = FROM main`
6. **Using `top` directly**: not in SPL2 → use `` `top 5 host` `` or `spl1`
7. **Predicate in `search` command**: `search` uses SPL syntax, not expressions. Use `where` for expressions.
8. **Subsearch limits**: append/appendcols cap at 5000 rows, 60s timeout
9. **Lexicographic sort**: numbers sort as strings by default (10 before 9)
10. **Pipeline restrictions**: don't use `stats`, `sort`, `join`, `spl1` in Edge/Ingest pipelines
11. **`branch` is terminal**: nothing can follow it — each branch must end with `into`
12. **`tojson()` for type checking**: use `tojson() IS my_type` to check if a record matches a structured type
