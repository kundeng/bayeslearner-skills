# splunk-platform-skill

`splunk-platform` is a deep, opinionated skill for Splunk development,
administration, dashboards, SDK/REST integrations, add-on engineering, ITSI
implementation, and AI-facing tooling.

It includes guidance for:

- SPL2 authoring: modules, searches, custom functions, types, views, and pipelines
- Python SDK and JavaScript SDK usage
- raw REST and search job/export patterns
- ITSI entities, services, KPI base searches, and event aggregation workflows
- admin and discovery SPL
- Dashboard Studio, Simple XML, and SplunkJS legacy boundaries
- UCC-based add-on development
- MCP integration patterns
- packaging and platform administration

## Install

With `skills.sh` / `npx skills`:

```bash
npx skills add https://github.com/kundeng/splunk-platform-skill -g --all
```

For a single skill from the repo:

```bash
npx skills add https://github.com/kundeng/splunk-platform-skill -g --skill splunk-platform --agent '*'
```

## Contents

- `SKILL.md`
- `references/`
- `evals/trigger-evals.json`
