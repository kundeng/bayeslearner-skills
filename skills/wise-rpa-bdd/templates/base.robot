*** Settings ***
Documentation     Minimal strict BDD suite for RPA extraction
Library           WiseRpaBDD
Suite Setup       Given I start deployment "${DEPLOYMENT}"
Suite Teardown    Then I finalize deployment

*** Variables ***
${DEPLOYMENT}        example-deployment
${ENTRY_URL}         https://example.com
${ARTIFACT_RECORDS}  records

*** Test Cases ***
Artifact Catalog
    Given I register artifact "${ARTIFACT_RECORDS}"
    ...    field=title    type=string    required=true
    ...    field=url      type=url       required=true
    And I set artifact options for "${ARTIFACT_RECORDS}"
    ...    format=jsonl
    ...    output=true

Primary Resource
    [Setup]    Given I start resource "primary" at "${ENTRY_URL}"
    Given url contains "/"
    And selector ".row" exists
    When I expand over elements ".row" with order "dfs"
    Then I extract fields
    ...    field=title    extractor=text    locator=".title"
    ...    field=url      extractor=link    locator="a"
    And I emit to artifact "${ARTIFACT_RECORDS}"

Quality Gates
    And I set quality gate min records to 10
    And I set filled percentage for "title" to 95
