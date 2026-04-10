*** Comments ***
Requirement    Full copy of Splunk ITSI Entity Integrations and Event Analytics docs.
...            Discover all pages from TOC, extract body, convert to markdown via
...            markdownify, then AI-clean navigation leftovers. Single markdown output.

*** Settings ***
Documentation     Full Splunk ITSI docs scrape: Entity Integrations + Event Analytics.
...               Two-phase discovery→detail: phase 1 collects TOC page URLs from
...               [data-testid="toc-link"], phase 2 opens each page, extracts title
...               and body from main article.
...               Body is converted HTML→markdown via markdownify (fast, built-in),
...               then AI (aichat) does light cleanup — removing nav chrome and
...               fixing formatting artifacts.
...               Evidence: [data-testid="toc-link"] yields ~50 links per section TOC;
...               main article contains page content; h1 for title.
Library           Browser
Library           WiseRpaBDD
Suite Setup       Given I start deployment "${DEPLOYMENT}"
Suite Teardown    Then I finalize deployment

*** Variables ***
${DEPLOYMENT}               splunk-itsi-complete
${ENTITY_ENTRY}             https://help.splunk.com/en/splunk-it-service-intelligence/splunk-it-service-intelligence/discover-and-integrate-it-components
${EVENTS_ENTRY}             https://help.splunk.com/en/splunk-it-service-intelligence/splunk-it-service-intelligence/detect-and-act-on-notable-events
${ARTIFACT_URLS}            page_urls
${ARTIFACT_DOCS}            itsi_docs
${AI_PROMPT}                Clean up this markdown converted from Splunk ITSI documentation. Remove any leftover navigation text, breadcrumbs, sidebar links, "Was this page helpful?" sections, and footer boilerplate. Preserve all technical content: headings, paragraphs, lists, tables, code blocks (SPL queries, CLI commands, config stanzas), notes, and warnings. Do not summarize — keep the full content. Output clean markdown only.

*** Test Cases ***
Artifact Catalog
    [Documentation]    Register URL collector and final markdown output artifacts.
    Given I register artifact "${ARTIFACT_URLS}"
    ...    field=page_url      type=url       required=true
    ...    field=section        type=string    required=true
    And I set artifact options for "${ARTIFACT_URLS}"
    ...    output=false
    ...    dedupe=page_url
    ...    description=Discovered TOC page URLs from Entity Integrations + Event Analytics

    Given I register artifact "${ARTIFACT_DOCS}"
    ...    field=title          type=string    required=true
    ...    field=url            type=url       required=true
    ...    field=section        type=string    required=false
    ...    field=body           type=string    required=true
    And I set artifact options for "${ARTIFACT_DOCS}"
    ...    output=true
    ...    format=markdown
    ...    structure=flat
    ...    description=Full Splunk ITSI docs: Entity Integrations + Event Analytics (cleaned markdown)

Hook Setup
    [Documentation]    Convert HTML body to markdown before AI cleanup runs.
    And I register hook "html_to_md" at "post_extract"
    ...    to_markdown=body

Discover Entity Integration Pages
    [Documentation]    Produces: page_urls (Entity Integrations TOC links)
    [Setup]    Given I start resource "discover_entity" at "${ENTITY_ENTRY}"
    And I set resource globals
    ...    timeout_ms=20000
    ...    retries=2
    ...    page_load_delay_ms=2000
    I define rule "root"
        Given url contains "discover-and-integrate"
        And selector "[data-testid='toc-link']" exists
    I define rule "toc"
        And I declare parents "root"
        When I expand over elements "[data-testid='toc-link']" with order "bfs"
        ...    limit=50
        Then I extract fields
        ...    field=page_url    extractor=link    locator="."
        ...    field=section     extractor=value   locator="."    value=Entity Integrations
        And I emit to artifact "${ARTIFACT_URLS}"

Discover Event Analytics Pages
    [Documentation]    Produces: page_urls (Event Analytics TOC links)
    [Setup]    Given I start resource "discover_events" at "${EVENTS_ENTRY}"
    And I set resource globals
    ...    timeout_ms=20000
    ...    retries=2
    ...    page_load_delay_ms=2000
    I define rule "root"
        Given url contains "detect-and-act"
        And selector "[data-testid='toc-link']" exists
    I define rule "toc"
        And I declare parents "root"
        When I expand over elements "[data-testid='toc-link']" with order "bfs"
        ...    limit=50
        Then I extract fields
        ...    field=page_url    extractor=link    locator="."
        ...    field=section     extractor=value   locator="."    value=Event Analytics
        And I emit to artifact "${ARTIFACT_URLS}"

Extract Doc Pages
    [Documentation]    Produces: itsi_docs (title, url, section, body as cleaned markdown)
    [Setup]    Given I start resource "extract_pages" at "{page_url}"
    Given I consume artifact "${ARTIFACT_URLS}"
    And I set resource globals
    ...    timeout_ms=30000
    ...    retries=2
    ...    page_load_delay_ms=2000
    And I set AI adapter "aichat"
    I define rule "page"
        And selector "main article" exists
        Then I extract fields
        ...    field=title      extractor=text    locator="h1"
        ...    field=url        extractor=url     locator="."
        ...    field=body       extractor=html    locator="main article"
        Then I extract with AI "body"
        ...    input=body
        ...    mode=cleanup
        ...    output=markdown
        ...    max_size=120000
        ...    chunk_size=50000
        ...    prompt=${AI_PROMPT}
        And I emit to artifact "${ARTIFACT_DOCS}"

Quality Gates
    And I set quality gate min records to 15
    And I set filled percentage for "title" to 95
    And I set filled percentage for "body" to 90
