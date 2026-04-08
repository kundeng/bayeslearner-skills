*** Comments ***
Requirement    Scrape the Web API reference index from
...            https://developer.mozilla.org/en-US/docs/Web/API — extract all API
...            names and their one-line descriptions. BFS expand over the API listing links.
Expected       name,url,description
Min Records    50

# -- Evidence (MDN Web API index -- WebFetch inspection, 2026-04-07) ---------------------------
#
# Fetched: https://developer.mozilla.org/en-US/docs/Web/API  (WebFetch, 2026-04-07)
#
# Auth:         none -- public documentation, no login required.
# URL pattern:  /en-US/docs/Web/API/<ApiName>
#
# Page layout (two main sections):
#   H2 "Specifications"  — grouped A-Z under h3 letter headings
#     Each entry: <li><a href="/en-US/docs/Web/API/...">API Name</a> [status badge]</li>
#     ~90 specification-level entries (Attribution Reporting API, Audio Output Devices API, ...)
#
#   H2 "Interfaces"      — grouped A-Z under h3 letter headings
#     Each entry: <li><a href="/en-US/docs/Web/API/...">InterfaceName</a></li>
#     ~900+ interface entries (AbortController, Blob, Document, ...)
#
# Key observation: The index page does NOT contain one-line descriptions inline.
#   Descriptions are on individual API pages in the first <p> after <h1> inside <article>.
#
# Strategy (two-phase):
#   Phase 1 (Discovery): BFS expand over Specifications section links to collect API URLs.
#     Selector: section heading "Specifications" followed by alphabetical <ul><li><a> entries.
#     The "Specifications" section lists high-level APIs (not individual interfaces).
#     Container: the section after h2#specifications, links in nested ul > li > a
#     Refined selector: div.section-content ul li a  (within the Specifications area)
#     Using the broader scope: article.main-page-content ul li a  covers all index links.
#     We target the Specifications section specifically via the first index block.
#
#   Phase 2 (Detail): Open each discovered URL, extract the API name from h1 and the
#     one-line description from the first paragraph of the article.
#
# Quality gates:
#   min_records = 50 (conservative; expect ~90 specification entries)
#   name = 95% fill, description = 80% fill (some pages may lack summary paragraph)
#
# ------------------------------------------------------------------------------------------

*** Settings ***
Documentation     Scrape MDN Web API reference index: discover all API specification
...               entries via BFS expansion, then visit each page to extract the API
...               name and one-line description. Two-phase: discovery + detail.
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
    ...    description=MDN Web API specifications with names and one-line descriptions

Discover API Listing Links
    [Documentation]    BFS expand over API listing links in the Specifications section.
    ...                Each li > a under the alphabetical headings yields one API URL.
    [Setup]    Given I start resource "discover" at "${ENTRY_URL}"
    And I set resource globals
    ...    timeout_ms=20000
    ...    retries=2
    ...    page_load_delay_ms=2000
    Given url contains "/docs/Web/API"
    And selector "div.section-content li a" exists
    When I expand over elements "div.section-content li a" with order "bfs"
    Then I extract fields
    ...    field=page_url    extractor=link    locator="."
    And I emit to artifact "${ARTIFACT_API_URLS}"

Extract API Details
    [Documentation]    Open each discovered API page and extract the name (h1) and
    ...                one-line description (first paragraph inside the article).
    [Setup]    Given I start resource "detail" at "{page_url}"
    And I set resource globals
    ...    timeout_ms=20000
    ...    retries=2
    ...    page_load_delay_ms=1500
    And I begin rule "page"
    And selector "article h1" exists
    Then I extract fields
    ...    field=name           extractor=text    locator="article h1"
    ...    field=url            extractor=link    locator="."
    ...    field=description    extractor=text    locator="article div.section-content > p:first-child"
    And I emit to artifact "${ARTIFACT_APIS}"

Quality Gates
    [Documentation]    Minimum thresholds for the MDN Web API scrape.
    And I set quality gate min records to 50
    And I set filled percentage for "name" to 95
    And I set filled percentage for "description" to 80
