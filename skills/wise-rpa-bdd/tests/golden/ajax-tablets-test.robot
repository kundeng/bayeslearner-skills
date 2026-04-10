*** Comments ***
Requirement    Scrape all tablets from the webscraper.io AJAX e-commerce test site.
...            Collect title, price, description, and rating for each tablet.

*** Settings ***
Documentation     Scrape tablet products from webscraper.io AJAX e-commerce test site.
...               Extracts title, price, description, and rating for each tablet
...               across 4 AJAX-paginated pages (21 total items, 6 per page, last page 3).
...               Pagination via numeric button controls (button.page-link.page) from 1 to 4.
...               Evidence: div.thumbnail containers; a.title[title] attr; h4.price text;
...               p.description text; p[data-rating] attr. No auth required.
Library           Browser
Library           WiseRpaBDD
Suite Setup       Given I start deployment "${DEPLOYMENT}"
Suite Teardown    Then I finalize deployment

*** Variables ***
${DEPLOYMENT}           tablets-ajax-webscraper
${ENTRY_URL}            https://www.webscraper.io/test-sites/e-commerce/ajax/computers/tablets
${ARTIFACT_TABLETS}     tablets

*** Test Cases ***
Artifact Catalog
    # One artifact: flat list of all tablet records (title, price, description, rating)
    Given I register artifact "${ARTIFACT_TABLETS}"
    ...    field=title          type=string    required=true
    ...    field=price          type=string    required=true
    ...    field=description    type=string    required=true
    ...    field=rating         type=string    required=true
    And I set artifact options for "${ARTIFACT_TABLETS}"
    ...    output=true
    ...    structure=flat
    ...    description=Tablet listings: title, price, description, rating (21 records expected)

Resource tablet_pages
    # -- Resource: AJAX-paginated tablet listing --------------------------------
    # Entry: https://www.webscraper.io/test-sites/e-commerce/ajax/computers/tablets
    # Three-rule tree: root (state gate) -> pages (numeric button pagination) -> items (extract)
    # AJAX pagination: button.page-link.page elements with data-id 1-4.
    # Numeric control clicks each page button in sequence; limit=4 pages.
    [Documentation]    Produces: tablets (21 records: title, price, description, rating)
    [Setup]    Given I start resource "tablet_pages" at "${ENTRY_URL}"
    And I set resource globals
    ...    timeout_ms=30000
    ...    retries=2
    ...    page_load_delay_ms=2000

    # Rule: root -- state gate confirming we are on the tablets listing
    # Evidence: URL contains "computers/tablets"; div.thumbnail present on every page
    I define rule "root"
        Given url contains "computers/tablets"
        And selector "div.thumbnail" exists

    # Rule: pages -- drive numeric button pagination across all 4 pages
    # Evidence: button.page-link.page elements (data-id 1-4); AJAX content loads on click.
    # page_load_delay_ms=2000 accounts for AJAX content loading after each page click.
    I define rule "pages"
        And I declare parents "root"
        When I paginate by numeric control "button.page-link.page" from 1 up to 4 pages

    # Rule: items -- expand over each div.thumbnail on every visited page, then extract
    # Evidence: 6 div.thumbnail per page (pages 1-3); 3 on page 4 -> 21 total.
    # Extractors:
    #   title       -- a.title, attr=title  (full name in title attribute)
    #   price       -- h4.price, text       (includes $ sign; e.g. "$69.99")
    #   description -- p.description, text  (specs string)
    #   rating      -- p[data-rating], attr=data-rating  (numeric 1-5)
    I define rule "items"
        And I declare parents "pages"
        When I expand over elements "div.thumbnail"
        Then I extract fields
        ...    field=title          extractor=attr    locator=a.title             attr=title
        ...    field=price          extractor=text    locator=h4.price
        ...    field=description    extractor=text    locator=p.description
        ...    field=rating         extractor=attr    locator=p[data-rating]      attr=data-rating
        And I emit to artifact "${ARTIFACT_TABLETS}"

Quality Gates
    # 4 pages x 6 items/page - 3 missing on last page = 21 total records
    # All fields confirmed present on every card across the site
    And I set quality gate min records to 21
    And I set filled percentage for "title" to 100
    And I set filled percentage for "price" to 100
    And I set filled percentage for "description" to 100
    And I set filled percentage for "rating" to 100
