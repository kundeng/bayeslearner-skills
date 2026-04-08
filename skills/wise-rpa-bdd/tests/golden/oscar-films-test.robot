*** Comments ***
Requirement    Scrape Oscar-winning films from https://www.scrapethissite.com/pages/ajax-javascript/ — the page
...            loads film data via AJAX when clicking year tabs (2010-2015). For each year, click the tab and extract
...            film title, nominations, awards, and whether it won best picture.
Expected       title,nominations,awards,best_picture
Min Records    80

# -- Evidence (live DOM -- npx agent-browser session) --------------------------
#
# Page: https://www.scrapethissite.com/pages/ajax-javascript/
#   Year tabs     : a.year-link              -- id="2015", id="2014", ... id="2010"
#                   Clicking a tab fires an AJAX request; results populate #table-body.
#   Table         : table.table > tbody#table-body
#   Film rows     : tr.film                  -- one per film per year
#   Title         : td.film-title            -- "Spotlight  " (text, whitespace-padded)
#   Nominations   : td.film-nominations      -- "6"
#   Awards        : td.film-awards           -- "2"
#   Best Picture  : td.film-best-picture     -- contains <i class="glyphicon glyphicon-flag"> if winner,
#                                               otherwise empty <td>
#
# Auth / cookies: none required.
# -------------------------------------------------------------------------------

*** Settings ***
Documentation     Single-resource AJAX extraction: use combination expansion to click each year tab
...               (2010-2015), then expand over film rows and extract title, nominations, awards,
...               and best-picture status.
Library           Browser
Library           WiseRpaBDD
Suite Setup       Given I start deployment "${DEPLOYMENT}"
Suite Teardown    Then I finalize deployment

*** Variables ***
${DEPLOYMENT}        oscar-films-ajax-scrape
${ENTRY_URL}         https://www.scrapethissite.com/pages/ajax-javascript/
${ARTIFACT_FILMS}    oscar_films

*** Test Cases ***
Artifact Catalog
    Given I register artifact "${ARTIFACT_FILMS}"
    ...    field=title           type=string    required=true
    ...    field=nominations     type=number    required=true
    ...    field=awards          type=number    required=true
    ...    field=best_picture    type=html      required=false
    And I set artifact options for "${ARTIFACT_FILMS}"
    ...    output=true
    ...    description=Oscar-winning films per year (2010-2015) loaded via AJAX tabs

Resource oscar films
    [Documentation]    Produces: oscar_films
    [Setup]    Given I start resource "oscar_films" at "${ENTRY_URL}"
    And I set resource globals
    ...    timeout_ms=30000
    ...    retries=2
    ...    page_load_delay_ms=2000
    And I begin rule "root"
    Given url contains "/pages/ajax-javascript"
    And selector "a.year-link" exists
    And I begin rule "year_tabs"
    And I declare parents "root"
    When I expand over combinations
    ...    action=click    control="a.year-link"    values=2015|2014|2013|2012|2011|2010
    And I begin rule "films"
    And I declare parents "year_tabs"
    And selector "tr.film" exists
    When I expand over elements "tr.film"
    Then I extract fields
    ...    field=title           extractor=text    locator="td.film-title"
    ...    field=nominations     extractor=text    locator="td.film-nominations"
    ...    field=awards          extractor=text    locator="td.film-awards"
    ...    field=best_picture    extractor=html    locator="td.film-best-picture"
    And I emit to artifact "${ARTIFACT_FILMS}"

Quality Gates
    And I set quality gate min records to 80
    And I set filled percentage for "title" to 95
    And I set filled percentage for "nominations" to 95
    And I set filled percentage for "awards" to 95
