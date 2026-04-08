*** Comments ***
Requirement    Scrape top restaurant listings from Yelp search results. Dismiss the OneTrust cookie banner on first load. Extract business name, rating, review count, and price range.
Expected       name,rating,review_count,price
Min Records    10

*** Settings ***
Documentation     Interrupt dismiss test: auto-dismiss OneTrust cookie banner,
...               then scrape Yelp search results. Exercises: configure interrupts,
...               element expansion, field extraction with post_extract hooks.
Library           Browser
Library           WiseRpaBDD
Suite Setup       Given I start deployment "${DEPLOYMENT}"
Suite Teardown    Then I finalize deployment

*** Variables ***
${DEPLOYMENT}           yelp-restaurants
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
    And I register hook "normalize" at "post_extract"
    ...    strip_html=name
    ...    lowercase=price

Interrupt Setup
    [Documentation]    Dismiss OneTrust cookie consent banner
    And I configure interrupts
    ...    dismiss="#onetrust-accept-btn-handler"

Resource search_results
    [Documentation]    Produces: listings
    [Setup]    Given I start resource "search_results" at "${ENTRY_URL}"
    And I set resource globals
    ...    timeout_ms=30000
    ...    page_load_delay_ms=3000
    And I begin rule "root"
    Given url contains "yelp.com/search"
    And selector "[data-testid='serp-ia-card']" exists
    And I begin rule "items"
    And I declare parents "root"
    When I expand over elements "[data-testid='serp-ia-card']"
    ...    limit=15
    Then I extract fields
    ...    field=name    extractor=text    locator="a[data-testid='biz-name']"
    ...    field=rating    extractor=attr    locator="[aria-label*='star rating']"    attr="aria-label"
    ...    field=review_count    extractor=text    locator="span.reviewCount__09f24__yCShS"
    ...    field=price    extractor=text    locator="span.priceRange__09f24__mmOuH"
    And I emit to artifact "${ARTIFACT_LISTINGS}"

Quality Gates
    And I set quality gate min records to 10
    And I set filled percentage for "name" to 95
    And I set filled percentage for "rating" to 80
