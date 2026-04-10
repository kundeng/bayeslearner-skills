*** Comments ***
Requirement    Log in to quotes.toscrape.com (username: admin, password: admin),
...            then scrape quotes. Collect quote text, author, and tags.

*** Settings ***
Documentation     Auth test: log in to quotes.toscrape.com via state setup, then
...               scrape quote text, author, and tags across 3 paginated pages.
...               Evidence: login form at /login with input#username, input#password,
...               input[type='submit']. Post-login indicator: a[href="/logout"].
...               Quote selectors: div.quote, span.text, small.author, a.tag.
...               Pagination: li.next a, limit=3 pages, 10 quotes/page → 30 records.
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
    ...    field=author        type=string    required=true
    ...    field=tags          type=array     required=true
    And I set artifact options for "${ARTIFACT_QUOTES}"
    ...    output=true
    ...    structure=flat
    ...    description=Quotes scraped after authenticated login (one row per quote)

Auth Setup
    [Documentation]    Configure login flow — skip if logout link already present
    Given I configure state setup
    ...    skip_when=a[href="/logout"]
    ...    action=open       url="https://quotes.toscrape.com/login"
    ...    action=input      css="input#username"          value="admin"
    ...    action=password   css="input#password"          value="admin"
    ...    action=click      css="input[type='submit']"

Resource quote_pages
    [Documentation]    Produces: quotes
    [Setup]    Given I start resource "quote_pages" at "${ENTRY_URL}"
    And I set resource globals
    ...    timeout_ms=30000
    ...    retries=2
    ...    page_load_delay_ms=1000

    # Rule: root — state gate confirming correct domain and quote presence
    I define rule "root"
        Given url matches "quotes.toscrape.com"
        And selector ".quote" exists

    # Rule: pages — drive next-button pagination across at most 3 pages
    I define rule "pages"
        And I declare parents "root"
        When I paginate by next button "li.next a" up to 3 pages

    # Rule: items — expand over each div.quote, extract fields, emit
    I define rule "items"
        And I declare parents "pages"
        When I expand over elements ".quote"
        Then I extract fields
        ...    field=quote_text    extractor=text       locator="span.text"
        ...    field=author        extractor=text       locator="small.author"
        ...    field=tags          extractor=grouped    locator="a.tag"
        And I emit to artifact "${ARTIFACT_QUOTES}"

Quality Gates
    # 3 pages × 10 quotes/page = 30 records minimum
    And I set quality gate min records to 30
    And I set filled percentage for "quote_text" to 100
    And I set filled percentage for "author" to 100
    And I set filled percentage for "tags" to 80
