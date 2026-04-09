*** Comments ***
Requirement    Scrape the heading and main content from the Cookiebot test page.

*** Settings ***
Documentation     Interrupt dismiss test: auto-dismiss Cookiebot cookie consent banner,
...               then scrape page heading and content. Exercises: configure interrupts.
Library           Browser
Library           WiseRpaBDD
Suite Setup       Given I start deployment "${DEPLOYMENT}"
Suite Teardown    Then I finalize deployment

*** Variables ***
${DEPLOYMENT}           cookiebot-consent-page
${ENTRY_URL}            https://www.cookiebot.com/en/cookie-consent/
${ARTIFACT_CONTENT}     page_content

*** Test Cases ***
Artifact Catalog
    Given I register artifact "${ARTIFACT_CONTENT}"
    ...    field=heading    type=string    required=true
    ...    field=content    type=string    required=true
    And I set artifact options for "${ARTIFACT_CONTENT}"
    ...    output=true

Interrupt Setup
    [Documentation]    Dismiss Cookiebot cookie consent banner
    And I configure interrupts
    ...    dismiss="#CybotCookiebotDialogBodyLevelButtonLevelOptinAllowAll"

Resource page_scrape
    [Documentation]    Produces: page_content
    [Setup]    Given I start resource "page" at "${ENTRY_URL}"
    And I set resource globals
    ...    timeout_ms=15000
    ...    page_load_delay_ms=2000
    And I begin rule "root"
    Given url contains "/cookie-consent"
    And selector "h1" exists
    Then I extract fields
    ...    field=heading    extractor=text    locator="h1"
    ...    field=content    extractor=text    locator="main"
    And I emit to artifact "${ARTIFACT_CONTENT}"

Quality Gates
    And I set quality gate min records to 1
    And I set filled percentage for "heading" to 100
