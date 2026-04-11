*** Comments ***
Requirement    Scrape The Book of OHDSI from ohdsi.github.io/TheBookOfOhdsi/
...            as cleaned markdown. Discover chapter URLs from the TOC sidebar,
...            then extract title and body from each page.

*** Settings ***
Documentation     Full Book of OHDSI extraction: 27 chapter pages to markdown.
...               Discovery: unique page URLs from .book-summary li.chapter a
...               (437 TOC links → 27 unique pages after dedup on base URL).
...               Detail: title from .page-inner section h1, body from
...               .page-inner section. Body converted HTML→markdown via
...               to_markdown hook, then AI cleanup to remove nav boilerplate.
...               Evidence: GitBook layout; .page-inner section contains chapter;
...               h1 has "Chapter N Title" format; ~29K HTML per page.
Library           Browser
Library           WiseRpaBDD
Suite Setup       Given I start deployment "${DEPLOYMENT}"
Suite Teardown    Then I finalize deployment

*** Variables ***
${DEPLOYMENT}           ohdsi-book
${ENTRY_URL}            https://ohdsi.github.io/TheBookOfOhdsi/
${ARTIFACT_URLS}        chapter_urls
${ARTIFACT_BOOK}        book_pages
${AI_PROMPT}            Clean up this markdown from The Book of OHDSI. Remove navigation elements (sidebar links, page navigation arrows, "GitBook" branding), table of contents duplicates, and footer boilerplate. Preserve all chapter content: headings, paragraphs, lists, tables, code blocks, figure captions, and references. Do not summarize — keep full content. Output clean markdown only.

*** Test Cases ***
Artifact Catalog
    Given I register artifact "${ARTIFACT_URLS}"
    ...    field=page_url    type=url    required=true
    And I set artifact options for "${ARTIFACT_URLS}"
    ...    output=false
    ...    dedupe=page_url
    ...    description=Unique chapter page URLs from TOC sidebar

    Given I register artifact "${ARTIFACT_BOOK}"
    ...    field=title    type=string    required=true
    ...    field=url      type=url       required=true
    ...    field=body     type=string    required=true
    And I set artifact options for "${ARTIFACT_BOOK}"
    ...    output=true
    ...    format=markdown
    ...    structure=flat
    ...    description=The Book of OHDSI — full chapter content as cleaned markdown

Hook Setup
    And I register hook "html_to_md" at "post_extract"
    ...    to_markdown=body

Discover Chapter URLs
    [Documentation]    Produces: chapter_urls (27 unique chapter page URLs)
    [Setup]    Given I start resource "discover" at "${ENTRY_URL}"
    And I set resource globals
    ...    timeout_ms=20000
    ...    retries=2
    ...    page_load_delay_ms=2000
    I define rule "root"
        Given url contains "TheBookOfOhdsi"
        And selector ".summary > li.chapter > a" exists
    I define rule "toc"
        And I declare parents "root"
        # Direct children only — avoids sub-section anchor duplicates (437 → 27)
        When I expand over elements ".summary > li.chapter > a" with order "bfs"
        Then I extract fields
        ...    field=page_url    extractor=link    locator="."
        And I emit to artifact "${ARTIFACT_URLS}"

Extract Chapter Pages
    [Documentation]    Produces: book_pages (title + body as cleaned markdown)
    [Setup]    Given I start resource "extract" at "{page_url}"
    Given I consume artifact "${ARTIFACT_URLS}"
    And I set resource globals
    ...    timeout_ms=30000
    ...    retries=2
    ...    page_load_delay_ms=2000
    And I set AI adapter "aichat"
    I define rule "page"
        And selector ".page-inner section" exists
        Then I extract fields
        ...    field=title    extractor=text    locator=".page-inner section h1"
        ...    field=url      extractor=url     locator="."
        ...    field=body     extractor=html    locator=".page-inner section"
        Then I extract with AI "body"
        ...    input=body
        ...    mode=cleanup
        ...    output=markdown
        ...    max_size=120000
        ...    chunk_size=50000
        ...    prompt=${AI_PROMPT}
        And I emit to artifact "${ARTIFACT_BOOK}"

Quality Gates
    And I set quality gate min records to 20
    And I set filled percentage for "title" to 95
    And I set filled percentage for "body" to 90
