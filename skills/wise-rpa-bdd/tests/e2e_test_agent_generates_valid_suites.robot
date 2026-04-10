*** Comments ***
E2E tests for the wise-rpa-bdd skill.

Each test case gives a natural language requirement to the AI agent,
then validates that the agent produces a valid .robot suite that passes
BDD validation, dryrun, and structurally matches the golden baseline.

Not included: airbnb-* (requires live interaction, dates change),
quotes-callkw (tests engine call_keyword, not agent drafting),
quotes-fallback (tests engine fallback selectors, not agent drafting),
splunk-itsi-complete (10+ min runtime, covered by focused variant).

*** Settings ***
Documentation     wise-rpa-bdd agent suite generation tests
Library           WiseRpaBDD.WiseRpaBDDTest    model=sonnet    max_turns=50
Test Timeout      10 minutes

*** Variables ***
${GOLDEN_DIR}         ${CURDIR}/golden
${GENERATED_DIR}      ${CURDIR}/generated

*** Test Cases ***
# --- Basic: pagination + element extraction ---

Quotes Scraping
    [Documentation]    Pagination via next button, text + grouped extraction
    ${path}=    Generate Suite From Requirement
    ...    Scrape all quotes from https://quotes.toscrape.com/ — extract quote text, author name, and tags for each quote.
    ...    ${GENERATED_DIR}/quotes-test.robot
    Generated Suite Should Pass BDD Validation
    Generated Suite Should Pass Dryrun
    Generated Suite Should Match Golden Baseline
    ...    ${GOLDEN_DIR}/quotes-test.robot

Quotes By Tag
    [Documentation]    Filtered tag page, pagination
    ${path}=    Generate Suite From Requirement
    ...    Scrape all quotes tagged "love" from https://quotes.toscrape.com/tag/love/ — extract quote text, author, and tags.
    ...    ${GENERATED_DIR}/quotes-by-tag-test.robot
    Generated Suite Should Pass BDD Validation
    Generated Suite Should Pass Dryrun
    Generated Suite Should Match Golden Baseline
    ...    ${GOLDEN_DIR}/quotes-by-tag-test.robot

Quotes JS Rendered
    [Documentation]    JavaScript-rendered version, same structure
    ${path}=    Generate Suite From Requirement
    ...    Scrape quotes from the JavaScript-rendered version of quotes.toscrape.com at https://quotes.toscrape.com/js/ — extract quote text, author, and tags.
    ...    ${GENERATED_DIR}/quotes-js-test.robot
    Generated Suite Should Pass BDD Validation
    Generated Suite Should Pass Dryrun
    Generated Suite Should Match Golden Baseline
    ...    ${GOLDEN_DIR}/quotes-js-test.robot

Quotes JMESPath
    [Documentation]    JMESPath query transform on output
    ${path}=    Generate Suite From Requirement
    ...    Scrape quotes from https://quotes.toscrape.com/ — extract quote text, author, and tags. Produce a full dataset and a JMESPath-filtered top-10 subset.
    ...    ${GENERATED_DIR}/quotes-jmespath-test.robot
    Generated Suite Should Pass BDD Validation
    Generated Suite Should Pass Dryrun
    Generated Suite Should Match Golden Baseline
    ...    ${GOLDEN_DIR}/quotes-jmespath-test.robot

Countries List
    [Documentation]    Simple element expansion, no pagination
    ${path}=    Generate Suite From Requirement
    ...    Scrape all countries from https://www.scrapethissite.com/pages/simple/ — collect country name, capital, population, and area.
    ...    ${GENERATED_DIR}/countries-list-test.robot
    Generated Suite Should Pass BDD Validation
    Generated Suite Should Pass Dryrun
    Generated Suite Should Match Golden Baseline
    ...    ${GOLDEN_DIR}/countries-list-test.robot

# --- Pagination variants ---

Hockey Teams
    [Documentation]    Paginated table with next-button pagination (24 pages)
    ${path}=    Generate Suite From Requirement
    ...    Scrape NHL hockey team stats from https://www.scrapethissite.com/pages/forms/ — extract team name, year, wins, losses, goals for, and goals against.
    ...    ${GENERATED_DIR}/hockey-teams-test.robot
    Generated Suite Should Pass BDD Validation
    Generated Suite Should Pass Dryrun
    Generated Suite Should Match Golden Baseline
    ...    ${GOLDEN_DIR}/hockey-teams-test.robot

