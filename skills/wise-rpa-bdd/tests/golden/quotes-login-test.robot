*** Comments ***
Requirement    Log in to quotes.toscrape.com, then scrape quotes that are only visible to authenticated users. Tests the auth/state setup feature.
Expected       quote_text,author,tags
Min Records    10

*** Settings ***
Documentation     Auth test: login via state setup, then scrape quotes.
...               Exercises: configure state setup, skip_when, action=open/input/click.
Library           Browser
Library           WiseRpaBDD
Suite Setup       Given I start deployment "${DEPLOYMENT}"
Suite Teardown    Then I finalize deployment

*** Variables ***
${DEPLOYMENT}           quotes-authenticated
${ENTRY_URL}            https://quotes.toscrape.com/
${ARTIFACT_QUOTES}      quotes

*** Test Cases ***
Artifact Catalog
    Given I register artifact "${ARTIFACT_QUOTES}"
    ...    field=quote_text    type=string    required=true
    ...    field=author    type=string    required=true
    ...    field=tags    type=array    required=true
    And I set artifact options for "${ARTIFACT_QUOTES}"
    ...    output=true

Auth Setup
    [Documentation]    Configure login flow — skip if already on logged-in page
    Given I configure state setup
    ...    skip_when=a[href="/logout"]
    ...    action=open    url="https://quotes.toscrape.com/login"
    ...    action=input    css="input#username"    value="admin"
    ...    action=password    css="input#password"    value="admin"
    ...    action=click    css="input[type='submit']"

Resource quote_pages
    [Documentation]    Produces: quotes
    [Setup]    Given I start resource "quote_pages" at "${ENTRY_URL}"
    And I set resource globals
    ...    timeout_ms=30000
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
    ...    field=quote_text    extractor=text    locator="span.text"
    ...    field=author    extractor=text    locator="small.author"
    ...    field=tags    extractor=grouped    locator="a.tag"
    And I emit to artifact "${ARTIFACT_QUOTES}"

Quality Gates
    And I set quality gate min records to 10
    And I set filled percentage for "quote_text" to 95
    And I set filled percentage for "author" to 95
