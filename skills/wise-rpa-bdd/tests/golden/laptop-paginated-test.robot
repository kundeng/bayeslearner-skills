*** Comments ***
Requirement    Scrape all laptops from https://www.webscraper.io/test-sites/e-commerce/static/computers/laptops
...            Paginated site with a next button. Extract: title, price, description, rating.
Expected       title,price,description,rating
Min Records    117

# ── Evidence (live DOM — /rrpa-explore session) ────────────────────────────────
#
# Fetched: https://www.webscraper.io/test-sites/e-commerce/static/computers/laptops
#          (pages 1, 2, 19, 20 confirmed via curl -sL)
#
# Item count label : p.item-count         — "117 items" on page 1
# Total pages      : 20 (links 1-20 visible in ul.pagination; confirmed page 20 has 3 cards)
# Items per page   : 6 (pages 1-19), 3 (page 20)  →  117 total
#
# Product card     : div.card.thumbnail   — 6 per page
#                    <div class="card thumbnail" itemscope ...>
#
# Title            : a.title              — selector: a.title, attr=title
#                    <a href="..." class="title" title="Packard 255 G2" itemprop="name">
#                    Full name is in the `title` attribute (not truncated).
#                    Text content has surrounding whitespace; `title` attr is clean.
#                    Sample: "Packard 255 G2", "Aspire E1-510", "ThinkPad T540p"
#
# Price            : h4.price span        — selector: h4.price span, extractor=text
#                    <h4 class="price float-end card-title pull-right" itemprop="offers" ...>
#                      <span itemprop="price">$416.99</span>
#                    Sample: "$416.99", "$306.99", "$1178.99"
#
# Description      : p.description       — selector: p.description, extractor=text
#                    <p class="description card-text" itemprop="description">
#                      15.6&quot;, AMD E2-3800 1.3GHz, 4GB, 500GB, Windows 8.1
#                    Always present; contains specs string. HTML entity &quot; decoded by browser.
#
# Rating           : p[data-rating]      — selector: p[data-rating], attr=data-rating
#                    <p data-rating="2"> (inside div.ratings)
#                    Numeric value 1–5 stored in data-rating attribute.
#                    Star spans (span.ws-icon.ws-icon-star) count equals data-rating.
#                    All 6 cards on page 1 have data-rating present (values: 2,3,1,4,3,1).
#
# Next button      : a.page-link.next    — selector: a.page-link.next
#                    <a class="page-link next" href="...?page=2" rel="next">
#                    Present on pages 1-19; ABSENT on page 20 → engine stops naturally.
#                    Previous-only page-item present on p20 — no next class.
#
# Auth / cookies   : none — no login prompt, no cookie consent banner observed.
#
# ───────────────────────────────────────────────────────────────────────────────

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
    And I begin rule "root"
    Given url contains "computers/laptops"
    And selector "div.card.thumbnail" exists

    # Rule: pages — drive next-button pagination across all 20 pages
    # Evidence: a.page-link.next present on pages 1-19 (href=?page=N, rel="next");
    #           absent on page 20 — engine stops naturally without sentinel needed.
    #           Limit=20 matches the confirmed total page count.
    And I begin rule "pages"
    And I declare parents "root"
    When I paginate by next button "a.page-link.next" up to 20 pages

    # Rule: items — expand over each div.card.thumbnail on every visited page, then extract
    # Evidence: exactly 6 div.card.thumbnail per page (pages 1-19); 3 on page 20 → 117 total.
    # Extractors:
    #   title       — a.title, attr=title  (full name in title attribute; no whitespace noise)
    #   price       — h4.price span, text  (includes $ sign; e.g. "$416.99")
    #   description — p.description, text  (specs string; browser decodes &quot; entities)
    #   rating      — p[data-rating], attr=data-rating  (numeric 1-5; always present)
    And I begin rule "items"
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
