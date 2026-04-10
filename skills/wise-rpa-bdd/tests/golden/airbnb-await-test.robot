*** Comments ***
Requirement    Scrape Airbnb vacation rental listings in Miami for a month-long stay in November.
...            Criteria: Miami FL, Nov 1-30, 2 adults, entire home, 1 BR, under $3,000/month, Superhost.
...            Collect: property title, property name, nightly/monthly price, rating, review count,
...            listing URL, and guest-favorite badge if present.
...
...            Pattern: AWAIT observation gates (Option 2).
...            Async dependencies between actions within a rule use the await=
...            parameter — an inline observation gate that waits for a selector
...            before the engine advances to the next action.
...            No "When I wait" anywhere. Rules stay grouped by user intent.

*** Settings ***
Documentation     Stealth scrape of Airbnb monthly-stay listings via interactive search flow.
...               Same scenario as airbnb-miami-stealth-test but replaces every
...               "When I wait" with an await= observation gate on the preceding action.
...               Rules stay grouped by user intent (fewer nodes than split-rule).
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

${DEPLOYMENT}           airbnb-await
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
    ...    description=Airbnb monthly-stay listings (await pattern)

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

    # ── Action rule: expand search bar and type city ──────────────────
    # Evidence: "Anywhere" expands compact bar; typing triggers autocomplete.
    # await= on click waits for the input to appear before typing.
    # await= on type waits for autocomplete dropdown before clicking.
    I define rule "enter_city"
        When I click text "Anywhere"
        ...    await=#bigsearch-query-location-input
        When I type "${CITY_SEARCH}" into locator "#bigsearch-query-location-input"
        ...    await=[data-testid='option-0']
        When I click locator "[data-testid='option-0']"

    # ── Action rule: navigate calendar and select dates ───────────────
    # Evidence: calendar auto-opens after city selection.
    I define rule "set_dates"
        And I declare parents "enter_city"
        When I select date "${CHECKIN}" from datepicker
        ...    forward=button[aria-label*="Move forward"]
        ...    heading=h2
        When I select date "${CHECKOUT}" from datepicker
        ...    forward=button[aria-label*="Move forward"]
        ...    heading=h2

    # ── Action rule: set guest count ──────────────────────────────────
    # Evidence: "Add guests" opens panel; stepper appears inside it.
    # await= on click waits for stepper control to appear.
    I define rule "set_guests"
        And I declare parents "set_dates"
        When I click text "Add guests"
        ...    await=[data-testid='stepper-adults-increase-button']
        When I set stepper "[data-testid='stepper-adults-increase-button']" to ${ADULTS}

    # ── Action rule: submit search ────────────────────────────────────
    I define rule "submit_search"
        And I declare parents "set_guests"
        When I click locator "[data-testid='structured-search-input-search-button']"

    # ── State gate: search results loaded ─────────────────────────────
    I define rule "search_loaded"
        And I declare parents "submit_search"
        Given url contains "airbnb.com/s/"
        And selector "[data-testid='card-container']" exists

    # ── Action: apply filters via URL params ──────────────────────────
    I define rule "apply_filters"
        And I declare parents "search_loaded"
        When I add url params "price_max=${PRICE_MAX}&min_bedrooms=${MIN_BEDROOMS}&superhost=${SUPERHOST}"

    # ── State gate: filtered results loaded ───────────────────────────
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