Oscar Films
    [Documentation]    AJAX tab expansion + element extraction
    ${path}=    Generate Suite From Requirement
    ...    Scrape Oscar-winning films from https://www.scrapethissite.com/pages/ajax-javascript/ for years 2010-2015 — extract title, nominations, awards, and best picture flag.
    ...    ${GENERATED_DIR}/oscar-films-test.robot
    Generated Suite Should Pass BDD Validation
    Generated Suite Should Pass Dryrun
    Generated Suite Should Match Golden Baseline
    ...    ${GOLDEN_DIR}/oscar-films-test.robot

Laptop Paginated Scraping
    [Documentation]    Paginated element expansion with next button
    ${path}=    Generate Suite From Requirement
    ...    Scrape all laptops from the webscraper.io test e-commerce site. Collect title, price, description, and star rating for each laptop.
    ...    ${GENERATED_DIR}/laptop-paginated-test.robot
    Generated Suite Should Pass BDD Validation
    Generated Suite Should Pass Dryrun
    Generated Suite Should Match Golden Baseline
    ...    ${GOLDEN_DIR}/laptop-paginated-test.robot

# --- Table extraction ---

Tables Extraction
    [Documentation]    HTML table extraction with header mapping
    ${path}=    Generate Suite From Requirement
    ...    Scrape all rows from the HTML tables on the webscraper.io tables test page. Collect row number, first name, last name, and username.
    ...    ${GENERATED_DIR}/tables-test.robot
    Generated Suite Should Pass BDD Validation
    Generated Suite Should Pass Dryrun
    Generated Suite Should Match Golden Baseline
    ...    ${GOLDEN_DIR}/tables-test.robot

Revspin Table Scraping
    [Documentation]    Sort action, numeric pagination, table extraction
    ${path}=    Generate Suite From Requirement
    ...    Scrape table tennis rubber ratings from https://revspin.net/top-rubber/overall-desc.html — extract all rubber attributes sorted by durability.
    ...    ${GENERATED_DIR}/revspin-test.robot
    Generated Suite Should Pass BDD Validation
    Generated Suite Should Pass Dryrun
    Generated Suite Should Match Golden Baseline
    ...    ${GOLDEN_DIR}/revspin-test.robot

# --- AJAX / dynamic sites ---

AJAX Tablets
    [Documentation]    AJAX-loaded product cards
    ${path}=    Generate Suite From Requirement
    ...    Scrape all tablets from the webscraper.io AJAX e-commerce test site at https://webscraper.io/test-sites/e-commerce/ajax/computers/tablets — collect title, price, description, and rating.
    ...    ${GENERATED_DIR}/ajax-tablets-test.robot
    Generated Suite Should Pass BDD Validation
    Generated Suite Should Pass Dryrun
    Generated Suite Should Match Golden Baseline
    ...    ${GOLDEN_DIR}/ajax-tablets-test.robot

E-Commerce Phones
    [Documentation]    Paginated product listing
    ${path}=    Generate Suite From Requirement
    ...    Scrape all phone products from the webscraper.io test e-commerce site at https://webscraper.io/test-sites/e-commerce/static/computers/phones — collect title, price, and description.
    ...    ${GENERATED_DIR}/e-commerce-phones-test.robot
    Generated Suite Should Pass BDD Validation
    Generated Suite Should Pass Dryrun
    Generated Suite Should Match Golden Baseline
    ...    ${GOLDEN_DIR}/e-commerce-phones-test.robot

# --- Auth flow ---

Quotes With Login Auth
    [Documentation]    Auth test: login then scrape
    ${path}=    Generate Suite From Requirement
    ...    Log in to quotes.toscrape.com (username: admin, password: admin), then scrape quotes. Collect quote text, author, and tags.
    ...    ${GENERATED_DIR}/quotes-login-test.robot
    Generated Suite Should Pass BDD Validation
    Generated Suite Should Pass Dryrun
    Generated Suite Should Match Golden Baseline
    ...    ${GOLDEN_DIR}/quotes-login-test.robot

# --- Multi-resource chaining ---

Books Catalogue
    [Documentation]    Category listing with detail page chaining
    ${path}=    Generate Suite From Requirement
    ...    Scrape all books from https://books.toscrape.com/catalogue/category/books_1/index.html — collect title, price, and availability from the listing page.
    ...    ${GENERATED_DIR}/books-catalogue-test.robot
    Generated Suite Should Pass BDD Validation
    Generated Suite Should Pass Dryrun
    Generated Suite Should Match Golden Baseline
    ...    ${GOLDEN_DIR}/books-catalogue-test.robot

