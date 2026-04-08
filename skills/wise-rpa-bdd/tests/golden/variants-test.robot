*** Comments ***
Requirement    Scrape laptop variant data from https://www.webscraper.io/test-sites/e-commerce/ajax/computers/laptops — discover product URLs, then for each product click HDD size buttons (128/256/512/1024) and extract the price for each variant.
Expected       title,hdd_size,price
Min Records    24

*** Settings ***
Documentation     Two-resource variant extraction: discover product URLs via BFS,
...               then use combination expansion to click each HDD size and extract prices.
Library           Browser
Library           WiseRpaBDD
Suite Setup       Given I start deployment "${DEPLOYMENT}"
Suite Teardown    Then I finalize deployment

*** Variables ***
${DEPLOYMENT}    laptop-ajax-variants-scrape
${ARTIFACT_PRODUCT_URLS}    product_urls
${ARTIFACT_VARIANT_DATA}    variant_data
${ARTIFACT_VARIANT_DATA_FLAT}    variant_data_flat
${ENTRY_DISCOVER}    https://www.webscraper.io/test-sites/e-commerce/ajax/computers/laptops
${ENTRY_VARIANTS}    https://www.webscraper.io{url}

*** Test Cases ***
Artifact Catalog
    Given I register artifact "${ARTIFACT_PRODUCT_URLS}"
    ...    field=url    type=string    required=true
    ...    field=title    type=string    required=true
    And I set artifact options for "${ARTIFACT_PRODUCT_URLS}"
    ...    dedupe=url
    ...    description=Product detail page URLs discovered from AJAX listing page
    Given I register artifact "${ARTIFACT_VARIANT_DATA}"
    ...    field=title    type=string    required=true
    ...    field=description    type=string    required=true
    ...    field=hdd_size    type=string    required=true
    ...    field=price    type=string    required=true
    And I set artifact options for "${ARTIFACT_VARIANT_DATA}"
    ...    output=true
    ...    structure=nested
    ...    consumes=product_urls
    ...    description=Variant data as nested tree records
    Given I register artifact "${ARTIFACT_VARIANT_DATA_FLAT}"
    ...    field=title    type=string    required=true
    ...    field=description    type=string    required=true
    ...    field=hdd_size    type=string    required=true
    ...    field=price    type=string    required=true
    And I set artifact options for "${ARTIFACT_VARIANT_DATA_FLAT}"
    ...    output=true
    ...    structure=flat
    ...    consumes=product_urls
    ...    description=Variant data as flat denormalized records

Resource discover
    [Documentation]    Produces: product_urls
    [Setup]    Given I start resource "discover" at "${ENTRY_DISCOVER}"
    And I set resource globals
    ...    timeout_ms=30000
    ...    retries=2
    ...    page_load_delay_ms=2000
    And I begin rule "root"
    Given url matches "/ajax/computers/laptops"
    And selector ".thumbnail" exists
    And I begin rule "products"
    And I declare parents "root"
    When I expand over elements ".thumbnail" with order "bfs"
    ...    limit=6
    Then I extract fields
    ...    field=url    extractor=attr    locator="a.title"    attr="href"
    ...    field=title    extractor=attr    locator="a.title"    attr="title"
    And I emit to artifact "${ARTIFACT_PRODUCT_URLS}"

Resource variants
    [Documentation]    Produces: variant_data, variant_data_flat
    [Setup]    Given I start resource "variants" at "${ENTRY_VARIANTS}"
    And I set resource globals
    ...    timeout_ms=30000
    ...    retries=2
    ...    page_load_delay_ms=2000
    And I begin rule "detail_root"
    Given url matches "/ajax/product/"
    And selector ".swatches" exists
    And I begin rule "hdd_variants"
    And I declare parents "detail_root"
    When I expand over combinations
    ...    action=click    control="button.swatch"    values=128|256|512|1024
    When I wait 500 ms
    Then I extract fields
    ...    field=title    extractor=text    locator="h4.card-title"
    ...    field=description    extractor=text    locator="p.description"
    ...    field=price    extractor=text    locator="h4.price.pull-right"
    ...    field=hdd_size    extractor=text    locator="button.swatch.active"
    And I emit to artifact "${ARTIFACT_VARIANT_DATA}"
    And I emit to artifact "${ARTIFACT_VARIANT_DATA_FLAT}"

Quality Gates
    And I set quality gate min records to 24
    And I set filled percentage for "title" to 95
    And I set filled percentage for "price" to 95
    And I set filled percentage for "hdd_size" to 95
