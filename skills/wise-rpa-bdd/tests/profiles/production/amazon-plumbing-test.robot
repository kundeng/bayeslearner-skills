*** Settings ***
Documentation     Generated from tests/profiles/production/amazon-plumbing-test.yaml
Library           WiseRpaBDD
Suite Setup       Given I start deployment "${DEPLOYMENT}"
Suite Teardown    Then I finalize deployment

*** Variables ***
${DEPLOYMENT}    amazon-plumbing-tools
${ARTIFACT_BRAND_URLS}    brand_urls
${ARTIFACT_PRODUCTS_NESTED}    products_nested
${ARTIFACT_PRODUCTS_FLAT}    products_flat
${ENTRY_DISCOVER_BRANDS}    https://www.amazon.com/s?k=plumbing+tools
${ENTRY_EXTRACT_PRODUCTS}    https://www.amazon.com{url}

*** Test Cases ***
Artifact Catalog
    Given I register artifact "${ARTIFACT_BRAND_URLS}"
    ...    field=brand_name    type=string    required=true
    ...    field=url    type=string    required=true
    And I set artifact options for "${ARTIFACT_BRAND_URLS}"
    ...    dedupe=url
    ...    description=Brand filter URLs from the sidebar
    Given I register artifact "${ARTIFACT_PRODUCTS_NESTED}"
    ...    field=brand_name    type=string    required=true
    ...    field=title    type=string    required=true
    ...    field=price    type=string    required=false
    ...    field=rating    type=string    required=false
    ...    field=asin    type=string    required=false
    And I set artifact options for "${ARTIFACT_PRODUCTS_NESTED}"
    ...    output=true
    ...    structure=nested
    ...    consumes=brand_urls
    ...    description=Product listings as nested tree records
    Given I register artifact "${ARTIFACT_PRODUCTS_FLAT}"
    ...    field=brand_name    type=string    required=true
    ...    field=title    type=string    required=true
    ...    field=price    type=string    required=false
    ...    field=rating    type=string    required=false
    ...    field=asin    type=string    required=false
    And I set artifact options for "${ARTIFACT_PRODUCTS_FLAT}"
    ...    output=true
    ...    structure=flat
    ...    consumes=brand_urls
    ...    description=Product listings as flat denormalized records

Resource discover_brands
    [Documentation]    Produces: brand_urls
    [Setup]    Given I start resource "discover_brands" at "${ENTRY_DISCOVER_BRANDS}"
    And I set resource globals
    ...    timeout_ms=30000
    ...    retries=2
    ...    page_load_delay_ms=3000
    And I begin rule "root"
    Given url matches "amazon.com/s"
    And selector "#brandsRefinements" exists
    And I begin rule "brands"
    And I declare parents "root"
    When I expand over elements "#brandsRefinements li:has(a.a-link-normal)" with order "bfs"
    ...    limit=3
    Then I extract fields
    ...    field=brand_name    extractor=text    locator="a.a-link-normal"
    ...    field=url    extractor=link    locator="a.a-link-normal"
    And I emit to artifact "${ARTIFACT_BRAND_URLS}"

Resource extract_products
    [Documentation]    Produces: ['products_nested', 'products_flat']
    [Setup]    Given I start resource "extract_products" at "${ENTRY_EXTRACT_PRODUCTS}"
    And I set resource globals
    ...    timeout_ms=30000
    ...    retries=2
    ...    page_load_delay_ms=3000
    ...    request_interval_ms=2000
    And I begin rule "brand_root"
    And selector "[data-component-type='s-search-result']" exists
    And I begin rule "pages"
    And I declare parents "brand_root"
    When I paginate by next button "a.s-pagination-next" up to 2 pages
    And I begin rule "product_cards"
    And I declare parents "pages"
    When I expand over elements "[data-component-type='s-search-result']"
    Then I extract fields
    ...    field=title    extractor=text    locator="h2 span"
    ...    field=price    extractor=text    locator=".a-price .a-offscreen"
    ...    field=rating    extractor=text    locator=".a-icon-alt"
    ...    field=asin    extractor=attr    locator="[data-asin]"    attr="data-asin"
    And I emit to artifact "${ARTIFACT_PRODUCTS_NESTED}"
    And I emit to artifact "${ARTIFACT_PRODUCTS_FLAT}"

Quality Gates
    And I set quality gate min records to 50
    And I set filled percentage for "title" to 90
    And I set filled percentage for "asin" to 90
