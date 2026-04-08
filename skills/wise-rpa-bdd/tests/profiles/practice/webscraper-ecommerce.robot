*** Settings ***
Documentation     Generated from tests/profiles/practice/webscraper-ecommerce.yaml
Library           WiseRpaBDD
Suite Setup       Given I start deployment "${DEPLOYMENT}"
Suite Teardown    Then I finalize deployment

*** Variables ***
${DEPLOYMENT}    webscraper-ecommerce-test
${ENTRY_LAPTOPS}    https://www.webscraper.io/test-sites/e-commerce/allinone/computers/laptops

*** Test Cases ***
Resource laptops
    [Setup]    Given I start resource "laptops" at "${ENTRY_LAPTOPS}"
    And I set resource globals
    ...    timeout_ms=30000
    ...    retries=2
    ...    page_load_delay_ms=2000
    And I begin rule "root"
    And selector ".thumbnail" exists
    And I begin rule "products"
    And I declare parents "root"
    When I expand over elements ".thumbnail"
    ...    limit=10
    Then I extract fields
    ...    field=title    extractor=text    locator=".title"
    ...    field=price    extractor=text    locator=".price"
    ...    field=description    extractor=text    locator=".description"
    ...    field=rating_count    extractor=text    locator=".ratings .pull-right"
