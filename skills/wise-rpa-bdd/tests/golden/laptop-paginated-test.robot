*** Comments ***
Requirement    Scrape all laptops from the webscraper.io test e-commerce site.
...            Collect title, price, description, and star rating for each laptop.

*** Settings ***
Documentation     Scrape all laptops from webscraper.io test e-commerce site.
...               Extracts title, price, description, and rating for each laptop
...               across 20 paginated pages (117 total items, 6 per page, last page 3).
...               Pagination: a.page-link.next stops naturally when absent on page 20.
...               Evidence: div.card.thumbnail containers; a.title[title] attr; h4.price span;
...               p.description text; p[data-rating] attr. No auth required.
Library           Browser
Library           WiseRpaBDD
Suite Setup       Given I start deployment "${DEPLOYMENT}"
Suite Teardown    Then I finalize deployment

*** Variables ***
${DEPLOYMENT}           laptops-webscraper
${ENTRY_URL}            https://www.webscraper.io/test-sites/e-commerce/static/computers/laptops
${ARTIFACT_LAPTOPS}     laptops

*** Test Cases ***
Artifact Catalog
    # One artifact: flat list of all laptop records (title, price, description, rating)
    # structure=flat → one denormalized row per laptop, ready for CSV/JSONL export
    Given I register artifact "${ARTIFACT_LAPTOPS}"
    ...    field=title          type=string    required=true
    ...    field=price          type=string    required=true
    ...    field=description    type=string    required=true
    ...    field=rating         type=string    required=true
    And I set artifact options for "${ARTIFACT_LAPTOPS}"
    ...    output=true
    ...    structure=flat
    ...    description=Laptop listings: title, price, description, rating (117 records expected)

Resource laptop_pages
    # ── Resource: paginated laptop listing ────────────────────────────────────
    # Entry: https://www.webscraper.io/test-sites/e-commerce/static/computers/laptops
    # Three-rule tree: root (state gate) → pages (next-button pagination) → items (extract)
    # Pagination: a.page-link.next present on pages 1–19; absent on page 20 → natural stop.
    # Limit=20 caps at page 20 (matches total page count confirmed from DOM).
    [Documentation]    Produces: laptops (117 records: title, price, description, rating)
    [Setup]    Given I start resource "laptop_pages" at "${ENTRY_URL}"
    And I set resource globals
    ...    timeout_ms=30000
    ...    retries=2
    ...    page_load_delay_ms=1000

    # Rule: root — state gate confirming we are on the laptops listing before acting
    # Evidence: URL contains "computers/laptops"; div.card.thumbnail present on every page
    I define rule "root"
        Given url contains "computers/laptops"
        And selector "div.card.thumbnail" exists

    # Rule: pages — drive next-button pagination across all 20 pages
    # Evidence: a.page-link.next present on pages 1-19 (href=?page=N, rel="next");
    #           absent on page 20 — engine stops naturally without sentinel needed.
    #           Limit=20 matches the confirmed total page count.
    I define rule "pages"
        And I declare parents "root"
        When I paginate by next button "a.page-link.next" up to 20 pages

    # Rule: items — expand over each div.card.thumbnail on every visited page, then extract
    # Evidence: exactly 6 div.card.thumbnail per page (pages 1-19); 3 on page 20 → 117 total.
    # Extractors:
    #   title       — a.title, attr=title  (full name in title attribute; no whitespace noise)
    #   price       — h4.price span, text  (includes $ sign; e.g. "$416.99")
    #   description — p.description, text  (specs string; browser decodes &quot; entities)
    #   rating      — p[data-rating], attr=data-rating  (numeric 1-5; always present)
    I define rule "items"
        And I declare parents "pages"
        When I expand over elements "div.card.thumbnail"
        Then I extract fields
        ...    field=title          extractor=attr    locator=a.title             attr=title
        ...    field=price          extractor=text    locator=h4.price span
        ...    field=description    extractor=text    locator=p.description
        ...    field=rating         extractor=attr    locator=p[data-rating]      attr=data-rating
        And I emit to artifact "${ARTIFACT_LAPTOPS}"

Quality Gates
    # 20 pages × 6 items/page − 3 missing on last page = 117 total records
    # title, price, description, rating — all confirmed present on every card sampled
    And I set quality gate min records to 117
    And I set filled percentage for "title" to 100
    And I set filled percentage for "price" to 100
    And I set filled percentage for "description" to 100
    And I set filled percentage for "rating" to 100
