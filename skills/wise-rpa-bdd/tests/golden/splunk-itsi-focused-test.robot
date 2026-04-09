*** Comments ***
Requirement    Scrape Splunk ITSI Entity Integrations and Event Analytics documentation
...            from help.splunk.com. Discover page URLs from the left-nav TOC, extract
...            title and body from each page. Use AI to extract code blocks and key
...            definitions from the HTML body. Output as markdown.
Expected       title,body,cleaned
Min Records    20

# -- Evidence (live DOM -- agent-browser session) ------------------------------------------------
#
# Fetched: https://help.splunk.com/en/splunk-it-service-intelligence/splunk-it-service-intelligence/
#          discover-and-integrate-it-components  (agent-browser, 2026-04-07)
# Fetched: https://help.splunk.com/en/splunk-it-service-intelligence/splunk-it-service-intelligence/
#          detect-and-act-on-notable-events      (agent-browser, 2026-04-07)
# Method:  agent-browser snapshot -i -c  +  eval inspection.
#
# Auth:         none -- public docs, no login required.
# URL pattern:  /en/splunk-it-service-intelligence/splunk-it-service-intelligence/<manual>/<version>/<section>/<page>
# Version:      4.21 (latest, selected by default).
#
# Left-nav TOC structure:
#   Container: div.toc  id="navigation-panel"  role="navigation"
#   Links:     .toc-item a[data-testid="toc-link"]  (72 links per manual)
#   Each link href is an absolute path, e.g.
#     /en/splunk-it-service-intelligence/.../4.21/get-started/what-is-an-entity-integration
#   Section parents have class "has-children expanded"; leaf pages are plain <a> tags.
#
# Content area:
#   Article:  main article              (single element, wraps entire page content; no role attribute)
#   Title:    h1                        (plain h1, no classes; verified 2026-04-09)
#
# Two manuals targeted:
#   1. Entity Integrations  -- "discover-and-integrate-it-components"  (~60 pages)
#   2. Event Analytics       -- "detect-and-act-on-notable-events"     (~60 pages)
#
# Extraction strategy:
#   Phase 1 (Discovery): Two resources, one per manual entry URL.
#     BFS expand over .toc-item a[data-testid="toc-link"] to collect page URLs.
#   Phase 2 (Detail):    Two resources consuming discovered URLs.
#     Open each URL, extract h1 title + article body HTML.
#   Phase 3 (AI):        Extract code blocks and key definitions from body HTML.
#   Output:              Nested JSON artifact + flat markdown artifact.
#
# Quality gates:
#   min_records = 20 (conservative; expect >100 total across both manuals)
#   title = 95% fill, body = 90% fill
#
# --------------------------------------------------------------------------------------------

*** Settings ***
Documentation     Scrape Splunk ITSI Entity Integrations and Event Analytics docs.
...               Discover page URLs from left-nav TOC, extract title and body,
...               then use AI to extract code blocks and key definitions.
...               Output as nested JSON and flat markdown.
Library           Browser
Library           WiseRpaBDD
Suite Setup       Given I start deployment "${DEPLOYMENT}"
Suite Teardown    Then I finalize deployment

*** Variables ***
${DEPLOYMENT}                   splunk-itsi-focused
${ENTITY_ENTRY}                 https://help.splunk.com/en/splunk-it-service-intelligence/splunk-it-service-intelligence/discover-and-integrate-it-components
${EVENTS_ENTRY}                 https://help.splunk.com/en/splunk-it-service-intelligence/splunk-it-service-intelligence/detect-and-act-on-notable-events
${ARTIFACT_ENTITY_URLS}         entity_urls
${ARTIFACT_EVENTS_URLS}         events_urls
${ARTIFACT_PAGES_NESTED}        pages_nested
${ARTIFACT_PAGES_FLAT}          pages_flat

