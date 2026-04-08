*** Comments ***
Requirement    Scrape all available test pages from https://the-internet.herokuapp.com/ — extract page names and their URLs from the main index. Simple single-page element expansion.
Expected       page_name,page_url
Min Records    40

# ── Evidence (live DOM — curl + agent-browser exploration) ──────────────────
#
# Fetched: https://the-internet.herokuapp.com/  (single page, no pagination)
# Method:  curl + grep against live HTML; agent-browser snapshot for interactive confirmation.
#
# Page heading     : h1.heading — "Welcome to the-internet"
# Subheading       : h2 — "Available Examples"
# Total links      : 44 (confirmed via grep count of <li><a href= in #content ul)
#
# Container        : #content ul
#                    <ul> ... </ul>
#                    Single unordered list; inline style removes bullets.
#
# Item             : #content ul li
#                    <li><a href='/abtest'>A/B Testing</a></li>
#                    Each <li> contains one <a> with the page path and display name.
#                    Some <li> have trailing text after </a> (e.g. " (user and pass: admin)")
#                    which is NOT part of the link and should be ignored.
#
# Page name        : #content ul li a — link text
#                    Examples: "A/B Testing", "Checkboxes", "Sortable Data Tables"
#
# Page URL         : #content ul li a — href attribute (relative paths like /abtest)
#                    Extractor type=link will resolve to absolute URL automatically.
#
# Pagination       : none — all 44 links rendered on a single page.
# Auth / cookies   : none — no login required, no cookie consent banner observed.
#
# ────────────────────────────────────────────────────────────────────────────

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
