# Splunk Dashboard Development

Use this for:
- Dashboard Studio work
- classic XML dashboards
- dashboard JSON definitions
- dashboard-related app/view development

## Dig Deeper

- Use Context7 against Splunk developer docs when you need framework-specific dashboard details, especially Dashboard Studio JSON structure, Simple XML extension behavior, SplunkJS Stack modules, tokens, and `SearchManager` usage.
- Prefer Context7 here over generic web search because the useful details are usually buried in older Splunk developer pages.

## Framework Split

- Dashboard Studio: preferred modern dashboard framework
- Classic dashboards / Simple XML: legacy but still relevant in older apps and admin contexts
- SplunkJS/Web Framework: legacy extension path for existing apps, not the greenfield default

Avoid HTML dashboards and older deprecated dashboard frameworks for new work.

## Dashboard Studio Concepts

- dashboards are defined by JSON
- core sections commonly include `visualizations`, `dataSources`, `defaults`, `inputs`, and `layout`
- Studio is best for polished layouts and modern visual configuration
- treat dashboard JSON as source code and store it in version control
- think in terms of data sources plus visualization definitions, not ad hoc DOM customization

## Dashboard Studio Best Fit

Use Dashboard Studio when you need:

- new dashboards with modern layout control
- cleaner source-of-truth JSON artifacts
- rich visualization composition without SplunkJS extension code
- a dashboard that should remain mostly declarative

Do not choose Studio if the real requirement is deep legacy token/JS behavior
already implemented in Simple XML or SplunkJS.

## Simple XML Concepts

- root elements are typically `<dashboard>` or `<form>`
- hierarchy is row/panel/search/input oriented
- it remains useful for legacy apps and some fine-grained XML-only behavior
- token behavior and SplunkJS extensions still show up in older apps

## SplunkJS / Web Framework Context

- SplunkJS Stack exposes search managers and views in JavaScript
- SearchManagers correspond to Splunk search jobs, saved reports, and post-process searches
- Simple XML extensions sit on top of that stack for targeted JS/CSS customization

This matters because many older dashboards are really Simple XML plus
SearchManager-driven JavaScript, not just plain XML panels.

## Selection Guidance

- **New dashboard**: Dashboard Studio
- **Existing XML dashboard**: keep using Simple XML unless there is a strong reason to migrate
- **Custom app web UI**: be careful with older Splunk Web Framework patterns; some older HTML/dashboard customization routes are deprecated

## Practical Defaults

- Keep searches explicit and reusable.
- Push complicated data shaping into SPL or saved searches rather than ad hoc client logic.
- Limit custom JS/CSS to cases where built-in dashboard behavior is insufficient.
- Keep token names and input wiring deliberate; hidden token sprawl is a common maintenance problem.
- Treat SearchManagers as real orchestration objects with lifecycle and state, not invisible glue.

## Decision Rules

- **New analytical or operational dashboard**: Dashboard Studio.
- **Existing XML dashboard with token-heavy behavior**: keep Simple XML.
- **Existing dashboard with custom JS based on SplunkJS Stack/SearchManagers**: maintain in place unless you are deliberately redesigning it.
- **HTML dashboard request**: push back unless the task is explicitly legacy maintenance.

## Studio Vs Simple XML

- Use **Dashboard Studio** when presentation quality and layout flexibility matter.
- Use **Simple XML** when the existing app already depends on XML forms, tokens, and SplunkJS extension hooks.
- Do not migrate XML dashboards to Studio just because Studio is newer. Migrate only when the maintenance or UX benefit is real.

## Legacy Extension Guidance

If you are in a SplunkJS or Simple XML extension context:

- keep the scope narrow
- bind data and tokens explicitly
- avoid turning a dashboard into a mini application unless the app already works that way
- treat SearchManagers as real search job orchestration, not magic state
- load extension JS/CSS as app artifacts, not one-off local edits

## Migration Guidance

- Migrate to Studio for layout/UX improvements and simpler declarative maintenance.
- Stay on Simple XML when the cost of reproducing token and SplunkJS behavior outweighs the benefit.
- If you must migrate, first inventory inputs, tokens, SearchManagers, drilldowns, and custom JS dependencies.

## Sources As Code

- Dashboard Studio: JSON under app-managed view objects
- Simple XML: XML definitions plus optional JS/CSS extension files

Version all of them. Avoid one-off manual UI edits with no source artifact.

## Sources

- https://docs.splunk.com/Documentation/SplunkCloud/latest/DashStudio
- https://docs.splunk.com/Documentation/SplunkCloud/latest/DashStudio/dashDef
- https://docs.splunk.com/Documentation/SplunkCloud/latest/Viz/Overviewofdashboards
- https://docs.splunk.com/Splexicon%3ASimpleXML
- https://docs.splunk.com/Documentation/SplunkCloud/latest/Viz/PanelreferenceforSimplifiedXML
- https://docs.splunk.com/Documentation/Splunk/latest/Viz/OverviewofSimplifiedXML
- https://dev.splunk.com/enterprise/docs/developapps/visualizedata/usewebframework
- https://dev.splunk.com/enterprise/docs/developapps/visualizedata/simplexmlextensions/searchresultsmodel
