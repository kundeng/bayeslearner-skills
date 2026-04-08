*** Settings ***
Documentation     Generated from tests/profiles/practice/quotes-test.yaml
Library           WiseRpaBDD
Suite Setup       Given I start deployment "${DEPLOYMENT}"
Suite Teardown    Then I finalize deployment

*** Variables ***
${DEPLOYMENT}    quotes-toscrape
${ARTIFACT_QUOTES}    quotes
${ARTIFACT_QUOTES_FLAT}    quotes_flat
${ENTRY_QUOTE_PAGES}    https://quotes.toscrape.com/

*** Test Cases ***
Artifact Catalog
    Given I register artifact "${ARTIFACT_QUOTES}"
    ...    field=quote_text    type=string    required=true
    ...    field=author    type=string    required=true
    ...    field=tags    type=array    required=true
    And I set artifact options for "${ARTIFACT_QUOTES}"
    ...    output=true
    ...    structure=nested
    ...    description=Quotes as nested tree records
    Given I register artifact "${ARTIFACT_QUOTES_FLAT}"
    ...    field=quote_text    type=string    required=true
    ...    field=author    type=string    required=true
    ...    field=tags    type=array    required=true
    And I set artifact options for "${ARTIFACT_QUOTES_FLAT}"
    ...    output=true
    ...    structure=flat
    ...    description=Quotes as flat denormalized records

Resource quote_pages
    [Documentation]    Produces: ['quotes', 'quotes_flat']
    [Setup]    Given I start resource "quote_pages" at "${ENTRY_QUOTE_PAGES}"
    And I set resource globals
    ...    timeout_ms=30000
    ...    retries=2
    And I begin rule "root"
    Given url matches "quotes.toscrape.com"
    And selector ".quote" exists
    And I begin rule "pages"
    And I declare parents "root"
    When I paginate by next button "li.next a" up to 3 pages
    And I begin rule "items"
    And I declare parents "pages"
    When I expand over elements ".quote"
    Then I extract fields
    ...    field=quote_text    extractor=text    locator=".text"
    ...    field=author    extractor=text    locator="small.author"
    ...    field=tags    extractor=grouped    locator=".tag"
    And I emit to artifact "${ARTIFACT_QUOTES}"
    And I emit to artifact "${ARTIFACT_QUOTES_FLAT}"

Quality Gates
    And I set quality gate min records to 25
    And I set filled percentage for "quote_text" to 95
    And I set filled percentage for "author" to 95
