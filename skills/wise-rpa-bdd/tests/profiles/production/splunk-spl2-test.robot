*** Settings ***
Documentation     Generated from tests/profiles/production/splunk-spl2-test.yaml
Library           WiseRpaBDD
Suite Setup       Given I start deployment "${DEPLOYMENT}"
Suite Teardown    Then I finalize deployment

*** Variables ***
${DEPLOYMENT}    splunk-spl2-docs
${ARTIFACT_SPL2_PAGES_NESTED}    spl2_pages_nested
${ARTIFACT_SPL2_PAGES_FLAT}    spl2_pages_flat
${ENTRY_DISCOVER_OVERVIEW}    https://help.splunk.com/en/splunk-cloud-platform/search/spl2-overview/what-is-spl2
${ENTRY_DISCOVER_MANUAL}    https://help.splunk.com/en/splunk-cloud-platform/search/spl2-search-manual/getting-started/searching-data-using-spl2
${ENTRY_DISCOVER_REFERENCE}    https://help.splunk.com/en/splunk-cloud-platform/search/spl2-search-reference/introduction/introduction

*** Test Cases ***
Artifact Catalog
    Given I register artifact "${ARTIFACT_SPL2_PAGES_NESTED}"
    ...    field=title    type=string    required=true
    ...    field=body    type=string    required=true
    And I set artifact options for "${ARTIFACT_SPL2_PAGES_NESTED}"
    ...    format=json
    ...    output=true
    ...    structure=nested
    ...    description=SPL2 documentation pages as nested tree records
    Given I register artifact "${ARTIFACT_SPL2_PAGES_FLAT}"
    ...    field=title    type=string    required=true
    ...    field=body    type=string    required=true
    And I set artifact options for "${ARTIFACT_SPL2_PAGES_FLAT}"
    ...    format=markdown
    ...    output=true
    ...    structure=flat
    ...    description=SPL2 documentation pages as flat denormalized records

Resource discover_overview
    [Setup]    Given I start resource "discover_overview" at "${ENTRY_DISCOVER_OVERVIEW}"
    And I set resource globals
    ...    timeout_ms=30000
    ...    retries=2
    And I begin rule "toc"
    And selector "div.toc a[href*='/spl2-overview/']" exists
    When I expand over elements "div.toc a[href*='/spl2-overview/']" with order "bfs"
    Then I extract fields
    ...    field=url    extractor=link    locator="div.toc a[href*='/spl2-overview/']"
    ...    field=title    extractor=text    locator="div.toc a[href*='/spl2-overview/']"

Resource discover_manual
    [Setup]    Given I start resource "discover_manual" at "${ENTRY_DISCOVER_MANUAL}"
    And I set resource globals
    ...    timeout_ms=30000
    ...    retries=2
    And I begin rule "toc"
    And selector "div.toc a[href*='/spl2-search-manual/']" exists
    When I expand over elements "div.toc a[href*='/spl2-search-manual/']" with order "bfs"
    Then I extract fields
    ...    field=url    extractor=link    locator="div.toc a[href*='/spl2-search-manual/']"
    ...    field=title    extractor=text    locator="div.toc a[href*='/spl2-search-manual/']"

Resource discover_reference
    [Setup]    Given I start resource "discover_reference" at "${ENTRY_DISCOVER_REFERENCE}"
    And I set resource globals
    ...    timeout_ms=30000
    ...    retries=2
    And I begin rule "toc"
    And selector "div.toc a[href*='/spl2-search-reference/']" exists
    When I expand over elements "div.toc a[href*='/spl2-search-reference/']" with order "bfs"
    Then I extract fields
    ...    field=url    extractor=link    locator="div.toc a[href*='/spl2-search-reference/']"
    ...    field=title    extractor=text    locator="div.toc a[href*='/spl2-search-reference/']"

Resource extract_overview_pages
    [Documentation]    Produces: ['spl2_pages_nested', 'spl2_pages_flat']
    [Setup]    Given I start resource "extract_overview_pages"
    Given I resolve entry from "discover_overview.toc.url"
    And I set resource globals
    ...    timeout_ms=30000
    ...    page_load_delay_ms=1500
    And I begin rule "page"
    And selector "h1.title" exists
    Then I extract fields
    ...    field=title    extractor=text    locator="h1.title"
    ...    field=body    extractor=html    locator=".body"
    And I emit to artifact "${ARTIFACT_SPL2_PAGES_NESTED}"
    And I emit to artifact "${ARTIFACT_SPL2_PAGES_FLAT}"

Resource extract_manual_pages
    [Documentation]    Produces: ['spl2_pages_nested', 'spl2_pages_flat']
    [Setup]    Given I start resource "extract_manual_pages"
    Given I resolve entry from "discover_manual.toc.url"
    And I set resource globals
    ...    timeout_ms=30000
    ...    page_load_delay_ms=1500
    And I begin rule "page"
    And selector "h1.title" exists
    Then I extract fields
    ...    field=title    extractor=text    locator="h1.title"
    ...    field=body    extractor=html    locator=".body"
    And I emit to artifact "${ARTIFACT_SPL2_PAGES_NESTED}"
    And I emit to artifact "${ARTIFACT_SPL2_PAGES_FLAT}"

Resource extract_reference_pages
    [Documentation]    Produces: ['spl2_pages_nested', 'spl2_pages_flat']
    [Setup]    Given I start resource "extract_reference_pages"
    Given I resolve entry from "discover_reference.toc.url"
    And I set resource globals
    ...    timeout_ms=30000
    ...    page_load_delay_ms=1500
    And I begin rule "page"
    And selector "h1.title" exists
    Then I extract fields
    ...    field=title    extractor=text    locator="h1.title"
    ...    field=body    extractor=html    locator=".body"
    And I emit to artifact "${ARTIFACT_SPL2_PAGES_NESTED}"
    And I emit to artifact "${ARTIFACT_SPL2_PAGES_FLAT}"

Quality Gates
    And I set quality gate min records to 200
