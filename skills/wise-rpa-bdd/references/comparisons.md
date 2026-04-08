# Comparisons

Optional reading. The agent does not need this to build a suite. Read this when evaluating the BDD approach against alternatives.

## vs WISE Scraper (YAML Profiles)

| Dimension | WISE Scraper | WISE RPA BDD |
|---|---|---|
| **Deliverable** | YAML profile + extracted data | Executable .robot suite |
| **Format** | YAML (machine-friendly) | Robot Framework BDD (human-readable, executable) |
| **Readability** | Requires schema knowledge | Reads as natural language steps |
| **Validation** | JSON Schema + runner dry-run | BDD validator + Robot dryrun |
| **Execution** | TypeScript runner required | Robot Framework + keyword library |
| **AI fit** | Agent assembles YAML fragments | Agent drafts BDD scenarios from evidence |
| **Portability** | Runner-agnostic profile format | Robot Framework ecosystem |
| **When better** | Large profile corpus, automated generation, CI pipelines | Human review, BDD teams, test-suite handoff |

The two approaches are **complementary**:
- WISE Scraper profiles can be auto-generated into BDD suites via `generate_from_wise_yaml.py`
- BDD suites can be manually authored from exploration evidence
- Both share the same NER model (state/action/expand/extract/emit)

## vs Plain Robot Framework

| Dimension | Plain Robot Framework | WISE RPA BDD |
|---|---|---|
| **Keywords** | Site-specific custom keywords | Generic browser-extraction keywords |
| **Structure** | Free-form test cases | Artifact catalog / resources / rules / quality gates |
| **Data model** | Ad-hoc variables | Declared artifacts with schemas, emit/merge/write pipeline |
| **Chaining** | Manual test ordering | Parent iteration, artifact consumption, entry resolution |
| **Validation** | Robot dryrun only | BDD validator + Robot dryrun (two gates) |

## vs Playwright Test Scripts

| Dimension | Playwright Scripts | WISE RPA BDD |
|---|---|---|
| **Language** | JavaScript/TypeScript/Python | Robot Framework BDD |
| **Abstraction** | Imperative code | Declarative BDD steps |
| **Reusability** | Import modules | Generic keyword contract |
| **Data pipeline** | Custom code | Artifact declarations, emit, merge, quality gates |
| **Agent fit** | Agent writes code from scratch | Agent fills in template patterns with selectors |

## vs Scrapy / Crawlee

Both Scrapy and Crawlee are production crawling frameworks. WISE RPA BDD is not a crawler — it is a **spec format** for structured browser extraction that happens to be executable.

Use Scrapy/Crawlee when: high-volume production crawls, proxy rotation, queue management.
Use WISE RPA BDD when: agent-driven repeatable extraction, BDD team handoff, human review of extraction logic.

## When to use what

- **WISE Scraper**: automated profile generation, CI pipeline integration, profile corpus management
- **WISE RPA BDD**: manual exploration into suite authoring, BDD teams, human-readable extraction specs
- **Plain Robot Framework**: existing RF infrastructure, non-extraction browser automation
- **Playwright/Scrapy/Crawlee**: production-scale crawling with code-level control
