*** Comments ***
Requirement    Scrape the Web API reference index from
...            https://developer.mozilla.org/en-US/docs/Web/API — discover API page
...            URLs from the index, then open up to 10 detail pages and extract the
...            API name and one-line description.
Expected       name,url,description
Min Records    5

# -- Evidence (MDN Web API index -- agent-browser + WebFetch, 2026-04-07) ----------------------
#
# Explored: https://developer.mozilla.org/en-US/docs/Web/API  (agent-browser, 2026-04-07)
# Detail:   https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API  (WebFetch, 2026-04-07)
#
# Auth:         none -- public documentation, no login required.
# URL pattern:  /en-US/docs/Web/API/<ApiName>
#
# Page layout (redesigned — 2026):
#   The index page uses <section aria-labelledby="specifications"> and
#   <section aria-labelledby="interfaces"> as top-level containers.
#
#   Specifications section:
#     <section aria-labelledby="specifications">
#       <h2 id="specifications">Specifications</h2>
#       <h3>A</h3>  <ul><li><a href="...">API Name</a></li></ul>
#       <h3>B</h3>  <ul>...</ul>
#       ...
#     </section>
#     Confirmed 147 links via:
#       document.querySelectorAll('section[aria-labelledby="specifications"] a[href*="/docs/Web/API"]').length → 147
#
#   Interfaces section: ~900+ interface entries (not targeted).
#
# Detail page (Fetch API example):
#   <h1>Fetch API</h1>
#   <p>The Fetch API provides an interface for fetching resources...</p>
#   The h1 sits directly in main content; first <p> sibling is the one-liner.
#   Selector for description: confirmed via WebFetch as the first <p> after h1.
#
# Strategy (two-phase, limited to 10 detail pages):
#   Phase 1 (Discovery): BFS expand over links inside
#     section[aria-labelledby="specifications"] a  (limit=10 detail pages).
#     Using locator="." to extract href from <a> elements directly.
#   Phase 2 (Detail): Consume discovered URLs, open each, extract h1 + first <p>.
#
# Quality gates:
#   min_records = 5 (conservative; discovery limited to 10 pages)
#   name = 95% fill, description = 80% fill
#
# ------------------------------------------------------------------------------------------

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
    And I begin rule "index"
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
    And I begin rule "page"
    And selector "h1" exists
    Then I extract fields
    ...    field=name           extractor=text    locator="h1"
    ...    field=description    extractor=text    locator="article p"
    And I emit to artifact "${ARTIFACT_APIS}"

Quality Gates
    [Documentation]    Minimum thresholds for the MDN Web API scrape.
    And I set quality gate min records to 5
    And I set filled percentage for "name" to 95
    And I set filled percentage for "description" to 80