*** Test Cases ***
Artifact Catalog
    [Documentation]    Register all artifacts: URL lists, nested JSON, flat markdown.
    # -- Discovery artifacts (URL collectors) --
    Given I register artifact "${ARTIFACT_ENTITY_URLS}"
    ...    field=page_url    type=url    required=true
    And I set artifact options for "${ARTIFACT_ENTITY_URLS}"
    ...    output=false
    ...    dedupe=page_url
    ...    description=Entity Integrations TOC page URLs

    Given I register artifact "${ARTIFACT_EVENTS_URLS}"
    ...    field=page_url    type=url    required=true
    And I set artifact options for "${ARTIFACT_EVENTS_URLS}"
    ...    output=false
    ...    dedupe=page_url
    ...    description=Event Analytics TOC page URLs

    # -- Nested output artifact (JSON) --
    Given I register artifact "${ARTIFACT_PAGES_NESTED}"
    ...    field=title      type=string    required=true
    ...    field=url        type=url       required=true
    ...    field=body       type=html      required=true
    ...    field=cleaned    type=string    required=false
    And I set artifact options for "${ARTIFACT_PAGES_NESTED}"
    ...    output=true
    ...    structure=nested
    ...    description=ITSI docs with AI-extracted code blocks and definitions (nested)

    # -- Flat output artifact (markdown) --
    Given I register artifact "${ARTIFACT_PAGES_FLAT}"
    ...    field=title      type=string    required=true
    ...    field=url        type=url       required=true
    ...    field=body       type=html      required=true
    ...    field=cleaned    type=string    required=false
    And I set artifact options for "${ARTIFACT_PAGES_FLAT}"
    ...    output=true
    ...    structure=flat
    ...    description=ITSI docs with AI-extracted code blocks and definitions (flat markdown)

Discover Entity Integration Pages
    [Documentation]    BFS expand left-nav TOC to collect Entity Integrations page URLs.
    [Setup]    Given I start resource "discover_entity" at "${ENTITY_ENTRY}"
    And I set resource globals
    ...    timeout_ms=15000
    ...    retries=2
    ...    page_load_delay_ms=2000
    And I begin rule "toc"
    Given url contains "discover-and-integrate-it-components"
    And selector ".toc-item a" exists
    When I expand over elements ".toc-item a" with order "bfs"
    ...    limit=10
    Then I extract fields
    ...    field=page_url    extractor=link    locator="."
    And I emit to artifact "${ARTIFACT_ENTITY_URLS}"

Discover Event Analytics Pages
    [Documentation]    BFS expand left-nav TOC to collect Event Analytics page URLs.
    [Setup]    Given I start resource "discover_events" at "${EVENTS_ENTRY}"
    And I set resource globals
    ...    timeout_ms=15000
    ...    retries=2
    ...    page_load_delay_ms=2000
    And I begin rule "toc"
    Given url contains "detect-and-act-on-notable-events"
    And selector ".toc-item a" exists
    When I expand over elements ".toc-item a" with order "bfs"
    ...    limit=10
    Then I extract fields
    ...    field=page_url    extractor=link    locator="."
    And I emit to artifact "${ARTIFACT_EVENTS_URLS}"

Extract Entity Integration Pages
    [Documentation]    Open each Entity Integration page, extract title, body, and AI-cleaned content.
    [Setup]    Given I start resource "extract_entity" at "{page_url}"
    Given I consume artifact "${ARTIFACT_ENTITY_URLS}"
    And I set resource globals
    ...    timeout_ms=20000
    ...    retries=2
    ...    page_load_delay_ms=2000
    And I begin rule "page"
    And selector "main article" exists
    Then I extract fields
    ...    field=title    extractor=text    locator="h1"
    ...    field=url      extractor=link    locator="."
    ...    field=body     extractor=html    locator="main article"
    Then I extract with AI "cleaned"
    ...    input=body
    ...    prompt=Extract all code blocks (SPL queries, CLI commands, config stanzas) and key definitions or concepts from this Splunk ITSI documentation page. Format the output as clean markdown with headings for Code Blocks and Key Definitions sections.
    And I emit to artifact "${ARTIFACT_PAGES_NESTED}"
    And I emit to artifact "${ARTIFACT_PAGES_FLAT}"

Extract Event Analytics Pages
    [Documentation]    Open each Event Analytics page, extract title, body, and AI-cleaned content.
    [Setup]    Given I start resource "extract_events" at "{page_url}"
    Given I consume artifact "${ARTIFACT_EVENTS_URLS}"
    And I set resource globals
    ...    timeout_ms=20000
    ...    retries=2
    ...    page_load_delay_ms=2000
    And I begin rule "page"
    And selector "main article" exists
    Then I extract fields
    ...    field=title    extractor=text    locator="h1"
    ...    field=url      extractor=link    locator="."
    ...    field=body     extractor=html    locator="main article"
    Then I extract with AI "cleaned"
    ...    input=body
    ...    prompt=Extract all code blocks (SPL queries, CLI commands, config stanzas) and key definitions or concepts from this Splunk ITSI documentation page. Format the output as clean markdown with headings for Code Blocks and Key Definitions sections.
    And I emit to artifact "${ARTIFACT_PAGES_NESTED}"
    And I emit to artifact "${ARTIFACT_PAGES_FLAT}"

Quality Gates
    [Documentation]    Minimum record and fill-rate thresholds.
    And I set quality gate min records to 10
    And I set filled percentage for "title" to 95
    And I set filled percentage for "body" to 90
