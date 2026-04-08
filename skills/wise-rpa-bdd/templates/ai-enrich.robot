*** Settings ***
Documentation     Deterministic extraction with AI classification enrichment
Library           WiseRpaBDD
Suite Setup       Given I start deployment "${DEPLOYMENT}"
Suite Teardown    Then I finalize deployment

*** Variables ***
${DEPLOYMENT}          ai-enrich-example
${ENTRY_URL}           https://example.com/products
${ARTIFACT_PRODUCTS}   products

*** Test Cases ***
Artifact Catalog
    Given I register artifact "${ARTIFACT_PRODUCTS}"
    ...    field=description    type=string    required=true
    ...    field=price          type=number    required=true
    ...    field=category       type=string    required=true
    And I set artifact options for "${ARTIFACT_PRODUCTS}"
    ...    format=jsonl
    ...    output=true

Product Classification Resource
    [Setup]    Given I start resource "products" at "${ENTRY_URL}"
    Given url contains "/products"
    And selector ".product-card" exists
    And I begin rule "root"
    And I declare parents ""
    When I expand over elements ".product-card"
    Then I extract fields
    ...    field=description    extractor=text    locator=".desc"
    ...    field=price          extractor=number  locator=".price"
    Then I extract with AI "category"
    ...    prompt="Classify this product into exactly one category."
    ...    input=description
    ...    categories=electronics|clothing|home|food|other
    And I emit to artifact "${ARTIFACT_PRODUCTS}"

Quality Gates
    And I set quality gate min records to 10
    And I set filled percentage for "category" to 95
