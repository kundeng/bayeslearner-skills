*** Settings ***
Documentation     Generated from tests/profiles/production/umsalary-test.yaml
Library           WiseRpaBDD
Suite Setup       Given I start deployment "${DEPLOYMENT}"
Suite Teardown    Then I finalize deployment

*** Variables ***
${DEPLOYMENT}    umsalary-staff-salaries
${ARTIFACT_SALARY_RECORDS}    salary_records
${ARTIFACT_SALARY_RECORDS_NESTED}    salary_records_nested
${ENTRY_SALARY_SEARCH}    https://www.umsalary.info/index.php

*** Test Cases ***
Artifact Catalog
    Given I register artifact "${ARTIFACT_SALARY_RECORDS}"
    ...    field=name    type=string    required=true
    ...    field=title    type=string    required=true
    ...    field=department    type=string    required=true
    ...    field=ftr    type=string    required=true
    ...    field=gr    type=string    required=true
    And I set artifact options for "${ARTIFACT_SALARY_RECORDS}"
    ...    output=true
    ...    structure=flat
    ...    description=Salary records as flat denormalized records
    Given I register artifact "${ARTIFACT_SALARY_RECORDS_NESTED}"
    ...    field=name    type=string    required=true
    ...    field=title    type=string    required=true
    ...    field=department    type=string    required=true
    ...    field=ftr    type=string    required=true
    ...    field=gr    type=string    required=true
    And I set artifact options for "${ARTIFACT_SALARY_RECORDS_NESTED}"
    ...    output=true
    ...    structure=nested
    ...    description=Salary data as nested tree records (rows array embedded)

Resource salary_search
    [Documentation]    Produces: ['salary_records', 'salary_records_nested']
    [Setup]    Given I start resource "salary_search" at "${ENTRY_SALARY_SEARCH}"
    And I set resource globals
    ...    timeout_ms=30000
    ...    retries=2
    ...    page_load_delay_ms=3000
    And I begin rule "root"
    Given url matches "umsalary.info"
    And selector "input[name='LName']" exists
    And I begin rule "search_combos"
    And I declare parents "root"
    When I expand over combinations
    ...    action=type    control=input[name='LName']    values=['coc', 'smith', 'jones']
    And I begin rule "submit_search"
    And I declare parents "search_combos"
    When I click locator "input[type='submit']"
    ...    type=real
    When I wait for idle
    And I begin rule "results_table"
    And I declare parents "submit_search"
    And table headers are "Name | Title | Department | FTR | GR"
    Then I extract table "salary_data" from "table.index"
    ...    header_row=1
    ...    field=name    header="Name"
    ...    field=title    header="Title"
    ...    field=department    header="Department"
    ...    field=ftr    header="FTR"
    ...    field=gr    header="GR"
    And I emit to artifact "${ARTIFACT_SALARY_RECORDS}" flattened by "salary_data"
    And I emit to artifact "${ARTIFACT_SALARY_RECORDS_NESTED}"

Quality Gates
    And I set quality gate min records to 3
    And I set filled percentage for "name" to 95
    And I set filled percentage for "title" to 90
    And I set filled percentage for "ftr" to 90
