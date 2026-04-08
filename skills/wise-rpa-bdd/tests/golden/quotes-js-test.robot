*** Comments ***
Requirement    Scrape JavaScript-rendered quotes from https://quotes.toscrape.com/js/ — same content as the regular quotes page but rendered via JavaScript. Extract quote text, author, and tags. Paginate via next button for 3 pages. This tests that the browser engine handles JS rendering.
Expected       quote_text,author,tags
Min Records    30

# ── Evidence (live DOM — agent-browser session) ──────────────────────────────
#
# Fetched: https://quotes.toscrape.com/js/  (page 1, browser with JS enabled)
# Method:  npx agent-browser open + eval against live DOM; selectors verified.
#
# NOTE: This page renders ALL content via JavaScript. A curl/fetch will see an
#       empty <div id="content"> that gets populated by an inline <script> tag.
#       Only a JS-capable browser engine will produce the quote elements below.
#
# Quote container  : div.quote              — 10 per page (confirmed via querySelectorAll)
#                    <div class="quote">
#
# Quote text       : span.text              — selector: .text
#                    <span class="text">"The world as we have created it ..."</span>
#                    Includes typographic/curly quotes. Always present.
#
# Author           : small.author           — selector: small.author
#                    <small class="author">Albert Einstein</small>
#                    Direct text node, not inside an anchor. Always populated.
#
# Tags             : a.tag                  — selector: .tag (grouped extractor)
#                    <a class="tag">change</a>
#                    Multiple per quote; zero tags possible on some quotes.
#                    NOTE: unlike the static version, tag <a> elements have NO href.
#
# Next button      : li.next a              — selector: li.next a
#                    <a href="/js/page/2/">Next <span aria-hidden="true">→</span></a>
#                    li.next absent on last page (natural stop).
#
# Auth / cookies   : none — no login required, no cookie consent banner observed.
# Total pages      : 10 (100 quotes). Limit=3 pages -> 30 records minimum.
#
# ─────────────────────────────────────────────────────────────────────────────

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
