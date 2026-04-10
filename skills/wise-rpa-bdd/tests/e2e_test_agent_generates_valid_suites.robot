*** Comments ***
E2E tests for the wise-rpa-bdd skill.

Each test case gives a natural language requirement to the AI agent,
then validates that the agent produces a valid .robot suite that passes
BDD validation, dryrun, and structurally matches the golden baseline.

*** Settings ***
Documentation     wise-rpa-bdd agent suite generation tests
Library           WiseRpaBDD.WiseRpaBDDTest    model=sonnet    max_turns=50
Test Timeout      10 minutes

*** Variables ***
${GOLDEN_DIR}         ${CURDIR}/golden
${GENERATED_DIR}      ${CURDIR}/generated

*** Test Cases ***
Quotes Scraping
    [Documentation]    Pagination via next button, text + grouped extraction
    ${path}=    Generate Suite From Requirement
    ...    Scrape all quotes from https://quotes.toscrape.com/ — extract quote text, author name, and tags for each quote.
    ...    ${GENERATED_DIR}/quotes-test.robot
    Generated Suite Should Pass BDD Validation
    Generated Suite Should Pass Dryrun
    Generated Suite Should Match Golden Baseline
    ...    ${GOLDEN_DIR}/quotes-test.robot

Revspin Table Scraping
    [Documentation]    Sort action, numeric pagination, table extraction
    ${path}=    Generate Suite From Requirement
    ...    Scrape table tennis rubber ratings from https://revspin.net/top-rubber/overall-desc.html — extract all rubber attributes sorted by durability.
    ...    ${GENERATED_DIR}/revspin-test.robot
    Generated Suite Should Pass BDD Validation
    Generated Suite Should Pass Dryrun
    Generated Suite Should Match Golden Baseline
    ...    ${GOLDEN_DIR}/revspin-test.robot

Laptop Paginated Scraping
    [Documentation]    Paginated element expansion with next button
    ${path}=    Generate Suite From Requirement
    ...    Scrape all laptops from the webscraper.io test e-commerce site. Collect title, price, description, and star rating for each laptop.
    ...    ${GENERATED_DIR}/laptop-paginated-test.robot
    Generated Suite Should Pass BDD Validation
    Generated Suite Should Pass Dryrun
    Generated Suite Should Match Golden Baseline
    ...    ${GOLDEN_DIR}/laptop-paginated-test.robot

Tables Extraction
    [Documentation]    HTML table extraction with header mapping
    ${path}=    Generate Suite From Requirement
    ...    Scrape all rows from the HTML tables on the webscraper.io tables test page. Collect row number, first name, last name, and username.
    ...    ${GENERATED_DIR}/tables-test.robot
    Generated Suite Should Pass BDD Validation
    Generated Suite Should Pass Dryrun
    Generated Suite Should Match Golden Baseline
    ...    ${GOLDEN_DIR}/tables-test.robot

Variants Click Expansion
    [Documentation]    Matrix/click expansion over product variants
    ${path}=    Generate Suite From Requirement
    ...    Scrape laptop variant pricing from the webscraper.io AJAX e-commerce site. For each laptop, get the price at every available HDD size option.
    ...    ${GENERATED_DIR}/variants-test.robot
    Generated Suite Should Pass BDD Validation
    Generated Suite Should Pass Dryrun
    Generated Suite Should Match Golden Baseline
    ...    ${GOLDEN_DIR}/variants-test.robot

Splunk ITSI With AI Extraction
    [Documentation]    Multi-section doc scraping + AI extraction
    ${path}=    Generate Suite From Requirement
    ...    Scrape Splunk ITSI documentation from help.splunk.com — extract page titles and body content from the Entity Integrations and Event Analytics manuals. Clean up body HTML with AI.
    ...    ${GENERATED_DIR}/splunk-itsi-focused-test.robot
    Generated Suite Should Pass BDD Validation
    Generated Suite Should Pass Dryrun
    Generated Suite Should Match Golden Baseline
    ...    ${GOLDEN_DIR}/splunk-itsi-focused-test.robot

Quotes With Login Auth
    [Documentation]    Auth test: login then scrape
    ${path}=    Generate Suite From Requirement
    ...    Log in to quotes.toscrape.com (username: admin, password: admin), then scrape quotes. Collect quote text, author, and tags.
    ...    ${GENERATED_DIR}/quotes-login-test.robot
    Generated Suite Should Pass BDD Validation
    Generated Suite Should Pass Dryrun
    Generated Suite Should Match Golden Baseline
    ...    ${GOLDEN_DIR}/quotes-login-test.robot
