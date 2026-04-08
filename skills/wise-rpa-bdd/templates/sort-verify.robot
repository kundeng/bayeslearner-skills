*** Settings ***
Documentation     Sort verification via state-check transitions
Library           WiseRpaBDD
Suite Setup       Given I start deployment "${DEPLOYMENT}"
Suite Teardown    Then I finalize deployment

*** Variables ***
${DEPLOYMENT}       sort-verify-example
${ENTRY_URL}        https://example.com/rankings
${ARTIFACT_ROWS}    rows

*** Test Cases ***
Artifact Catalog
    Given I register artifact "${ARTIFACT_ROWS}"
    ...    field=name      type=string    required=true
    ...    field=rating    type=number    required=true
    And I set artifact options for "${ARTIFACT_ROWS}"
    ...    format=jsonl
    ...    output=true

Sorted Extraction Resource
    [Setup]    Given I start resource "rankings" at "${ENTRY_URL}"
    Given url contains "/rankings"
    And selector "table" exists
    And I begin rule "sort_by_rating"
    And I declare parents ""
    When I click locator "th.sortable[data-col='rating']"
    ...    type=real
    When I wait for idle
    And I begin rule "sorted_results"
    And I declare parents "sort_by_rating"
    And selector "th.sortable[aria-sort='descending']" exists
    When I expand over elements "table.results tbody tr"
    Then I extract fields
    ...    field=name      extractor=text    locator="td.name"
    ...    field=rating    extractor=text    locator="td.rating"
    And I emit to artifact "${ARTIFACT_ROWS}"

Quality Gates
    And I set quality gate min records to 10
    And I set filled percentage for "rating" to 90
