*** Comments ***
Requirement    Scrape all books from the books.toscrape.com catalogue.
...            Collect title, price, star rating, and availability for each book.

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
