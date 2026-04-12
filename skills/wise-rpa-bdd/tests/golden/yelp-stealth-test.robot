*** Comments ***
Requirement    Scrape top restaurant listings from Yelp search results using nodriver stealth mode. Dismiss cookie/consent banners on first load. Extract business name, rating, review count, and price range. Yelp uses DataDome — requires nodriver (no Playwright) to avoid detection.
Expected       name,rating,review_count,price
Min Records    10

*** Settings ***
Documentation     Stealth mode test: bypass DataDome on Yelp using nodriver
...               (raw CDP, no Playwright). Exercises: stealth adapter, interrupt
...               dismiss, element expansion, field extraction.
...               Requires WISE_RPA_STEALTH=1 (default) and nodriver installed.
...               NOTE: Do NOT import Library Browser — its Playwright process
...               is detectable by DataDome.
Library           WiseRpaBDD
Suite Setup       Given I start deployment "${DEPLOYMENT}"
Suite Teardown    Then I finalize deployment

*** Variables ***
${DEPLOYMENT}           yelp-stealth
${ENTRY_URL}            https://www.yelp.com/search?find_desc=restaurants&find_loc=San+Francisco
${ARTIFACT_LISTINGS}    listings

*** Test Cases ***
Artifact Catalog
    Given I register artifact "${ARTIFACT_LISTINGS}"
    ...    field=name    type=string    required=true
    ...    field=rating    type=string    required=true
    ...    field=review_count    type=string    required=true
    ...    field=price    type=string    required=false
    And I set artifact options for "${ARTIFACT_LISTINGS}"
    ...    output=true

Resource search_results
    [Documentation]    Produces: listings
    [Setup]    Given I start resource "search_results" at "${ENTRY_URL}"
    And I set resource globals
    ...    timeout_ms=45000
    ...    page_load_delay_ms=5000
    I define rule "root"
    Given url contains "yelp.com/search"
    And selector "[data-testid='serp-ia-card']" exists
    I define rule "items"
    And I declare parents "root"
    When I expand over elements "[data-testid='serp-ia-card']"
    ...    limit=15
    Then I extract fields
    ...    field=name    extractor=text    locator="h3 a | a[data-testid='biz-name']"
    ...    field=rating    extractor=attr    locator="[aria-label*='star rating']"    attr="aria-label"
    ...    field=review_count    extractor=text    locator="span[data-font-weight='semibold']"
    ...    field=price    extractor=text    locator="span[aria-label*='price'] | span.priceRange__09f24__mmOuH"
    And I emit to artifact "${ARTIFACT_LISTINGS}"

Quality Gates
    And I set quality gate min records to 10
    And I set filled percentage for "name" to 95
    And I set filled percentage for "rating" to 80
