*** Settings ***
Documentation     Click to reveal dynamic content with nested expansion
Library           WiseRpaBDD
Suite Setup       Given I start deployment "${DEPLOYMENT}"
Suite Teardown    Then I finalize deployment

*** Variables ***
${DEPLOYMENT}         element-click-example
${ENTRY_URL}          https://example.com/products
${ARTIFACT_VARIANTS}  variants

*** Test Cases ***
Artifact Catalog
    Given I register artifact "${ARTIFACT_VARIANTS}"
    ...    field=name        type=string    required=true
    ...    field=price       type=number    required=true
    ...    field=hdd_size    type=string    required=false
    And I set artifact options for "${ARTIFACT_VARIANTS}"
    ...    format=jsonl
    ...    output=true

Variant Extraction Resource
    [Setup]    Given I start resource "variants" at "${ENTRY_URL}"
    Given url contains "/products"
    And selector "div.product-wrapper" exists
    And I begin rule "color_variant"
    And I declare parents ""
    When I expand over elements "div.product-wrapper"
    When I click locator "select option:not(:has-text('Select'))"
    ...    type=real
    ...    uniqueness=css
    ...    delay_ms=2000
    And I begin rule "hdd_variation"
    And I declare parents "color_variant"
    When I click locator "button:not([disabled])"
    ...    type=real
    ...    uniqueness=text
    ...    delay_ms=2000
    And I begin rule "product_data"
    And I declare parents "hdd_variation"
    Then I extract fields
    ...    field=name        extractor=text    locator="h4[itemprop='name']"
    ...    field=price       extractor=text    locator="h4[itemprop='offers']"
    ...    field=hdd_size    extractor=text    locator="button.active"
    And I emit to artifact "${ARTIFACT_VARIANTS}"

Quality Gates
    And I set quality gate min records to 3
