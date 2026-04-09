*** Comments ***
Requirement    Scrape the index of all test pages from the-internet.herokuapp.com.
...            Collect each page name and its URL.

*** Settings ***
Documentation     Scrape all available test page names and URLs from
...               the-internet.herokuapp.com index page — a single-page listing of 44
...               example pages. Evidence: #content ul li elements each containing an
...               anchor with page name (text) and page URL (href). No pagination needed.
Library           Browser
Library           WiseRpaBDD
Suite Setup       Given I start deployment "${DEPLOYMENT}"
Suite Teardown    Then I finalize deployment

*** Variables ***
${DEPLOYMENT}            herokuapp-index
${ENTRY_URL}             https://the-internet.herokuapp.com/
${ARTIFACT_PAGES}        pages

*** Test Cases ***
Artifact Catalog
    Given I register artifact "${ARTIFACT_PAGES}"
    ...    field=page_name    type=string    required=true
    ...    field=page_url     type=url       required=true
    And I set artifact options for "${ARTIFACT_PAGES}"
    ...    output=true
    ...    structure=flat
    ...    description=All available test pages with name and URL from the-internet index

Resource page_index
    [Documentation]    Produces: pages
    [Setup]    Given I start resource "page_index" at "${ENTRY_URL}"
    And I set resource globals
    ...    timeout_ms=15000
    ...    retries=2
    ...    page_load_delay_ms=500

    # Rule: root — state gate confirming correct page before extraction
    # Evidence: url is /; h1.heading and ul with li>a elements present
    And I begin rule "root"
    Given url contains "/"
    And selector "#content ul li a" exists

    # Rule: items — expand over each li and extract page name + URL
    # Evidence: 44 #content ul li elements on a single page.
    # Extractors:
    #   page_name — a; link text (page display name)
    #   page_url  — a; href resolved to absolute URL
    And I begin rule "items"
    And I declare parents "root"
    When I expand over elements "#content ul li"
    Then I extract fields
    ...    field=page_name    extractor=text    locator="a"
    ...    field=page_url     extractor=link    locator="a"
    And I emit to artifact "${ARTIFACT_PAGES}"

Quality Gates
    # 44 pages total; require at least 40 to allow for minor edge cases
    # page_name and page_url should always be populated
    And I set quality gate min records to 40
    And I set filled percentage for "page_name" to 100
    And I set filled percentage for "page_url" to 100
