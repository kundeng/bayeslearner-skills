*** Comments ***
Requirement    Scrape quotes from quotes.toscrape.com using fallback selectors.
...            Exercises pipe-delimited selector chains — the engine tries each
...            candidate in order and uses the first that matches on the live page.

*** Settings ***
Documentation     Fallback selector resilience test: every extractor uses a
...               pipe-delimited selector chain where the first option is a
...               plausible-but-wrong selector. The engine must fall back to
...               the second (correct) selector and still extract all fields.
...               Also exercises exclude_if to skip elements containing an
...               inner marker (simulates sponsored-item filtering).
Library           Browser
Library           WiseRpaBDD
Suite Setup       Given I start deployment "${DEPLOYMENT}"
Suite Teardown    Then I finalize deployment

*** Variables ***
${DEPLOYMENT}           quotes-fallback-selectors
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
    ...    description=Quotes extracted via fallback selector chains

Resource quote_pages
    # Exercises three spec-08 features:
    #   1. Fallback selectors on state check (selector exists)
    #   2. Fallback selectors on field extraction (pipe-delimited locators)
    #   3. exclude_if on element expansion (sponsored-item pattern)
    [Documentation]    Produces: quotes
    [Setup]    Given I start resource "quote_pages" at "${ENTRY_URL}"
    And I set resource globals
    ...    timeout_ms=30000
    ...    retries=2
    ...    page_load_delay_ms=1000

    # Rule: root — state gate with fallback selector
    # First selector (div.quote-card) doesn't exist; falls back to div.quote
    I define rule "root"
        Given url matches "quotes.toscrape.com"
        And selector "div.quote-card | div.quote" exists

    # Rule: pages — standard pagination, limit 2 pages
    I define rule "pages"
        And I declare parents "root"
        When I paginate by next button "li.next a" up to 2 pages

    # Rule: items — expand with exclude_if + fallback selectors on extraction
    # exclude_if="a.tag:text('inspirational')" skips quotes tagged "inspirational"
    # (demonstrates the filter; on page 1 this drops ~3 of 10 quotes)
    I define rule "items"
        And I declare parents "pages"
        When I expand over elements ".quote"
        ...    exclude_if=a.tag:text('inspirational')
        Then I extract fields
        ...    field=quote_text    extractor=text       locator="span.quote-text | span.text"
        ...    field=author        extractor=text       locator="small.quote-author | small.author"
        ...    field=tags          extractor=grouped    locator="a.tag-link | a.tag"
        And I emit to artifact "${ARTIFACT_QUOTES}"

Quality Gates
    # 2 pages, ~7 quotes/page after filtering out "inspirational" ones
    And I set quality gate min records to 10
    And I set filled percentage for "quote_text" to 100
    And I set filled percentage for "author" to 100
    And I set filled percentage for "tags" to 80
