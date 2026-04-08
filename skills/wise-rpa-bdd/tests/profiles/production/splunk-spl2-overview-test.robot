*** Settings ***
Documentation     Generated from tests/profiles/production/splunk-spl2-overview-test.yaml
Library           WiseRpaBDD
Suite Setup       Given I start deployment "${DEPLOYMENT}"
Suite Teardown    Then I finalize deployment

*** Variables ***
${DEPLOYMENT}    splunk-spl2-overview
${ARTIFACT_PAGE_URLS}    page_urls
${ARTIFACT_PAGE_CONTENT}    page_content
${ENTRY_DISCOVER}    https://help.splunk.com/en/splunk-cloud-platform/search/spl2-overview/what-is-spl2
${ENTRY_EXTRACT_PAGES}    https://help.splunk.com{url}

*** Test Cases ***
Artifact Catalog
    Given I register artifact "${ARTIFACT_PAGE_URLS}"
    ...    field=url    type=string    required=true
    ...    field=title    type=string    required=true
    And I set artifact options for "${ARTIFACT_PAGE_URLS}"
    ...    description=TOC links from the left nav for SPL2 Overview section
    Given I register artifact "${ARTIFACT_PAGE_CONTENT}"
    ...    field=title    type=string    required=true
    ...    field=body    type=string    required=true
    And I set artifact options for "${ARTIFACT_PAGE_CONTENT}"
    ...    format=markdown
    ...    output=true
    ...    consumes=page_urls
    ...    description=Title + body HTML per page

Resource discover
    [Documentation]    Produces: page_urls
    [Setup]    Given I start resource "discover" at "${ENTRY_DISCOVER}"
    And I set resource globals
    ...    timeout_ms=30000
    ...    retries=2
    And I begin rule "toc"
    And selector ".toc-item-wrapper a[href*='/spl2-overview/']" exists
    When I expand over elements ".toc-item-wrapper:has(> a[href*='/spl2-overview/'])" with order "bfs"
    Then I extract fields
    ...    field=url    extractor=link    locator="a[href*='/spl2-overview/']"
    ...    field=title    extractor=text    locator="a[href*='/spl2-overview/']"
    And I emit to artifact "p"
    And I emit to artifact "a"
    And I emit to artifact "g"
    And I emit to artifact "e"
    And I emit to artifact "_"
    And I emit to artifact "u"
    And I emit to artifact "r"
    And I emit to artifact "l"
    And I emit to artifact "s"

Resource extract_pages
    [Documentation]    Produces: page_content
    [Setup]    Given I start resource "extract_pages" at "${ENTRY_EXTRACT_PAGES}"
    And I set resource globals
    ...    timeout_ms=30000
    ...    page_load_delay_ms=1500
    And I begin rule "page"
    And selector "h1.title" exists
    Then I extract fields
    ...    field=title    extractor=text    locator="h1.title"
    ...    field=body    extractor=html    locator=".body"
    And I emit to artifact "p"
    And I emit to artifact "a"
    And I emit to artifact "g"
    And I emit to artifact "e"
    And I emit to artifact "_"
    And I emit to artifact "c"
    And I emit to artifact "o"
    And I emit to artifact "n"
    And I emit to artifact "t"
    And I emit to artifact "e"
    And I emit to artifact "n"
    And I emit to artifact "t"

Quality Gates
    And I set quality gate min records to 8
