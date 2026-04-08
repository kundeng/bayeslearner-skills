*** Comments ***
Requirement    Scrape all quotes from https://quotes.toscrape.com/ — extract quote text, author name, and tags for each quote. The site has pagination (next button). Collect at least 3 pages.
Expected       quote_text,author,tags
Min Records    30

# ── Evidence (live DOM — /rrpa-explore session) ────────────────────────────────
#
# Fetched: https://quotes.toscrape.com/  (pages 1, 2, 3, 10)
# Method:  curl + grep against live HTML responses
#
# Quote container  : div.quote              — 10 per page on p1/2/3/10 (confirmed)
#                    <div class="quote" itemscope itemtype="http://schema.org/CreativeWork">
#
# Quote text       : span.text              — selector: .text
#                    <span class="text" itemprop="text">"…"</span>
#                    Includes curly/typographic quotes. Unique class per container.
#
# Author           : small.author           — selector: small.author
#                    <small class="author" itemprop="author">Albert Einstein</small>
#                    Always present; nested inside a bare <span>.
#
# Tags             : a.tag                  — selector: .tag (grouped extractor)
#                    <a class="tag" href="/tag/change/page/1/">change</a>
#                    Multiple per quote, inside <div class="tags">. Zero tags possible.
#
# Next button      : li.next a              — selector: li.next a
#                    <li class="next"><a href="/page/2/">Next <span aria-hidden="true">→</span></a>
#                    Absent on page 10 (natural stop — no sentinel CSS needed).
#
# Prev button      : li.previous a          — present on pages 2–10; not used for navigation.
#
# Auth / cookies   : none — no login, no cookie consent banner observed.
# Total pages      : 10 (100 quotes). Limit set to 3 → 30 records minimum.
#
# ───────────────────────────────────────────────────────────────────────────────

*** Settings ***
Documentation     Scrape quote text, author, and tags from quotes.toscrape.com
...               across paginated pages using the next-button pattern.
...               Evidence: div.quote containers, span.text, small.author, a.tag,
...               pagination via li.next a. 10 quotes/page, limit=3 pages → 30 records.
Library           Browser
Library           WiseRpaBDD
Suite Setup       Given I start deployment "${DEPLOYMENT}"
Suite Teardown    Then I finalize deployment

*** Variables ***
${DEPLOYMENT}              quotes-toscrape
${ENTRY_URL}               https://quotes.toscrape.com/
${ARTIFACT_QUOTES}         quotes
${ARTIFACT_QUOTES_FLAT}    quotes_flat

*** Test Cases ***
Artifact Catalog
    # Nested artifact — preserves page → item tree structure for downstream chaining
    Given I register artifact "${ARTIFACT_QUOTES}"
    ...    field=quote_text    type=string    required=true
    ...    field=author        type=string    required=true
    ...    field=tags          type=array     required=true
    And I set artifact options for "${ARTIFACT_QUOTES}"
    ...    output=true
    ...    structure=nested
    ...    description=Quotes with page-level nesting (nested tree records)
    # Flat artifact — denormalized, one row per quote; ready for CSV/JSONL export
    Given I register artifact "${ARTIFACT_QUOTES_FLAT}"
    ...    field=quote_text    type=string    required=true
    ...    field=author        type=string    required=true
    ...    field=tags          type=array     required=true
    And I set artifact options for "${ARTIFACT_QUOTES_FLAT}"
    ...    output=true
    ...    structure=flat
    ...    description=Quotes as flat denormalized records (one row per quote)

Resource quote_pages
    # ── Resource: paginated quote listing ──────────────────────────────────────
    # Entry: https://quotes.toscrape.com/  (no auth required)
    # Three-rule tree: root (state gate) → pages (pagination) → items (extract)
    # Pagination: li.next a drives next-page clicks; stops naturally at page 10
    #             (li.next absent). Limit=3 pages → exactly 30 records expected.
    [Documentation]    Produces: quotes, quotes_flat
    [Setup]    Given I start resource "quote_pages" at "${ENTRY_URL}"
    And I set resource globals
    ...    timeout_ms=30000
    ...    retries=2
    ...    page_load_delay_ms=1000

    # Rule: root — state gate confirming we are on the right domain before acting
    And I begin rule "root"
    Given url matches "quotes.toscrape.com"
    And selector ".quote" exists

    # Rule: pages — drive next-button pagination across at most 3 pages
    # Evidence: li.next present on p1 (href=/page/2/), p2 (href=/page/3/);
    #           absent on p10 — engine stops naturally. Limit=3 caps at 30 records.
    And I begin rule "pages"
    And I declare parents "root"
    When I paginate by next button "li.next a" up to 3 pages

    # Rule: items — expand over each div.quote on every visited page, then extract
    # Evidence: exactly 10 div.quote elements per page (confirmed p1/2/3/10).
    # Extractors:
    #   quote_text — span.text (class="text"); includes surrounding typographic quotes
    #   author     — small.author (class="author"); always populated
    #   tags       — a.tag (class="tag"); grouped; 0–N tags per quote
    And I begin rule "items"
    And I declare parents "pages"
    When I expand over elements ".quote"
    Then I extract fields
    ...    field=quote_text    extractor=text       locator=".text"
    ...    field=author        extractor=text       locator="small.author"
    ...    field=tags          extractor=grouped    locator=".tag"
    And I emit to artifact "${ARTIFACT_QUOTES}"
    And I emit to artifact "${ARTIFACT_QUOTES_FLAT}"

Quality Gates
    # 3 pages × 10 quotes/page = 30 records minimum
    # quote_text and author are always populated (confirmed across all sample pages)
    # tags allow 80% fill — a small number of quotes have zero tags
    And I set quality gate min records to 30
    And I set filled percentage for "quote_text" to 100
    And I set filled percentage for "author" to 100
    And I set filled percentage for "tags" to 80
