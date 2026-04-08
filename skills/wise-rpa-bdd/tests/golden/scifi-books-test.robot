*** Comments ***
Requirement    Scrape sci-fi books from https://books.toscrape.com/catalogue/category/books/science-fiction_16/index.html
...            Two-resource chaining pattern: discover book URLs from the category page,
...            then for each book open the detail page and extract title, price, description,
...            UPC, availability, and number of reviews.
Expected       title,price,description,upc,availability,num_reviews
Min Records    16

# -- Evidence (books.toscrape.com DOM analysis) -----------------------------------------------
#
# Category page: https://books.toscrape.com/catalogue/category/books/science-fiction_16/index.html
#   "16 results" shown; single page (no pagination control observed).
#
# Book card        : article.product_pod          -- one per book on category listing
#   Link to detail : h3 > a                       -- href is relative detail URL
#                    <h3><a href="../../../mesaerion-the-best-..._983/index.html"
#                           title="Mesaerion: ...">Mesaerion: The Best Science ...</a></h3>
#
# Detail page (e.g. /catalogue/mesaerion-the-best-science-fiction-stories-1800-1849_983/index.html):
#   Title          : .product_main h1             -- full title text
#                    <h1>Mesaerion: The Best Science Fiction Stories 1800-1849</h1>
#   Price          : .product_main p.price_color  -- e.g. "£37.59"
#   Description    : #product_description ~ p     -- paragraph immediately after description header
#   Info table     : table.table-striped           -- key-value rows with <th> and <td>
#     UPC          : th="UPC"                      -- e.g. "e30f54cea9b38190"
#     Availability : th="Availability"             -- e.g. "In stock (19 available)"
#     Num reviews  : th="Number of reviews"        -- e.g. "0"
#
# Auth / cookies   : none required
#
# -------------------------------------------------------------------------------------------------

*** Settings ***
Documentation     Scrape sci-fi books using two-resource chaining.
...               Resource 1 (discover): visit the Science Fiction category page, expand over
...               each book card (article.product_pod), extract the detail link.
...               Resource 2 (detail): consume discovered URLs, open each detail page, extract
...               title, price, description, UPC, availability, and number of reviews via table.
...               Evidence: 16 books on one category page; detail pages share a consistent layout
...               with .product_main for title/price and table.table-striped for metadata.
Library           Browser
Library           WiseRpaBDD
Suite Setup       Given I start deployment "${DEPLOYMENT}"
Suite Teardown    Then I finalize deployment

*** Variables ***
${DEPLOYMENT}           scifi-books
${ENTRY_URL}            https://books.toscrape.com/catalogue/category/books/science-fiction_16/index.html
${ARTIFACT_URLS}        book_urls
${ARTIFACT_BOOKS}       books

*** Test Cases ***
Artifact Catalog
    # Intermediate artifact: holds discovered book detail URLs
    Given I register artifact "${ARTIFACT_URLS}"
    ...    field=detail_url    type=url    required=true
    And I set artifact options for "${ARTIFACT_URLS}"
    ...    output=false
    ...    description=Intermediate: detail page URLs discovered from the category listing

    # Final artifact: one record per book with all extracted fields
    Given I register artifact "${ARTIFACT_BOOKS}"
    ...    field=title          type=string    required=true
    ...    field=price          type=string    required=true
    ...    field=description    type=string    required=false
    ...    field=upc            type=string    required=true
    ...    field=availability   type=string    required=true
    ...    field=num_reviews    type=string    required=false
    And I set artifact options for "${ARTIFACT_BOOKS}"
    ...    output=true
    ...    structure=flat
    ...    consumes=book_urls
    ...    description=Sci-fi book details: title, price, description, UPC, availability, reviews

Discovery Resource
    # -- Resource 1: category listing page -------------------------------------------------
    # Expand over each article.product_pod, extract the detail link from h3 a.
    # Evidence: 16 article.product_pod elements on a single category page; no pagination needed.
    [Documentation]    Produces: book_urls (16 detail page URLs)
    [Setup]    Given I start resource "discover" at "${ENTRY_URL}"
    And I set resource globals
    ...    timeout_ms=30000
    ...    retries=2
    ...    page_load_delay_ms=1000

    And I begin rule "root"
    Given url contains "science-fiction"
    And selector "article.product_pod" exists

    And I begin rule "cards"
    And I declare parents "root"
    When I expand over elements "article.product_pod"
    Then I extract fields
    ...    field=detail_url    extractor=link    locator=h3 a
    And I emit to artifact "${ARTIFACT_URLS}"

Detail Resource
    # -- Resource 2: individual book detail pages ------------------------------------------
    # Consumes book_urls artifact; opens each detail_url; extracts fields.
    # Evidence: .product_main h1 = title; .product_main p.price_color = price;
    #           #product_description ~ p = description; table.table-striped for UPC,
    #           Availability, Number of reviews (key-value rows via table extraction).
    [Documentation]    Produces: books (16 records with title, price, description, upc, availability, num_reviews)
    [Setup]    Given I start resource "detail" at "{detail_url}"
    And I set resource globals
    ...    timeout_ms=30000
    ...    retries=2
    ...    page_load_delay_ms=1500
    And I begin rule "page"
    And selector ".product_main" exists
    Then I extract fields
    ...    field=title          extractor=text    locator=.product_main h1
    ...    field=price          extractor=text    locator=.product_main p.price_color
    ...    field=description    extractor=text    locator=#product_description ~ p

    Then I extract table "product_info" from "table.table-striped"
    ...    field=upc            header=UPC
    ...    field=availability   header=Availability
    ...    field=num_reviews    header=Number of reviews

    And I emit to artifact "${ARTIFACT_BOOKS}"

Quality Gates
    And I set quality gate min records to 16
    And I set filled percentage for "title" to 100
    And I set filled percentage for "price" to 100
    And I set filled percentage for "upc" to 100
    And I set filled percentage for "availability" to 100
