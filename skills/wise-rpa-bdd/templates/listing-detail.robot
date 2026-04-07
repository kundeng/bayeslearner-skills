*** Settings ***
Documentation     Listing to detail flow with explicit parent chaining
Library           WiseRpaBDD
Suite Setup       Given I start deployment "${DEPLOYMENT}"
Suite Teardown    Then I finalize deployment

*** Variables ***
${DEPLOYMENT}         listing-detail
${LISTING_ENTRY}      https://example.com/products
${ARTIFACT_PRODUCTS}  products

*** Test Cases ***
Artifact Catalog
    Given I register artifact "${ARTIFACT_PRODUCTS}"
    ...    field=name           type=string    required=true
    ...    field=price          type=number    required=true
    ...    field=url            type=url       required=true
    ...    field=description    type=string    required=false
    And I set artifact options for "${ARTIFACT_PRODUCTS}"
    ...    format=jsonl
    ...    output=true

Listing Resource
    [Setup]    Given I start resource "product-listings" at "${LISTING_ENTRY}"
    Given url contains "/products"
    And selector ".product-card" exists
    When I expand over elements ".product-card" with order "bfs"
    Then I extract fields
    ...    field=name    extractor=text      locator=".title"
    ...    field=price   extractor=number    locator=".price"
    ...    field=url     extractor=link      locator="a"
    And I emit to artifact "${ARTIFACT_PRODUCTS}"
    And I paginate by next button ".pagination-next" up to 10 pages

Detail Resource
    [Setup]    Given I iterate over parent records from "Listing Resource"
    When I open the bound field "url"
    Then I extract fields
    ...    field=description    extractor=text    locator=".product-desc"
    And I merge into artifact "${ARTIFACT_PRODUCTS}" on key "url"
