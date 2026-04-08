*** Comments ***
Requirement    Scrape Splunk ITSI Entity Integrations and Event Analytics documentation from help.splunk.com. Two sections only. Discover page URLs from left-nav, extract title and body from each page. Output as markdown.
Expected       title,body
Min Records    20

*** Settings ***
Documentation     Generated from tests/profiles/production/splunk-itsi-focused-test.yaml
Library           Browser
Library           WiseRpaBDD
Suite Setup       Given I start deployment "${DEPLOYMENT}"
Suite Teardown    Then I finalize deployment

*** Variables ***
${DEPLOYMENT}    splunk-itsi-entity-events
${ARTIFACT_ITSI_PAGES_NESTED}    itsi_pages_nested
${ARTIFACT_ITSI_PAGES_FLAT}    itsi_pages_flat
${ENTRY_DISCOVER_ENTITY}    https://help.splunk.com/en/splunk-it-service-intelligence/splunk-it-service-intelligence/discover-and-integrate-it-components
${ENTRY_DISCOVER_EVENTS}    https://help.splunk.com/en/splunk-it-service-intelligence/splunk-it-service-intelligence/detect-and-act-on-notable-events

*** Test Cases ***
Artifact Catalog
    Given I register artifact "${ARTIFACT_ITSI_PAGES_NESTED}"
    ...    field=title    type=string    required=true
    ...    field=body    type=string    required=true
    And I set artifact options for "${ARTIFACT_ITSI_PAGES_NESTED}"
    ...    format=json
    ...    output=true
    ...    structure=nested
    ...    dedupe=title
    ...    description=ITSI Entity Integrations + Event Analytics pages (nested)
    Given I register artifact "${ARTIFACT_ITSI_PAGES_FLAT}"
    ...    field=title    type=string    required=true
    ...    field=body    type=string    required=true
    And I set artifact options for "${ARTIFACT_ITSI_PAGES_FLAT}"
    ...    format=markdown
    ...    output=true
    ...    structure=flat
    ...    dedupe=title
    ...    description=ITSI Entity Integrations + Event Analytics pages (markdown)

Resource discover_entity
    [Setup]    Given I start resource "discover_entity" at "${ENTRY_DISCOVER_ENTITY}"
    And I set resource globals
    ...    timeout_ms=30000
    ...    retries=2
    And I begin rule "toc"
    And selector "nav a[href*='/discover-and-integrate-it-components/']" exists
    When I expand over elements "nav a[href*='/discover-and-integrate-it-components/4.21/']:not([href*='%'])" with order "bfs"
    Then I extract fields
    ...    field=url    extractor=link    locator="nav a[href*='/discover-and-integrate-it-components/4.21/']"
    ...    field=title    extractor=text    locator="nav a[href*='/discover-and-integrate-it-components/4.21/']"

Resource discover_events
    [Setup]    Given I start resource "discover_events" at "${ENTRY_DISCOVER_EVENTS}"
    And I set resource globals
    ...    timeout_ms=30000
    ...    retries=2
    And I begin rule "toc"
    And selector "nav a[href*='/detect-and-act-on-notable-events/']" exists
    When I expand over elements "nav a[href*='/detect-and-act-on-notable-events/4.21/']:not([href*='%'])" with order "bfs"
    Then I extract fields
    ...    field=url    extractor=link    locator="nav a[href*='/detect-and-act-on-notable-events/4.21/']"
    ...    field=title    extractor=text    locator="nav a[href*='/detect-and-act-on-notable-events/4.21/']"

Resource extract_entity_pages
    [Documentation]    Produces: ['itsi_pages_nested', 'itsi_pages_flat']
    [Setup]    Given I start resource "extract_entity_pages"
    Given I resolve entry from "discover_entity.toc.url"
    And I set resource globals
    ...    timeout_ms=30000
    ...    page_load_delay_ms=2000
    And I begin rule "page"
    And selector "h1" exists
    Then I extract fields
    ...    field=title    extractor=text    locator="h1"
    ...    field=body    extractor=html    locator="article"
    And I emit to artifact "${ARTIFACT_ITSI_PAGES_NESTED}"
    And I emit to artifact "${ARTIFACT_ITSI_PAGES_FLAT}"

Resource extract_events_pages
    [Documentation]    Produces: ['itsi_pages_nested', 'itsi_pages_flat']
    [Setup]    Given I start resource "extract_events_pages"
    Given I resolve entry from "discover_events.toc.url"
    And I set resource globals
    ...    timeout_ms=30000
    ...    page_load_delay_ms=2000
    And I begin rule "page"
    And selector "h1" exists
    Then I extract fields
    ...    field=title    extractor=text    locator="h1"
    ...    field=body    extractor=html    locator="article"
    And I emit to artifact "${ARTIFACT_ITSI_PAGES_NESTED}"
    And I emit to artifact "${ARTIFACT_ITSI_PAGES_FLAT}"

Quality Gates
    And I set quality gate min records to 20
