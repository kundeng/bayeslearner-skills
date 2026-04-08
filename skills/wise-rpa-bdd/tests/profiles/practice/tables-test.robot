*** Settings ***
Documentation     Generated from tests/profiles/practice/tables-test.yaml
Library           WiseRpaBDD
Suite Setup       Given I start deployment "${DEPLOYMENT}"
Suite Teardown    Then I finalize deployment

*** Variables ***
${DEPLOYMENT}    tables-test
${ARTIFACT_TABLE_DATA}    table_data
${ARTIFACT_TABLE_DATA_NESTED}    table_data_nested
${ENTRY_TABLE_SCRAPE}    https://www.webscraper.io/test-sites/tables

*** Test Cases ***
Artifact Catalog
    Given I register artifact "${ARTIFACT_TABLE_DATA}"
    ...    field=#    type=string    required=true
    ...    field=First Name    type=string    required=true
    ...    field=Last Name    type=string    required=true
    ...    field=Username    type=string    required=true
    And I set artifact options for "${ARTIFACT_TABLE_DATA}"
    ...    output=true
    ...    structure=flat
    ...    description=Table rows as flat denormalized records
    Given I register artifact "${ARTIFACT_TABLE_DATA_NESTED}"
    ...    field=#    type=string    required=true
    ...    field=First Name    type=string    required=true
    ...    field=Last Name    type=string    required=true
    ...    field=Username    type=string    required=true
    And I set artifact options for "${ARTIFACT_TABLE_DATA_NESTED}"
    ...    output=true
    ...    structure=nested
    ...    description=Table data as nested tree records (rows array embedded)

Resource table_scrape
    [Documentation]    Produces: ['table_data', 'table_data_nested']
    [Setup]    Given I start resource "table_scrape" at "${ENTRY_TABLE_SCRAPE}"
    And I set resource globals
    ...    timeout_ms=30000
    ...    retries=2
    And I begin rule "root"
    Given url matches "test-sites/tables"
    And selector "table" exists
    And I begin rule "each_table"
    And I declare parents "root"
    When I expand over elements "table"
    Then I extract table "rows" from "table"
    ...    header_row=0
    ...    field=#    header="#"
    ...    field=First Name    header="First Name"
    ...    field=Last Name    header="Last Name"
    ...    field=Username    header="Username"
    And I emit to artifact "${ARTIFACT_TABLE_DATA}" flattened by "rows"
    And I emit to artifact "${ARTIFACT_TABLE_DATA_NESTED}"

Quality Gates
    And I set quality gate min records to 6
    And I set filled percentage for "First Name" to 100
    And I set filled percentage for "Last Name" to 100
    And I set filled percentage for "Username" to 100
