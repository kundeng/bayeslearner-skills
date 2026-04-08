*** Comments ***
Requirement    Scrape phone products from webscraper.io test e-commerce site.
...            Extract title, price, description, and rating from product cards.
...            Single page, no pagination needed.
Expected       title,price,description,rating
Min Records    9

# ── Evidence (live DOM — agent-browser session) ──────────────────────────────
#
# Fetched: https://www.webscraper.io/test-sites/e-commerce/static/phones/touch
#          (Note: /computers/phones shows 0 items; /phones/touch has 9 phone products)
#
# Item count label : p.item-count         — "9 items"
# Total pages      : 1 (no pagination controls present)
# Items per page   : 9  →  9 total
#
# Product card     : div.card.thumbnail   — 9 on the page
#                    <div class="card thumbnail" itemscope itemtype="https://schema.org/Product">
#
# Title            : a.title              — selector: a.title, attr=title
#                    <a href="..." class="title" title="Nokia 123" itemprop="name">
#                    Full name is in the `title` attribute (clean, no whitespace noise).
#                    Sample: "Nokia 123", "LG Optimus", "Samsung Galaxy"
#
# Price            : h4.price span        — selector: h4.price span, extractor=text
#                    <h4 class="price float-end card-title pull-right" itemprop="offers" ...>
#                      <span itemprop="price">$24.99</span>
#                    Sample: "$24.99", "$57.99", "$93.99"
#
# Description      : p.description       — selector: p.description, extractor=text
#                    <p class="description card-text" itemprop="description">
#                      7 day battery
#                    Always present; short specs string.
#
# Rating           : p[data-rating]      — selector: p[data-rating], attr=data-rating
#                    <p data-rating="3"> (inside div.ratings)
#                    Numeric value 1–5 stored in data-rating attribute.
#                    Star spans count equals data-rating value.
#
# Auth / cookies   : none — no login prompt, no cookie consent banner observed.
#
# ─────────────────────────────────────────────────────────────────────────────

*** Settings ***
Documentation     Scrape phone products from webscraper.io test e-commerce site.
...               Extracts title, price, description, and rating for each phone
...               on a single page (9 items, no pagination).
...               Evidence: div.card.thumbnail containers; a.title[title] attr; h4.price span;
...               p.description text; p[data-rating] attr. No auth required.
Library           Browser
Library           WiseRpaBDD
Suite Setup       Given I start deployment "${DEPLOYMENT}"
Suite Teardown    Then I finalize deployment

*** Variables ***
${DEPLOYMENT}          phones-webscraper
${ENTRY_URL}           https://www.webscraper.io/test-sites/e-commerce/static/phones/touch
${ARTIFACT_PHONES}     phones

*** Test Cases ***
Artifact Catalog
    # One artifact: flat list of all phone records (title, price, description, rating)
    Given I register artifact "${ARTIFACT_PHONES}"
    ...    field=title          type=string    required=true
    ...    field=price          type=string    required=true
    ...    field=description    type=string    required=true
    ...    field=rating         type=string    required=true
    And I set artifact options for "${ARTIFACT_PHONES}"
    ...    output=true
    ...    structure=flat
    ...    description=Phone listings: title, price, description, rating (9 records expected)

Resource phone_listing
    # ── Resource: single-page phone listing ──────────────────────────────────
    # Entry: https://www.webscraper.io/test-sites/e-commerce/static/phones/touch
    # Two-rule tree: root (state gate) → items (expand + extract)
    # No pagination — all 9 items on a single page.
    [Documentation]    Produces: phones (9 records: title, price, description, rating)
    [Setup]    Given I start resource "phone_listing" at "${ENTRY_URL}"
    And I set resource globals
    ...    timeout_ms=30000
    ...    retries=2

    # Rule: root — state gate confirming we are on the phones listing
    # Evidence: URL contains "phones/touch"; div.card.thumbnail present
    And I begin rule "root"
    Given url contains "phones/touch"
    And selector "div.card.thumbnail" exists

    # Rule: items — expand over each div.card.thumbnail, then extract fields
    # Evidence: 9 div.card.thumbnail on the page.
    # Extractors:
    #   title       — a.title, attr=title  (full name in title attribute; clean text)
    #   price       — h4.price span, text  (includes $ sign; e.g. "$24.99")
    #   description — p.description, text  (short specs string; always present)
    #   rating      — p[data-rating], attr=data-rating  (numeric 1-5; always present)
    And I begin rule "items"
    And I declare parents "root"
    When I expand over elements "div.card.thumbnail"
    Then I extract fields
    ...    field=title          extractor=attr    locator=a.title             attr=title
    ...    field=price          extractor=text    locator=h4.price span
    ...    field=description    extractor=text    locator=p.description
    ...    field=rating         extractor=attr    locator=p[data-rating]      attr=data-rating
    And I emit to artifact "${ARTIFACT_PHONES}"

Quality Gates
    # 9 items on a single page — all fields confirmed present on every card
    And I set quality gate min records to 9
    And I set filled percentage for "title" to 100
    And I set filled percentage for "price" to 100
    And I set filled percentage for "description" to 100
    And I set filled percentage for "rating" to 100
