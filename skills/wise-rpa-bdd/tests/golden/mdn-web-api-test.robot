*** Comments ***
Requirement    Scrape Web API names and descriptions from the MDN Web API reference.

*** Settings ***
Documentation     Scrape MDN Web API reference index: discover API specification
...               entries via BFS expansion (limit 10), then visit each page to
...               extract the API name and one-line description. Two-phase:
...               discovery + detail.
Library           Browser
Library           WiseRpaBDD
Suite Setup       Given I start deployment "${DEPLOYMENT}"
Suite Teardown    Then I finalize deployment

*** Variables ***
${DEPLOYMENT}            mdn-web-api
${ENTRY_URL}             https://developer.mozilla.org/en-US/docs/Web/API
${ARTIFACT_API_URLS}     api_urls
${ARTIFACT_APIS}         apis

*** Test Cases ***
Artifact Catalog
    [Documentation]    Register artifacts: URL collector (internal) and final API records (output).

    # -- Discovery artifact (internal URL list, not written to disk) --
    Given I register artifact "${ARTIFACT_API_URLS}"
    ...    field=page_url    type=url    required=true
    And I set artifact options for "${ARTIFACT_API_URLS}"
    ...    output=false
    ...    dedupe=page_url
    ...    description=Discovered API specification page URLs from MDN index

    # -- Output artifact (API name + description) --
    Given I register artifact "${ARTIFACT_APIS}"
    ...    field=name           type=string    required=true
    ...    field=url            type=url       required=true
    ...    field=description    type=string    required=false
    And I set artifact options for "${ARTIFACT_APIS}"
    ...    output=true
    ...    structure=flat
    ...    consumes=api_urls
    ...    description=MDN Web API specifications with names and one-line descriptions

Discover API Listing Links
    [Documentation]    BFS expand over API listing links in the Specifications section.
    ...                section[aria-labelledby="specifications"] wraps the spec entries.
    ...                Limited to 10 links for detail-page visiting.
    [Setup]    Given I start resource "discover" at "${ENTRY_URL}"
    And I set resource globals
    ...    timeout_ms=20000
    ...    retries=2
    ...    page_load_delay_ms=2000
    I define rule "index"
        Given url contains "/docs/Web/API"
        And selector "section[aria-labelledby='specifications'] a" exists
        When I expand over elements "section[aria-labelledby='specifications'] a" with order "bfs"
        ...    limit=10
        Then I extract fields
        ...    field=page_url    extractor=link    locator="."
        And I emit to artifact "${ARTIFACT_API_URLS}"

Extract API Details
    [Documentation]    Open each discovered API page (up to 10) and extract the name
    ...                (h1) and one-line description (first paragraph after h1).
    [Setup]    Given I start resource "detail" at "{page_url}"
    And I set resource globals
    ...    timeout_ms=20000
    ...    retries=2
    ...    page_load_delay_ms=1500
    I define rule "page"
        And selector "h1" exists
        Then I extract fields
        ...    field=name           extractor=text    locator="h1"
        ...    field=description    extractor=text    locator="main .content-section > p"
        And I emit to artifact "${ARTIFACT_APIS}"

Quality Gates
    [Documentation]    Minimum thresholds for the MDN Web API scrape.
    And I set quality gate min records to 5
    And I set filled percentage for "name" to 95
    And I set filled percentage for "description" to 80
