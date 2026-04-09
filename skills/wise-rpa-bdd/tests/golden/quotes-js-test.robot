*** Comments ***
Requirement    Scrape quotes from the JavaScript-rendered version of quotes.toscrape.com.
...            Collect quote text, author, and tags.

*** Settings ***
Documentation     Scrape JS-rendered quote text, author, and tags from
...               quotes.toscrape.com/js/ across paginated pages using the
...               next-button pattern. Validates browser JS rendering capability.
...               Evidence: div.quote containers, span.text, small.author, a.tag,
...               pagination via li.next a. 10 quotes/page, limit=3 pages -> 30 records.
Library           Browser
Library           WiseRpaBDD
Suite Setup       Given I start deployment "${DEPLOYMENT}"
Suite Teardown    Then I finalize deployment

*** Variables ***
${DEPLOYMENT}              quotes-js-toscrape
${ENTRY_URL}               https://quotes.toscrape.com/js/
${ARTIFACT_QUOTES}         quotes_js

*** Test Cases ***
Artifact Catalog
    Given I register artifact "${ARTIFACT_QUOTES}"
    ...    field=quote_text    type=string    required=true
    ...    field=author        type=string    required=true
    ...    field=tags          type=array     required=true
    And I set artifact options for "${ARTIFACT_QUOTES}"
    ...    output=true
    ...    structure=flat
    ...    description=JS-rendered quotes as flat records (one row per quote)

Resource quote_js_pages
    # ── Resource: paginated JS-rendered quote listing ─────────────────────────
    # Entry: https://quotes.toscrape.com/js/  (no auth required)
    # Three-rule tree: root (state gate) -> pages (pagination) -> items (extract)
    # Pagination: li.next a drives next-page clicks; stops naturally on last page
    #             (li.next absent). Limit=3 pages -> exactly 30 records expected.
    [Documentation]    Produces: quotes_js
    [Setup]    Given I start resource "quote_js_pages" at "${ENTRY_URL}"
    And I set resource globals
    ...    timeout_ms=30000
    ...    retries=2
    ...    page_load_delay_ms=2000

    # Rule: root — state gate confirming JS has rendered quote elements
    # Evidence: url contains /js/; div.quote present once JS executes
    And I begin rule "root"
    Given url contains "/js/"
    And selector ".quote" exists

    # Rule: pages — drive next-button pagination across at most 3 pages
    # Evidence: li.next a present on p1 (href=/js/page/2/), p2 (href=/js/page/3/).
    #           Absent on last page. Limit=3 caps collection at pages 1-3.
    And I begin rule "pages"
    And I declare parents "root"
    When I paginate by next button "li.next a" up to 3 pages

    # Rule: items — expand over each div.quote on every visited page, then extract
    # Evidence: 10 div.quote elements per page (confirmed via querySelectorAll).
    # Extractors:
    #   quote_text — .text (span class="text"); typographic quotes included
    #   author     — small.author (class="author"); direct text node
    #   tags       — .tag (a class="tag"); grouped extractor; 0-N tags per quote
    And I begin rule "items"
    And I declare parents "pages"
    When I expand over elements ".quote"
    Then I extract fields
    ...    field=quote_text    extractor=text       locator=".text"
    ...    field=author        extractor=text       locator="small.author"
    ...    field=tags          extractor=grouped    locator=".tag"
    And I emit to artifact "${ARTIFACT_QUOTES}"

Quality Gates
    # 3 pages x 10 quotes/page = 30 records minimum
    # quote_text and author are always populated (confirmed on p1 sample)
    # tags allow 80% fill — some quotes may carry zero tags
    And I set quality gate min records to 30
    And I set filled percentage for "quote_text" to 100
    And I set filled percentage for "author" to 100
    And I set filled percentage for "tags" to 80
