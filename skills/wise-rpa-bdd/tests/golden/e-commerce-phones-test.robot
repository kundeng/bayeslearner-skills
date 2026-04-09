*** Comments ***
Requirement    Scrape all phone products from the webscraper.io test e-commerce site.
...            Collect title, price, description, and rating for each phone.

*** Settings ***
Documentation     Scrape phone products from webscraper.io test e-commerce site.
...               Extracts title, price, description, and rating for each phone.
...               Paginated across 2 pages (6 + 3 = 9 items).
...               Evidence: div.card.thumbnail containers; a.title[title] attr; h4.price span;
...               p.description text; p[data-rating] attr; a.page-link.next pagination.
...               No auth required.
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
    [Documentation]    Produces: phones (9 records: title, price, description, rating)
    [Setup]    Given I start resource "phone_listing" at "${ENTRY_URL}"
    And I set resource globals
    ...    timeout_ms=30000
    ...    retries=2

    # Rule: root — state gate + pagination across 2 pages
    And I begin rule "root"
    Given url contains "phones/touch"
    And selector "div.card.thumbnail" exists
    When I paginate by next button "a.page-link.next" up to 2 pages

    # Rule: items — expand over each product card, extract fields
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
    And I set quality gate min records to 9
    And I set filled percentage for "title" to 100
    And I set filled percentage for "price" to 100
    And I set filled percentage for "description" to 100
    And I set filled percentage for "rating" to 100
