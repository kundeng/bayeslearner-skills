*** Comments ***
Requirement    Scrape all books from https://books.toscrape.com/catalogue/page-1.html
...            Extract title, price, star rating, and availability across 50 paginated pages.
...            Site has 50 pages with 20 books each (1000 total). Pagination via next button.
Expected       title,price,star_rating,availability
Min Records    1000

# ── Evidence (books.toscrape.com DOM analysis) ────────────────────────────────
#
# Fetched: https://books.toscrape.com/catalogue/page-1.html
#          (50 pages confirmed; "Page 1 of 50" shown in pager)
#
# Product card     : article.product_pod   — 20 per page
#                    <article class="product_pod"> wraps each book listing.
#
# Title            : h3 > a               — selector: h3 a, attr=title
#                    <h3><a href="..." title="A Light in the Attic">A Light in the ...</a></h3>
#                    Full title is in the `title` attribute (display text is truncated).
#                    Sample: "A Light in the Attic", "Tipping the Velvet", "Soumission"
#
# Price            : p.price_color        — selector: p.price_color, extractor=text
#                    <p class="price_color">£51.77</p>
#                    Always present; includes currency symbol. Sample: "£51.77", "£53.74"
#
# Star rating      : p.star-rating        — selector: p.star-rating, attr=class
#                    <p class="star-rating Three"> (One|Two|Three|Four|Five)
#                    Rating encoded as word in class attribute alongside "star-rating".
#                    Sample class values: "star-rating Three", "star-rating One"
#
# Availability     : p.instock.availability — selector: p.availability, extractor=text
#                    <p class="instock availability"><i class="icon-ok"></i> In stock</p>
#                    Text content "In stock" (with leading whitespace trimmed by extractor).
#
# Next button      : li.next > a          — selector: li.next a
#                    <li class="next"><a href="page-2.html">next</a></li>
#                    Present on pages 1-49; ABSENT on page 50 → engine stops naturally.
#
# Auth / cookies   : none — no login prompt, no cookie consent banner observed.
#
# ───────────────────────────────────────────────────────────────────────────────

*** Settings ***
Documentation     Scrape all books from books.toscrape.com catalogue.
...               Extracts title, price, star rating, and availability for each book
...               across 50 paginated pages (1000 total items, 20 per page).
...               Pagination: li.next a stops naturally when absent on page 50.
...               Evidence: article.product_pod containers; h3 a[title] attr; p.price_color;
...               p.star-rating class attr; p.availability text. No auth required.
Library           Browser
Library           WiseRpaBDD
Suite Setup       Given I start deployment "${DEPLOYMENT}"
Suite Teardown    Then I finalize deployment

*** Variables ***
${DEPLOYMENT}           books-catalogue
${ENTRY_URL}            https://books.toscrape.com/catalogue/page-1.html
${ARTIFACT_BOOKS}       books

*** Test Cases ***
Artifact Catalog
    # One artifact: flat list of all book records (title, price, star_rating, availability)
    # structure=flat → one denormalized row per book, ready for CSV/JSONL export
    Given I register artifact "${ARTIFACT_BOOKS}"
    ...    field=title          type=string    required=true
    ...    field=price          type=string    required=true
    ...    field=star_rating    type=string    required=true
    ...    field=availability   type=string    required=true
    And I set artifact options for "${ARTIFACT_BOOKS}"
    ...    output=true
    ...    structure=flat
    ...    description=Book listings: title, price, star rating, availability (1000 records expected)

Resource book_pages
    # ── Resource: paginated book listing ──────────────────────────────────────
    # Entry: https://books.toscrape.com/catalogue/page-1.html
    # Three-rule tree: root (state gate) → pages (next-button pagination) → items (extract)
    # Pagination: li.next a present on pages 1-49; absent on page 50 → natural stop.
    # Limit=50 caps at page 50 (matches total page count confirmed from DOM).
    [Documentation]    Produces: books (1000 records: title, price, star_rating, availability)
    [Setup]    Given I start resource "book_pages" at "${ENTRY_URL}"
    And I set resource globals
    ...    timeout_ms=30000
    ...    retries=2
    ...    page_load_delay_ms=1000

    # Rule: root — state gate confirming we are on the catalogue listing before acting
    # Evidence: URL contains "catalogue"; article.product_pod present on every page
    And I begin rule "root"
    Given url contains "catalogue"
    And selector "article.product_pod" exists

    # Rule: pages — drive next-button pagination across all 50 pages
    # Evidence: li.next a present on pages 1-49 (href=page-N.html);
    #           absent on page 50 — engine stops naturally without sentinel needed.
    #           Limit=50 matches the confirmed total page count.
    And I begin rule "pages"
    And I declare parents "root"
    When I paginate by next button "li.next a" up to 50 pages

    # Rule: items — expand over each article.product_pod on every visited page, then extract
    # Evidence: exactly 20 article.product_pod per page → 50 × 20 = 1000 total.
    # Extractors:
    #   title        — h3 a, attr=title  (full title in title attribute; display text truncated)
    #   price        — p.price_color, text  (includes £ symbol; e.g. "£51.77")
    #   star_rating  — p.star-rating, attr=class  (e.g. "star-rating Three"; word encodes rating)
    #   availability — p.availability, text  (e.g. "In stock"; whitespace trimmed by extractor)
    And I begin rule "items"
    And I declare parents "pages"
    When I expand over elements "article.product_pod"
    Then I extract fields
    ...    field=title          extractor=attr    locator=h3 a              attr=title
    ...    field=price          extractor=text    locator=p.price_color
    ...    field=star_rating    extractor=attr    locator=p.star-rating     attr=class
    ...    field=availability   extractor=text    locator=p.availability
    And I emit to artifact "${ARTIFACT_BOOKS}"

Quality Gates
    # 50 pages × 20 items/page = 1000 total records
    # title, price, star_rating, availability — all confirmed present on every card sampled
    And I set quality gate min records to 1000
    And I set filled percentage for "title" to 100
    And I set filled percentage for "price" to 100
    And I set filled percentage for "star_rating" to 100
    And I set filled percentage for "availability" to 100
