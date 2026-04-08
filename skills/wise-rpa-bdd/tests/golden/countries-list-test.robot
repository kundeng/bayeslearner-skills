*** Comments ***
Requirement    Scrape all countries from https://www.scrapethissite.com/pages/simple/ — extract country name, capital, population, and area. All data is on a single page in div.country elements.
Expected       country_name,capital,population,area
Min Records    200

# ── Evidence (live DOM — curl exploration) ───────────────────────────────────
#
# Fetched: https://www.scrapethissite.com/pages/simple/  (single page, no pagination)
# Method:  curl + grep against live HTML response; selectors confirmed directly.
#
# Page heading     : h1 — "Countries of the World: A Simple Example" <small>250 items</small>
# Total countries  : 250 (stated in heading; confirmed via grep count of div.country)
#
# Country container: div.col-md-4.country
#                    <div class="col-md-4 country"> ... </div>
#
# Country name     : h3.country-name
#                    <h3 class="country-name"><i class="flag-icon ..."></i> Andorra</h3>
#                    Text node after the <i> flag icon. Always present.
#
# Capital          : span.country-capital
#                    <span class="country-capital">Andorra la Vella</span>
#                    Always present (some may be empty for territories).
#
# Population       : span.country-population
#                    <span class="country-population">84000</span>
#                    Numeric string. Always present (some may be 0).
#
# Area             : span.country-area
#                    <span class="country-area">468.0</span>
#                    Numeric string with decimal. Always present (some may be 0.0).
#
# Pagination       : none — all 250 countries rendered on a single page.
# Auth / cookies   : none — no login required, no cookie consent banner observed.
#
# ─────────────────────────────────────────────────────────────────────────────

*** Settings ***
Documentation     Scrape country name, capital, population, and area from
...               scrapethissite.com/pages/simple/ — a single-page listing of 250 countries.
...               Evidence: div.col-md-4.country containers with h3.country-name,
...               span.country-capital, span.country-population, span.country-area.
...               No pagination needed.
Library           Browser
Library           WiseRpaBDD
Suite Setup       Given I start deployment "${DEPLOYMENT}"
Suite Teardown    Then I finalize deployment

*** Variables ***
${DEPLOYMENT}            countries-simple
${ENTRY_URL}             https://www.scrapethissite.com/pages/simple/
${ARTIFACT_COUNTRIES}    countries

*** Test Cases ***
Artifact Catalog
    Given I register artifact "${ARTIFACT_COUNTRIES}"
    ...    field=country_name    type=string    required=true
    ...    field=capital         type=string    required=true
    ...    field=population      type=number    required=true
    ...    field=area            type=number    required=true
    And I set artifact options for "${ARTIFACT_COUNTRIES}"
    ...    output=true
    ...    structure=flat
    ...    description=All countries with name, capital, population, and area

Resource country_listing
    [Documentation]    Produces: countries
    [Setup]    Given I start resource "country_listing" at "${ENTRY_URL}"
    And I set resource globals
    ...    timeout_ms=30000
    ...    retries=2
    ...    page_load_delay_ms=1000

    # Rule: root — state gate confirming correct page before extraction
    # Evidence: url contains /pages/simple/; div.country elements present
    And I begin rule "root"
    Given url contains "/pages/simple/"
    And selector ".country" exists

    # Rule: items — expand over each div.country and extract four fields
    # Evidence: 250 div.col-md-4.country elements on a single page.
    # Extractors:
    #   country_name — h3.country-name; text node (flag icon child ignored by text extractor)
    #   capital      — span.country-capital; direct text
    #   population   — span.country-population; numeric string
    #   area         — span.country-area; numeric string with decimal
    And I begin rule "items"
    And I declare parents "root"
    When I expand over elements ".country"
    Then I extract fields
    ...    field=country_name    extractor=text      locator="h3.country-name"
    ...    field=capital         extractor=text      locator=".country-capital"
    ...    field=population      extractor=number    locator=".country-population"
    ...    field=area            extractor=number    locator=".country-area"
    And I emit to artifact "${ARTIFACT_COUNTRIES}"

Quality Gates
    # 250 countries total; require at least 200 to allow for minor edge cases
    # country_name and capital should always be populated
    # population and area may be zero for some territories but the field is always present
    And I set quality gate min records to 200
    And I set filled percentage for "country_name" to 100
    And I set filled percentage for "capital" to 90
    And I set filled percentage for "population" to 90
    And I set filled percentage for "area" to 90
