*** Comments ***
Requirement    Log in to quotes.toscrape.com using raw Browser library calls
...            deferred via "And I call keyword", then scrape quotes.
...            Demonstrates the call-keyword passthrough mechanism for complex
...            multi-step flows that need raw Browser access at walk time.

*** Settings ***
Documentation     Call-keyword auth test: log in to quotes.toscrape.com via a
...               custom RF keyword containing raw Browser calls (Click, Fill Text),
...               deferred to walk time with "And I call keyword". Then scrape
...               quote text, author, and tags across 2 paginated pages.
...               Evidence: login form at /login with input#username, input#password,
...               input[type='submit']. Post-login indicator: a[href="/logout"].
...               Supports both stealth and non-stealth modes — the stealth bridge
...               swaps the Browser library instance so RF keywords resolve against
...               the stealth adapter's live page.
Library           Browser
Library           WiseRpaBDD
Suite Setup       Given I start deployment "${DEPLOYMENT}"
Suite Teardown    Then I finalize deployment

*** Variables ***
${DEPLOYMENT}           quotes-callkw-auth
${ENTRY_URL}            https://quotes.toscrape.com/login
${ARTIFACT_QUOTES}      quotes

*** Keywords ***
Login To Quotes
    [Documentation]    Raw Browser calls — runs at walk time, not test definition time.
    ...                Fill username and password, click submit, verify logged in.
    Fill Text    input#username    admin
    Fill Text    input#password    admin
    Click    input[type='submit']
    Wait For Elements State    a[href="/logout"]    visible    timeout=10s

*** Test Cases ***
Artifact Catalog
    Given I register artifact "${ARTIFACT_QUOTES}"
    ...    field=quote_text    type=string    required=true
    ...    field=author        type=string    required=true
    ...    field=tags          type=array     required=true
    And I set artifact options for "${ARTIFACT_QUOTES}"
    ...    output=true
    ...    structure=flat
    ...    description=Quotes scraped after call-keyword login (raw Browser calls)

Resource quote_pages
    [Documentation]    Produces: quotes
    [Setup]    Given I start resource "quote_pages" at "${ENTRY_URL}"
    And I set resource globals
    ...    timeout_ms=30000
    ...    retries=2
    ...    page_load_delay_ms=1000

    # Rule: login — pure action rule using call keyword for auth
    # The "Login To Quotes" keyword uses raw Browser calls (Fill Text, Click)
    # which are deferred to walk time when the browser is live.
    I define rule "login"
        And I call keyword "Login To Quotes"

    # Rule: root — state gate after login
    I define rule "root"
        And I declare parents "login"
        Given url matches "quotes.toscrape.com"
        And selector ".quote" exists

    # Rule: pages — paginate across 2 pages
    I define rule "pages"
        And I declare parents "root"
        When I paginate by next button "li.next a" up to 2 pages

    # Rule: items — expand + extract + emit
    I define rule "items"
        And I declare parents "pages"
        When I expand over elements ".quote"
        Then I extract fields
        ...    field=quote_text    extractor=text       locator="span.text"
        ...    field=author        extractor=text       locator="small.author"
        ...    field=tags          extractor=grouped    locator="a.tag"
        And I emit to artifact "${ARTIFACT_QUOTES}"

Quality Gates
    # 2 pages x 10 quotes/page = 20 minimum
    And I set quality gate min records to 20
    And I set filled percentage for "quote_text" to 100
    And I set filled percentage for "author" to 100
    And I set filled percentage for "tags" to 80
