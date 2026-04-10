*** Comments ***
Requirement    Scrape all quotes tagged "love" from quotes.toscrape.com.
...            Collect quote text, author, and all tags for each quote.

*** Settings ***
Documentation     Scrape love-tagged quotes from quotes.toscrape.com/tag/love/
...               extracting quote text, author, and all tags across paginated pages.
...               Evidence: div.quote containers, span.text, small.author, a.tag,
...               pagination via li.next a. Page 1 = 10 quotes, page 2 = 4 quotes.
...               14 total records expected.
Library           Browser
Library           WiseRpaBDD
Suite Setup       Given I start deployment "${DEPLOYMENT}"
Suite Teardown    Then I finalize deployment

*** Variables ***
${DEPLOYMENT}              quotes-by-tag-love
${ENTRY_URL}               https://quotes.toscrape.com/tag/love/
${ARTIFACT_QUOTES}         love_quotes
${ARTIFACT_QUOTES_FLAT}    love_quotes_flat

*** Test Cases ***
Artifact Catalog
    # Nested artifact — preserves page → quote tree structure
    Given I register artifact "${ARTIFACT_QUOTES}"
    ...    field=quote_text    type=string    required=true
    ...    field=author        type=string    required=true
    ...    field=tags          type=array     required=true
    And I set artifact options for "${ARTIFACT_QUOTES}"
    ...    output=true
    ...    structure=nested
    ...    description=Love-tagged quotes with page-level nesting
    # Flat artifact — denormalized, one row per quote; ready for CSV/JSONL export
    Given I register artifact "${ARTIFACT_QUOTES_FLAT}"
    ...    field=quote_text    type=string    required=true
    ...    field=author        type=string    required=true
    ...    field=tags          type=array     required=true
    And I set artifact options for "${ARTIFACT_QUOTES_FLAT}"
    ...    output=true
    ...    structure=flat
    ...    description=Love-tagged quotes as flat denormalized records

Resource love_quote_pages
    # ── Resource: paginated love-tagged quote listing ─────────────────────────
    # Entry: https://quotes.toscrape.com/tag/love/  (no auth required)
    # Three-rule tree: root (state gate) → pages (pagination) → items (extract)
    # Pagination: li.next a drives next-page clicks; absent on page 2 (natural stop).
    #             Limit=5 is a safety cap; site only has 2 pages for this tag.
    [Documentation]    Produces: love_quotes, love_quotes_flat
    [Setup]    Given I start resource "love_quote_pages" at "${ENTRY_URL}"
    And I set resource globals
    ...    timeout_ms=30000
    ...    retries=2
    ...    page_load_delay_ms=1000

    # Rule: root — state gate confirming we are on the love tag page
    # Evidence: url contains /tag/love; div.quote present on both pages
    I define rule "root"
        Given url contains "/tag/love"
        And selector ".quote" exists

    # Rule: pages — drive next-button pagination across all pages
    # Evidence: li.next present on p1 (href=/tag/love/page/2/), absent on p2.
    #           Limit=5 is a safety cap; engine stops naturally at page 2.
    I define rule "pages"
        And I declare parents "root"
        When I paginate by next button "li.next a" up to 5 pages

    # Rule: items — expand over each div.quote on every visited page, then extract
    # Evidence: 10 div.quote on page 1, 4 on page 2 (14 total).
    # Extractors:
    #   quote_text — .text (span class="text"); typographic quotes included
    #   author     — small.author (class="author"); direct text node
    #   tags       — .tag (a class="tag"); grouped extractor; 1+ tags per quote
    I define rule "items"
        And I declare parents "pages"
        When I expand over elements ".quote"
        Then I extract fields
        ...    field=quote_text    extractor=text       locator=".text"
        ...    field=author        extractor=text       locator="small.author"
        ...    field=tags          extractor=grouped    locator=".tag"
        And I emit to artifact "${ARTIFACT_QUOTES}"
        And I emit to artifact "${ARTIFACT_QUOTES_FLAT}"

Quality Gates
    # 2 pages: 10 + 4 = 14 records total; min 10 allows some tolerance
    # quote_text and author are always populated on every quote
    # tags: every quote on the love tag page has at least the "love" tag → 100%
    And I set quality gate min records to 10
    And I set filled percentage for "quote_text" to 100
    And I set filled percentage for "author" to 100
    And I set filled percentage for "tags" to 100
