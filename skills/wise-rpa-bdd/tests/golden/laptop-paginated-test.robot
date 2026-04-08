*** Comments ***
Requirement    Scrape all laptops from https://www.webscraper.io/test-sites/e-commerce/static/computers/laptops — paginated site with next button, extract title, price, description, and rating.
Expected       title,price,description,rating
Min Records    100

*** Settings ***
Documentation     Generated from tests/profiles/practice/laptop-paginated-test.yaml
Library           Browser
Library           WiseRpaBDD
Suite Setup       Given I start deployment "${DEPLOYMENT}"
Suite Teardown    Then I finalize deployment

*** Variables ***
${DEPLOYMENT}    laptop-paginated-scrape
${ARTIFACT_LAPTOPS_NESTED}    laptops_nested
${ARTIFACT_LAPTOPS_FLAT}    laptops_flat
${ENTRY_LAPTOPS}    https://www.webscraper.io/test-sites/e-commerce/static/computers/laptops

*** Test Cases ***
Artifact Catalog
    Given I register artifact "${ARTIFACT_LAPTOPS_NESTED}"
    ...    field=title    type=string    required=true
    ...    field=price    type=string    required=true
    ...    field=description    type=string    required=true
    ...    field=rating    type=string    required=false
    And I set artifact options for "${ARTIFACT_LAPTOPS_NESTED}"
    ...    output=true
    ...    structure=nested
    ...    description=Paginated laptop products as nested tree records
    Given I register artifact "${ARTIFACT_LAPTOPS_FLAT}"
    ...    field=title    type=string    required=true
    ...    field=price    type=string    required=true
    ...    field=description    type=string    required=true
    ...    field=rating    type=string    required=false
    And I set artifact options for "${ARTIFACT_LAPTOPS_FLAT}"
    ...    output=true
    ...    structure=flat
    ...    description=Paginated laptop products as flat denormalized records

Resource laptops
    [Documentation]    Produces: ['laptops_nested', 'laptops_flat']
    [Setup]    Given I start resource "laptops" at "${ENTRY_LAPTOPS}"
    And I set resource globals
    ...    timeout_ms=30000
    ...    retries=2
    ...    page_load_delay_ms=2000
    And I begin rule "root"
    Given url matches "/computers/laptops"
    And selector ".thumbnail" exists
    And I begin rule "pages"
    And I declare parents "root"
    When I paginate by next button "a.page-link.next" up to 25 pages
    And I begin rule "products"
    And I declare parents "pages"
    When I expand over elements ".thumbnail"
    Then I extract fields
    ...    field=title    extractor=attr    locator="a.title"    attr="title"
    ...    field=price    extractor=text    locator="span[itemprop=price]"
    ...    field=description    extractor=text    locator=".description"
    ...    field=rating    extractor=attr    locator="p[data-rating]"    attr="data-rating"
    And I emit to artifact "${ARTIFACT_LAPTOPS_NESTED}"
    And I emit to artifact "${ARTIFACT_LAPTOPS_FLAT}"

Quality Gates
    And I set quality gate min records to 100
    And I set filled percentage for "title" to 95
    And I set filled percentage for "price" to 95
    And I set filled percentage for "description" to 90
    And I set filled percentage for "rating" to 80
