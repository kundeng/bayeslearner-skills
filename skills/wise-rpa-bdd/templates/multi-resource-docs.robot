*** Settings ***
Documentation     Multi-resource discovery plus extraction flow
Library           WiseRpaBDD
Suite Setup       Given I start deployment "${DEPLOYMENT}"
Suite Teardown    Then I finalize deployment

*** Variables ***
${DEPLOYMENT}        docs-crawl
${DISCOVER_ENTRY}    https://example.com/docs
${ARTIFACT_URLS}     page_urls
${ARTIFACT_PAGES}    page_content

*** Test Cases ***
Artifact Catalog
    Given I register artifact "${ARTIFACT_URLS}"
    ...    field=url      type=url       required=true
    ...    field=label    type=string    required=true
    Given I register artifact "${ARTIFACT_PAGES}"
    ...    field=title    type=string    required=true
    ...    field=body     type=string    required=true
    And I set artifact options for "${ARTIFACT_PAGES}"
    ...    format=markdown
    ...    output=true

Discover Resource
    [Setup]    Given I start resource "discover" at "${DISCOVER_ENTRY}"
    Given selector "nav a" exists
    When I expand over elements "nav a" with order "bfs"
    Then I extract fields
    ...    field=url      extractor=link    locator="a"
    ...    field=label    extractor=text    locator="a"
    And I emit to artifact "${ARTIFACT_URLS}"

Extract Resource
    [Setup]    Given I start resource "extract"
    Given I consume artifact "${ARTIFACT_URLS}"
    When I open the bound field "url"
    Then I extract fields
    ...    field=title    extractor=text    locator="h1"
    ...    field=body     extractor=html    locator="article"
    And I emit to artifact "${ARTIFACT_PAGES}"
