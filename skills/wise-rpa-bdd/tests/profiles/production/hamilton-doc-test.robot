*** Settings ***
Documentation     Generated from tests/profiles/production/hamilton-doc-test.yaml
Library           WiseRpaBDD
Suite Setup       Given I start deployment "${DEPLOYMENT}"
Suite Teardown    Then I finalize deployment

*** Variables ***
${DEPLOYMENT}    hamilton-dagworks-docs
${ARTIFACT_HAMILTON_PAGE_URLS}    hamilton_page_urls
${ARTIFACT_HAMILTON_PAGES_NESTED}    hamilton_pages_nested
${ARTIFACT_HAMILTON_PAGES_FLAT}    hamilton_pages_flat
${ENTRY_DISCOVER_PAGES}    https://hamilton.dagworks.io/en/latest/
${ENTRY_EXTRACT_PAGES}    https://hamilton.dagworks.io/en/latest/{url}

*** Test Cases ***
Artifact Catalog
    Given I register artifact "${ARTIFACT_HAMILTON_PAGE_URLS}"
    ...    field=url    type=string    required=true
    ...    field=title    type=string    required=true
    And I set artifact options for "${ARTIFACT_HAMILTON_PAGE_URLS}"
    ...    dedupe=url
    ...    description=Discovered Hamilton documentation page URLs from sidebar navigation
    Given I register artifact "${ARTIFACT_HAMILTON_PAGES_NESTED}"
    ...    field=title    type=string    required=true
    ...    field=body    type=string    required=true
    And I set artifact options for "${ARTIFACT_HAMILTON_PAGES_NESTED}"
    ...    format=json
    ...    output=true
    ...    structure=nested
    ...    consumes=hamilton_page_urls
    ...    description=Hamilton documentation pages as nested tree records
    Given I register artifact "${ARTIFACT_HAMILTON_PAGES_FLAT}"
    ...    field=title    type=string    required=true
    ...    field=body    type=string    required=true
    And I set artifact options for "${ARTIFACT_HAMILTON_PAGES_FLAT}"
    ...    format=markdown
    ...    output=true
    ...    structure=flat
    ...    consumes=hamilton_page_urls
    ...    description=Hamilton documentation pages as flat denormalized markdown

Resource discover_pages
    [Documentation]    Produces: hamilton_page_urls
    [Setup]    Given I start resource "discover_pages" at "${ENTRY_DISCOVER_PAGES}"
    And I set resource globals
    ...    timeout_ms=30000
    ...    retries=2
    And I begin rule "toc"
    And selector "div.sidebar-tree a.reference.internal" exists
    When I expand over elements "div.sidebar-tree li:has(> a.reference.internal[href$='/'])" with order "bfs"
    Then I extract fields
    ...    field=url    extractor=link    locator="a.reference.internal"
    ...    field=title    extractor=text    locator="a.reference.internal"
    And I emit to artifact "${ARTIFACT_HAMILTON_PAGE_URLS}"

Resource extract_pages
    [Documentation]    Produces: ['hamilton_pages_nested', 'hamilton_pages_flat']
    [Setup]    Given I start resource "extract_pages" at "${ENTRY_EXTRACT_PAGES}"
    And I set resource globals
    ...    timeout_ms=30000
    ...    page_load_delay_ms=1500
    ...    retries=2
    And I begin rule "page"
    And selector "article#furo-main-content h1" exists
    Then I extract fields
    ...    field=title    extractor=text    locator="article#furo-main-content h1"
    ...    field=body    extractor=html    locator="article[role='main']"
    And I emit to artifact "${ARTIFACT_HAMILTON_PAGES_NESTED}"
    And I emit to artifact "${ARTIFACT_HAMILTON_PAGES_FLAT}"

Quality Gates
    And I set quality gate min records to 100
