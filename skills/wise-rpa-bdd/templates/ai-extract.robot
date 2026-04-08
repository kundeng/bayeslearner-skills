*** Settings ***
Documentation     AI semantic extraction on captured HTML content
Library           WiseRpaBDD
Suite Setup       Given I start deployment "${DEPLOYMENT}"
Suite Teardown    Then I finalize deployment

*** Variables ***
${DEPLOYMENT}         ai-extract-example
${ENTRY_URL}          https://example.com/reviews
${ARTIFACT_REVIEWS}   reviews

*** Test Cases ***
Artifact Catalog
    Given I register artifact "${ARTIFACT_REVIEWS}"
    ...    field=reviewer    type=string    required=true
    ...    field=rating      type=number    required=true
    ...    field=date        type=string    required=false
    ...    field=text        type=string    required=true
    And I set artifact options for "${ARTIFACT_REVIEWS}"
    ...    format=jsonl
    ...    output=true

Review Extraction Resource
    [Setup]    Given I start resource "reviews" at "${ENTRY_URL}"
    Given url contains "/reviews"
    And selector ".reviews-container" exists
    And I begin rule "root"
    And I declare parents ""
    Then I extract fields
    ...    field=raw_html    extractor=html    locator=".reviews-container"
    Then I extract with AI "parsed_reviews"
    ...    prompt="Extract all user reviews with rating, reviewer name, date, and text."
    ...    input=raw_html
    ...    schema={"type":"array","items":{"type":"object","properties":{"reviewer":{"type":"string"},"rating":{"type":"number"},"date":{"type":"string"},"text":{"type":"string"}}}}
    And I emit to artifact "${ARTIFACT_REVIEWS}"

Quality Gates
    And I set quality gate min records to 5
    And I set filled percentage for "reviewer" to 90