Scifi Books Discovery Detail
    [Documentation]    Two-resource discovery → detail chaining
    ${path}=    Generate Suite From Requirement
    ...    Scrape all sci-fi books from https://books.toscrape.com/catalogue/category/books/science-fiction_16/index.html — discover book URLs from the listing, then visit each detail page to extract title, price, description, UPC, availability, and review count.
    ...    ${GENERATED_DIR}/scifi-books-test.robot
    Generated Suite Should Pass BDD Validation
    Generated Suite Should Pass Dryrun
    Generated Suite Should Match Golden Baseline
    ...    ${GOLDEN_DIR}/scifi-books-test.robot

Herokuapp Index
    [Documentation]    Simple index page scraping
    ${path}=    Generate Suite From Requirement
    ...    Scrape the index of all test pages from https://the-internet.herokuapp.com/ — collect page name and URL for each link.
    ...    ${GENERATED_DIR}/herokuapp-index-test.robot
    Generated Suite Should Pass BDD Validation
    Generated Suite Should Pass Dryrun
    Generated Suite Should Match Golden Baseline
    ...    ${GOLDEN_DIR}/herokuapp-index-test.robot

MDN Web API Reference
    [Documentation]    Discovery → detail, multi-resource
    ${path}=    Generate Suite From Requirement
    ...    Scrape Web API names and descriptions from the MDN Web API reference at https://developer.mozilla.org/en-US/docs/Web/API — discover API page URLs from the index, then extract name and description from each detail page.
    ...    ${GENERATED_DIR}/mdn-web-api-test.robot
    Generated Suite Should Pass BDD Validation
    Generated Suite Should Pass Dryrun
    Generated Suite Should Match Golden Baseline
    ...    ${GOLDEN_DIR}/mdn-web-api-test.robot

Python Module Index
    [Documentation]    Single-page table extraction
    ${path}=    Generate Suite From Requirement
    ...    Scrape the Python standard library module index from https://docs.python.org/3/py-modindex.html — extract module name and description for each module.
    ...    ${GENERATED_DIR}/python-modindex-test.robot
    Generated Suite Should Pass BDD Validation
    Generated Suite Should Pass Dryrun
    Generated Suite Should Match Golden Baseline
    ...    ${GOLDEN_DIR}/python-modindex-test.robot

# --- Matrix / combination expansion ---

Variants Click Expansion
    [Documentation]    Matrix/click expansion over product variants
    ${path}=    Generate Suite From Requirement
    ...    Scrape laptop variant pricing from the webscraper.io AJAX e-commerce site. For each laptop, get the price at every available HDD size option.
    ...    ${GENERATED_DIR}/variants-test.robot
    Generated Suite Should Pass BDD Validation
    Generated Suite Should Pass Dryrun
    Generated Suite Should Match Golden Baseline
    ...    ${GOLDEN_DIR}/variants-test.robot

# --- Interrupt dismiss ---

Cookiebot Interrupt
    [Documentation]    Auto-dismiss cookie consent overlay
    ${path}=    Generate Suite From Requirement
    ...    Scrape the heading and main content from https://www.cookiebot.com/en/cookie-consent/ — the page has a cookie consent banner that must be dismissed first.
    ...    ${GENERATED_DIR}/cookiebot-interrupt-test.robot
    Generated Suite Should Pass BDD Validation
    Generated Suite Should Pass Dryrun
    Generated Suite Should Match Golden Baseline
    ...    ${GOLDEN_DIR}/cookiebot-interrupt-test.robot

# --- AI extraction ---

Splunk ITSI With AI Extraction
    [Documentation]    Multi-section doc scraping + AI extraction
    ${path}=    Generate Suite From Requirement
    ...    Scrape Splunk ITSI documentation from help.splunk.com — extract page titles and body content from the Entity Integrations and Event Analytics manuals. Clean up body HTML with AI.
    ...    ${GENERATED_DIR}/splunk-itsi-focused-test.robot
    Generated Suite Should Pass BDD Validation
    Generated Suite Should Pass Dryrun
    Generated Suite Should Match Golden Baseline
    ...    ${GOLDEN_DIR}/splunk-itsi-focused-test.robot
