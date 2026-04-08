*** Comments ***
E2E tests for the wise-rpa-bdd skill.

Each test case gives a natural language requirement to the AI agent
(via Claude Agent SDK), then validates that the agent produces a valid
.robot suite that passes BDD validation and dryrun, and structurally
matches the vetted golden baseline.

*** Settings ***
Documentation     wise-rpa-bdd agent suite generation tests
Library           AgentRunner    model=sonnet    max_turns=50
Test Timeout      5 minutes

*** Variables ***
${GOLDEN_DIR}         ${CURDIR}/golden
${GENERATED_DIR}      ${CURDIR}/generated

*** Test Cases ***
Quotes Scraping
    [Documentation]    Pagination via next button, text + grouped extraction
    ${path}=    Generate Suite From Requirement
    ...    Scrape all quotes from https://quotes.toscrape.com/ — extract quote text, author name, and tags for each quote. The site has pagination (next button). Collect at least 3 pages.
    ...    ${GENERATED_DIR}/quotes-test.robot
    Generated Suite Should Pass BDD Validation
    Generated Suite Should Pass Dryrun
    Generated Suite Should Match Golden Baseline
    ...    ${GOLDEN_DIR}/quotes-test.robot

Revspin Table Scraping
    [Documentation]    Sort action, numeric pagination, table extraction
    ${path}=    Generate Suite From Requirement
    ...    Scrape table tennis rubber ratings from https://revspin.net/top-rubber/overall-desc.html — click durability sort, then extract all rubber attributes (rank, name, speed, spin, control, durability, overall, price) from 2 pages of results.
    ...    ${GENERATED_DIR}/revspin-test.robot
    Generated Suite Should Pass BDD Validation
    Generated Suite Should Pass Dryrun
    Generated Suite Should Match Golden Baseline
    ...    ${GOLDEN_DIR}/revspin-test.robot

Laptop Paginated Scraping
    [Documentation]    Paginated element expansion with next button
    ${path}=    Generate Suite From Requirement
    ...    Scrape all laptops from https://www.webscraper.io/test-sites/e-commerce/static/computers/laptops — paginated site with next button, extract title, price, description, and rating.
    ...    ${GENERATED_DIR}/laptop-paginated-test.robot
    Generated Suite Should Pass BDD Validation
    Generated Suite Should Pass Dryrun
    Generated Suite Should Match Golden Baseline
    ...    ${GOLDEN_DIR}/laptop-paginated-test.robot

Tables Extraction
    [Documentation]    HTML table extraction with header mapping
    ${path}=    Generate Suite From Requirement
    ...    Scrape all table rows from https://www.webscraper.io/test-sites/tables — extract row number, first name, last name, and username from both HTML tables on the page.
    ...    ${GENERATED_DIR}/tables-test.robot
    Generated Suite Should Pass BDD Validation
    Generated Suite Should Pass Dryrun
    Generated Suite Should Match Golden Baseline
    ...    ${GOLDEN_DIR}/tables-test.robot

Variants Click Expansion
    [Documentation]    Matrix/click expansion over product variants
    ${path}=    Generate Suite From Requirement
    ...    Scrape laptop variant data from https://www.webscraper.io/test-sites/e-commerce/ajax/computers/laptops — discover product URLs, then for each product click HDD size buttons (128/256/512/1024) and extract the price for each variant.
    ...    ${GENERATED_DIR}/variants-test.robot
    Generated Suite Should Pass BDD Validation
    Generated Suite Should Pass Dryrun
    Generated Suite Should Match Golden Baseline
    ...    ${GOLDEN_DIR}/variants-test.robot

Splunk ITSI Event Analytics With AI Extraction
    [Tags]    needs-work
    [Documentation]    Multi-section doc scraping + AI extraction for code blocks
    ${path}=    Generate Suite From Requirement
    ...    Scrape Splunk ITSI Entity Integrations and Event Analytics documentation from help.splunk.com. Two sections only. Discover page URLs from left-nav, extract title and body from each page. Use AI to extract code blocks and key definitions from the HTML body. Output as markdown.
    ...    ${GENERATED_DIR}/splunk-itsi-focused-test.robot
    Generated Suite Should Pass BDD Validation
    Generated Suite Should Pass Dryrun
    Generated Suite Should Match Golden Baseline
    ...    ${GOLDEN_DIR}/splunk-itsi-focused-test.robot

Quotes With Login Auth
    [Documentation]    Auth test: login via state setup, then scrape quotes
    ${path}=    Generate Suite From Requirement
    ...    Log in to quotes.toscrape.com using the login page (username: admin, password: admin), then scrape quotes visible to authenticated users. Extract quote text, author, and tags. Paginate via next button for 3 pages.
    ...    ${GENERATED_DIR}/quotes-login-test.robot
    Generated Suite Should Pass BDD Validation
    Generated Suite Should Pass Dryrun
    Generated Suite Should Match Golden Baseline
    ...    ${GOLDEN_DIR}/quotes-login-test.robot
