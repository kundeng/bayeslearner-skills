*** Settings ***
Documentation     Generated from tests/profiles/practice/books-mystery-test.yaml
Library           WiseRpaBDD
Suite Setup       Given I start deployment "${DEPLOYMENT}"
Suite Teardown    Then I finalize deployment

*** Variables ***
${DEPLOYMENT}    books-mystery
${ARTIFACT_MYSTERY_BOOKS}    mystery_books
${ARTIFACT_MYSTERY_BOOKS_FLAT}    mystery_books_flat
${ARTIFACT_MYSTERY_BOOKS_QUERY_DOWN}    mystery_books_query_down
${ARTIFACT_MYSTERY_BOOKS_QUERY_UP}    mystery_books_query_up
${ENTRY_MYSTERY_CATALOG}    https://books.toscrape.com/catalogue/category/books/mystery_3/index.html

*** Test Cases ***
Artifact Catalog
    Given I register artifact "${ARTIFACT_MYSTERY_BOOKS}"
    ...    field=title    type=string    required=true
    ...    field=price    type=string    required=true
    ...    field=rating    type=string    required=true
    ...    field=availability    type=string    required=true
    And I set artifact options for "${ARTIFACT_MYSTERY_BOOKS}"
    ...    output=true
    ...    structure=nested
    ...    description=Mystery books as nested tree records
    Given I register artifact "${ARTIFACT_MYSTERY_BOOKS_FLAT}"
    ...    field=title    type=string    required=true
    ...    field=price    type=string    required=true
    ...    field=rating    type=string    required=true
    ...    field=availability    type=string    required=true
    And I set artifact options for "${ARTIFACT_MYSTERY_BOOKS_FLAT}"
    ...    output=true
    ...    structure=flat
    ...    description=Mystery books as flat denormalized records
    Given I register artifact "${ARTIFACT_MYSTERY_BOOKS_QUERY_DOWN}"
    ...    field=title    type=string    required=true
    ...    field=price    type=string    required=true
    And I set artifact options for "${ARTIFACT_MYSTERY_BOOKS_QUERY_DOWN}"
    ...    output=true
    ...    query=[].pages[].books[].{title: title, price: price, rating: rating}
    ...    description=Downward denormalization via JMESPath — flattens tree to book records
    Given I register artifact "${ARTIFACT_MYSTERY_BOOKS_QUERY_UP}"
    ...    field=title    type=string    required=true
    And I set artifact options for "${ARTIFACT_MYSTERY_BOOKS_QUERY_UP}"
    ...    output=true
    ...    query=[].pages[].{book_titles: books[].title, book_count: length(books)}
    ...    description=Upward aggregation via JMESPath — groups books by page

Resource mystery_catalog
    [Documentation]    Produces: ['mystery_books', 'mystery_books_flat', 'mystery_books_query_down', 'mystery_books_query_up']
    [Setup]    Given I start resource "mystery_catalog" at "${ENTRY_MYSTERY_CATALOG}"
    And I set resource globals
    ...    timeout_ms=30000
    ...    retries=2
    And I begin rule "root"
    Given url matches "mystery_3"
    And selector "article.product_pod" exists
    And I begin rule "pages"
    And I declare parents "root"
    When I paginate by next button "li.next a" up to 5 pages
    And I begin rule "books"
    And I declare parents "pages"
    When I expand over elements "article.product_pod"
    Then I extract fields
    ...    field=title    extractor=attr    locator="h3 a"    attr="title"
    ...    field=price    extractor=text    locator=".price_color"
    ...    field=rating    extractor=attr    locator="p.star-rating"    attr="class"
    ...    field=availability    extractor=text    locator=".instock.availability"
    And I emit to artifact "${ARTIFACT_MYSTERY_BOOKS}"
    And I emit to artifact "${ARTIFACT_MYSTERY_BOOKS_FLAT}"

Quality Gates
    And I set quality gate min records to 30
    And I set filled percentage for "title" to 95
    And I set filled percentage for "price" to 95
