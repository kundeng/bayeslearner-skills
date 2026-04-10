*** Comments ***
Requirement    Scrape Splunk ITSI documentation from help.splunk.com — extract page
...            titles and body content from the Entity Integrations and Event Analytics
...            manuals. Clean up body HTML with AI.

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
${AI_CLEANUP_PROMPT}            Extract all code blocks (SPL queries, CLI commands, config stanzas) and key definitions or concepts from this Splunk ITSI documentation page. Format as markdown with ## Code Blocks and ## Key Definitions sections.

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
    I define rule "toc"
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
    I define rule "toc"
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
    I define rule "page"
        And selector "main article" exists
        Then I extract fields
        ...    field=title    extractor=text    locator="h1"
        ...    field=url      extractor=link    locator="."
        ...    field=body     extractor=html    locator="main article"
        Then I extract with AI "cleaned"
        ...    input=body
        ...    output=markdown
        ...    max_size=30000
        ...    prompt=${AI_CLEANUP_PROMPT}
        And I emit to artifact "${ARTIFACT_PAGES_NESTED}"
        And I emit to artifact "${ARTIFACT_PAGES_FLAT}"

Extract Event Analytics Pages
    [Documentation]    Open each Event Analytics page, extract title, body, and AI-cleaned content.
    [Setup]    Given I start resource "extract_events" at "{page_url}"
    Given I consume artifact "${ARTIFACT_EVENTS_URLS}"
    And I set resource globals
    ...    timeout_ms=20000
    ...    retries=2
    I define rule "page"
        And selector "main article" exists
        Then I extract fields
        ...    field=title    extractor=text    locator="h1"
        ...    field=url      extractor=link    locator="."
        ...    field=body     extractor=html    locator="main article"
        Then I extract with AI "cleaned"
        ...    input=body
        ...    output=markdown
        ...    max_size=30000
        ...    prompt=${AI_CLEANUP_PROMPT}
        And I emit to artifact "${ARTIFACT_PAGES_NESTED}"
        And I emit to artifact "${ARTIFACT_PAGES_FLAT}"

Quality Gates
    [Documentation]    Minimum record and fill-rate thresholds.
    And I set quality gate min records to 10
    And I set filled percentage for "title" to 95
    And I set filled percentage for "body" to 90
