*** Settings ***
Documentation     Cartesian product of filter axes for exhaustive search
Library           WiseRpaBDD
Suite Setup       Given I start deployment "${DEPLOYMENT}"
Suite Teardown    Then I finalize deployment

*** Variables ***
${DEPLOYMENT}        matrix-example
${ENTRY_URL}         https://example.com/search
${ARTIFACT_RESULTS}  results

*** Test Cases ***
Artifact Catalog
    Given I register artifact "${ARTIFACT_RESULTS}"
    ...    field=title    type=string    required=true
    ...    field=price    type=number    required=true
    And I set artifact options for "${ARTIFACT_RESULTS}"
    ...    format=jsonl
    ...    output=true

Matrix Search Resource
    [Setup]    Given I start resource "search" at "${ENTRY_URL}"
    Given url contains "/search"
    And I begin rule "search_combos"
    And I declare parents ""
    When I expand over combinations
    ...    action=type    control="#search-box"    values=laptop|tablet
    ...    action=select  control="#brand-dropdown" values=auto
    ...    action=checkbox control="#in-stock"      values=on
    When I wait for idle
    And I begin rule "results"
    And I declare parents "search_combos"
    When I expand over elements ".result-row"
    Then I extract fields
    ...    field=title    extractor=text    locator=".title"
    ...    field=price    extractor=number  locator=".price"
    And I emit to artifact "${ARTIFACT_RESULTS}"

Quality Gates
    And I set quality gate min records to 5
