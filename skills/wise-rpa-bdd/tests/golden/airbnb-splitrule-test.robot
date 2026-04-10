*** Comments ***
Requirement    Scrape Airbnb vacation rental listings in Miami for a month-long stay in November.
...            Criteria: Miami FL, Nov 1-30, 2 adults, entire home, 1 BR, under $3,000/month, Superhost.
...            Collect: property title, property name, nightly/monthly price, rating, review count,
...            listing URL, and guest-favorite badge if present.
...
...            Pattern: SPLIT-RULE observation gates (Option 1).
...            Every async dependency between actions is expressed as a separate
...            state-gate rule. No "When I wait" anywhere — the engine's native
...            wait_for_elements_state (10 s) handles all timing.

*** Settings ***
Documentation     Stealth scrape of Airbnb monthly-stay listings via interactive search flow.
...               Same scenario as airbnb-miami-stealth-test but uses split rules
...               with explicit state gates instead of "When I wait" between actions.
...               Each s,a→o transition is its own rule node in the MDP.
...               Evidence: all selectors verified via agent-browser.
Library           Browser
Library           WiseRpaBDD
Suite Setup       Given I start deployment "${DEPLOYMENT}"
Suite Teardown    Then I finalize deployment

*** Variables ***
# ── Generalizable search parameters ──────────────────────────────────────────
${CITY_SEARCH}          Miami, Florida
${CHECKIN}              2026-11-01
${CHECKOUT}             2026-11-30
${ADULTS}               2
${PRICE_MAX}            3000
${MIN_BEDROOMS}         1
${SUPERHOST}            true
${MAX_PAGES}            5

${DEPLOYMENT}           airbnb-splitrule
${ENTRY_URL}            https://www.airbnb.com
${ARTIFACT_LISTINGS}    listings

*** Test Cases ***
Artifact Catalog
    Given I register artifact "${ARTIFACT_LISTINGS}"
    ...    field=title         type=string    required=true
    ...    field=name          type=string    required=true
    ...    field=price         type=string    required=true
    ...    field=rating        type=string    required=false
    ...    field=listing_url   type=url       required=true
    ...    field=badge         type=string    required=false
    And I set artifact options for "${ARTIFACT_LISTINGS}"
    ...    output=true
    ...    dedupe=listing_url
    ...    description=Airbnb monthly-stay listings (split-rule pattern)

Interrupt Setup
    # Minimal dismiss — only the pricing "Got it" modal.
    # Broader selectors ([role="dialog"], [data-testid="modal-container"])
    # match the search/calendar/guest panels and close them mid-flow.
    And I configure interrupts
    ...    dismiss=text="Got it"

Resource listing_search
    [Documentation]    Produces: listings
    [Setup]    Given I start resource "search" at "${ENTRY_URL}"
    And I set resource globals
    ...    timeout_ms=30000
    ...    retries=2
    ...    page_load_delay_ms=500

    # ── Action: click "Anywhere" to expand compact search bar ─────────
    # Evidence: on some viewports, search bar renders compact with "Anywhere"
    I define rule "expand_search"
        When I click text "Anywhere"

    # ── Observation gate: search input is now visible ─────────────────
    # Evidence: input#bigsearch-query-location-input appears after expand
    I define rule "search_input_ready"
        And I declare parents "expand_search"
        And selector "#bigsearch-query-location-input" exists

    # ── Action: type city name into search field ──────────────────────
    # Evidence: input#bigsearch-query-location-input, placeholder="Search destinations"
    I define rule "type_city"
        And I declare parents "search_input_ready"
        When I type "${CITY_SEARCH}" into locator "#bigsearch-query-location-input"

    # ── Observation gate: autocomplete dropdown appeared ──────────────
    # Evidence: [data-testid="option-0"] is first autocomplete suggestion
    I define rule "autocomplete_ready"
        And I declare parents "type_city"
        And selector "[data-testid='option-0']" exists

    # ── Action: click first autocomplete suggestion ───────────────────
    I define rule "select_city"
        And I declare parents "autocomplete_ready"
        When I click locator "[data-testid='option-0']"

    # ── Action: navigate calendar and select dates ────────────────────
    # Evidence: calendar auto-opens after city selection.
    # Forward: button[aria-label*="Move forward"], month headings: h2
    I define rule "set_dates"
        And I declare parents "select_city"
        When I select date "${CHECKIN}" from datepicker
        ...    forward=button[aria-label*="Move forward"]
        ...    heading=h2
        When I select date "${CHECKOUT}" from datepicker
        ...    forward=button[aria-label*="Move forward"]
        ...    heading=h2

    # ── Action: open guest panel ──────────────────────────────────────
    I define rule "open_guest_panel"
        And I declare parents "set_dates"
        When I click text "Add guests"

    # ── Observation gate: stepper control is visible ──────────────────
    # Evidence: [data-testid="stepper-adults-increase-button"] in guest panel
    I define rule "stepper_ready"
        And I declare parents "open_guest_panel"
        And selector "[data-testid='stepper-adults-increase-button']" exists

    # ── Action: set adult count ───────────────────────────────────────
    I define rule "set_guests"
        And I declare parents "stepper_ready"
        When I set stepper "[data-testid='stepper-adults-increase-button']" to ${ADULTS}

    # ── Action: submit search ─────────────────────────────────────────
    # Evidence: button[data-testid="structured-search-input-search-button"]
    I define rule "submit_search"
        And I declare parents "set_guests"
        When I click locator "[data-testid='structured-search-input-search-button']"

    # ── Observation gate: search results loaded ───────────────────────
    I define rule "search_loaded"
        And I declare parents "submit_search"
        Given url contains "airbnb.com/s/"
        And selector "[data-testid='card-container']" exists

    # ── Action: apply filters via URL params ──────────────────────────
    I define rule "apply_filters"
        And I declare parents "search_loaded"
        When I add url params "price_max=${PRICE_MAX}&min_bedrooms=${MIN_BEDROOMS}&superhost=${SUPERHOST}"

    # ── Observation gate: filtered results loaded ─────────────────────
    I define rule "root"
        And I declare parents "apply_filters"
        Given url contains "airbnb.com/s/"
        And selector "[data-testid='card-container']" exists

    # ── Pagination ────────────────────────────────────────────────────
    I define rule "pages"
        And I declare parents "root"
        When I paginate by next button "a[aria-label='Next']" up to ${MAX_PAGES} pages

    # ── Extraction: 18 cards per page ─────────────────────────────────
    I define rule "items"
        And I declare parents "pages"
        When I expand over elements "[data-testid='card-container']"
        Then I extract fields
        ...    field=title         extractor=text    locator="[data-testid='listing-card-title']"
        ...    field=name          extractor=text    locator="[data-testid='listing-card-name']"
        ...    field=price         extractor=text    locator="[data-testid='price-availability-row']"
        ...    field=rating        extractor=text    locator=".r4a59j5 span[aria-hidden]"
        ...    field=listing_url   extractor=link    locator="a[aria-labelledby]"
        ...    field=badge         extractor=text    locator=".t1qa5xaj"
        And I emit to artifact "${ARTIFACT_LISTINGS}"

Quality Gates
    And I set quality gate min records to 10
    And I set filled percentage for "title" to 95
    And I set filled percentage for "name" to 90
    And I set filled percentage for "price" to 90
    And I set filled percentage for "listing_url" to 95
