*** Comments ***
Requirement    Scrape quotes from quotes.toscrape.com. Produce a full dataset
...            (quote text, author, tags) and a second author-only view.

*** Settings ***
Documentation     Scrape quotes from quotes.toscrape.com and emit two artifacts:
...               quotes_full (all fields, no transform) and quotes_authors
...               (jmespath-projected to author only). Demonstrates field
...               projection / reshaping via the artifact query option.
Library           Browser
Library           WiseRpaBDD
Suite Setup       Given I start deployment "${DEPLOYMENT}"
Suite Teardown    Then I finalize deployment

*** Variables ***
${DEPLOYMENT}              quotes-jmespath
${ENTRY_URL}               https://quotes.toscrape.com/
${ARTIFACT_FULL}           quotes_full
${ARTIFACT_AUTHORS}        quotes_authors
${JMESPATH_AUTHORS}        [].{author: data.author}

*** Test Cases ***
Artifact Catalog
    # Full artifact — baseline with all extracted fields
    Given I register artifact "${ARTIFACT_FULL}"
    ...    field=quote_text    type=string    required=true
    ...    field=author        type=string    required=true
    ...    field=tags          type=array     required=true
    And I set artifact options for "${ARTIFACT_FULL}"
    ...    output=true
    ...    structure=flat
    ...    description=All quote fields (baseline, no jmespath)

    # Author-only artifact — jmespath projects just the author field
    Given I register artifact "${ARTIFACT_AUTHORS}"
    ...    field=author        type=string    required=true
    And I set artifact options for "${ARTIFACT_AUTHORS}"
    ...    output=true
    ...    structure=flat
    ...    query=${JMESPATH_AUTHORS}
    ...    description=Author names only via jmespath projection

Resource quote_pages
    [Documentation]    Produces: quotes_full, quotes_authors
    [Setup]    Given I start resource "quote_pages" at "${ENTRY_URL}"
    And I set resource globals
    ...    timeout_ms=30000
    ...    retries=2
    ...    page_load_delay_ms=1000

    # Rule: root — state gate
    I define rule "root"
        Given url matches "quotes.toscrape.com"
        And selector ".quote" exists

    # Rule: pages — paginate via next button, limit 3 pages
    I define rule "pages"
        And I declare parents "root"
        When I paginate by next button "li.next a" up to 3 pages

    # Rule: items — expand over each quote, extract, emit to both artifacts
    I define rule "items"
        And I declare parents "pages"
        When I expand over elements ".quote"
        Then I extract fields
        ...    field=quote_text    extractor=text       locator=".text"
        ...    field=author        extractor=text       locator="small.author"
        ...    field=tags          extractor=grouped    locator=".tag"
        And I emit to artifact "${ARTIFACT_FULL}"
        And I emit to artifact "${ARTIFACT_AUTHORS}"

Quality Gates
    # 3 pages x 10 quotes/page = 30 records minimum
    And I set quality gate min records to 30
    And I set filled percentage for "quote_text" to 100
    And I set filled percentage for "author" to 100
    And I set filled percentage for "tags" to 80
