*** Comments ***
Requirement    Scrape Airbnb vacation rental listings in Miami for a month-long stay in November.
...            Criteria: Miami FL, Nov 1-30, 2 adults, entire home, 1 BR, under $3,000/month, Superhost.
...            Collect: property title, property name, nightly/monthly price, rating, review count,
...            listing URL, and guest-favorite badge if present.

*** Settings ***
Documentation     Stealth scrape of Airbnb monthly-stay listings via interactive search flow.
...               Starts at airbnb.com, types city, selects autocomplete (discovers place_id),
...               sets dates via calendar, sets guests, submits search, then applies filters
...               (price, bedrooms, superhost) via URL params.
...               Evidence: 18 cards/page via [data-testid="card-container"], pagination
...               via a[aria-label="Next"]. All selectors verified via agent-browser.
Library           Browser
Library           WiseRpaBDD
Suite Setup       Given I start deployment "${DEPLOYMENT}"
Suite Teardown    Then I finalize deployment

*** Variables ***
# ── Generalizable search parameters ──────────────────────────────────────────
# Override from command line:
#   robot --variable CITY_SEARCH:Austin,\ Texas --variable CHECKIN:2027-03-01 ...
${CITY_SEARCH}          Miami, Florida
${CHECKIN}              2026-11-01
${CHECKOUT}             2026-11-30
${ADULTS}               2
${PRICE_MAX}            3000
${MIN_BEDROOMS}         1
${SUPERHOST}            true
${MAX_PAGES}            5

${DEPLOYMENT}           airbnb-monthly-listings
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
    ...    description=Airbnb monthly-stay listings (filtered by city/dates/price/bedrooms/superhost)

Interrupt Setup
    [Documentation]    Auto-dismiss Airbnb overlays throughout the rule walk.
    ...                Evidence: "Got it" pricing modal appears intermittently and blocks clicks.
    And I configure interrupts
    ...    dismiss=text="Got it"
    ...    dismiss=[role="dialog"] button[aria-label="Close"]
    ...    dismiss=[data-testid="modal-container"] button[aria-label="Close"]

Resource listing_search
    [Documentation]    Produces: listings
    [Setup]    Given I start resource "search" at "${ENTRY_URL}"
    And I set resource globals
    ...    timeout_ms=30000
    ...    retries=2
    ...    page_load_delay_ms=2000

    # ── Action rule: expand the search bar if in compact mode ───────────────
    # Evidence: on some viewports/loads, the search bar renders compact with
    # "Anywhere | Anytime | Add guests" buttons. Clicking expands it.
    I define rule "expand_search"
        And I evaluate js "() => { for (const b of document.querySelectorAll('button, div[role=button]')) { const t = b.textContent.trim(); if (t === 'Anywhere' || t.startsWith('Anywhere')) { b.click(); return; } } }"
        When I wait 2000 ms

    # ── Action rule: type city and select autocomplete ────────────────────────
    # Evidence: input#bigsearch-query-location-input, placeholder="Search destinations"
    # Autocomplete: [data-testid="option-0"] is first suggestion (e.g. "Miami, FL")
    I define rule "enter_city"
        And I declare parents "expand_search"
        When I type "${CITY_SEARCH}" into locator "#bigsearch-query-location-input"
        When I wait 2000 ms
        When I click locator "[data-testid='option-0']"
        When I wait 1000 ms

    # ── Action rule: navigate calendar and select dates ───────────────────────
    # Evidence: calendar auto-opens after city selection.
    # Forward: button[aria-label*="Move forward"], month headings: h2 "November 2026"
    # Day buttons: aria-label="1, Sunday, November 2026. Available..."
    I define rule "set_dates"
        And I declare parents "enter_city"
        And I evaluate js "async () => { const sleep = ms => new Promise(r => setTimeout(r, ms)); const checkin = '${CHECKIN}'; const checkout = '${CHECKOUT}'; function monthYear(d) { return new Date(d + 'T00:00:00').toLocaleDateString('en-US', {month:'long', year:'numeric'}); } async function navTo(my) { while (true) { let found = false; for (const h of document.querySelectorAll('h2')) { if (h.textContent.trim() === my) { found = true; break; } } if (found) break; const fwd = document.querySelector('button[aria-label*=\"Move forward\"]'); if (!fwd) break; fwd.click(); await sleep(400); } } function clickDay(day, my) { for (const b of document.querySelectorAll('button')) { const l = b.getAttribute('aria-label') || ''; if (l.startsWith(day + ', ') && l.includes(my)) { b.click(); return; } } } const ciMY = monthYear(checkin); const coMY = monthYear(checkout); const ciDay = String(parseInt(checkin.split('-')[2])); const coDay = String(parseInt(checkout.split('-')[2])); await navTo(ciMY); clickDay(ciDay, ciMY); await sleep(300); if (coMY !== ciMY) await navTo(coMY); clickDay(coDay, coMY); await sleep(300); }"

    # ── Action rule: set guest count ──────────────────────────────────────────
    # Evidence: div[tabindex="0"] containing "guest" opens guest panel.
    # Adults stepper: [data-testid="stepper-adults-increase-button"]
    I define rule "set_guests"
        And I declare parents "set_dates"
        And I evaluate js "() => { for (const d of document.querySelectorAll('div[tabindex]')) { if (d.textContent.includes('guest')) { d.click(); return; } } }"
        When I wait 500 ms
        And I evaluate js "() => { const n = ${ADULTS}; const btn = document.querySelector('[data-testid=\"stepper-adults-increase-button\"]'); for (let i = 0; i < n; i++) { btn.click(); } }"
        When I wait 500 ms

    # ── Action rule: submit search ────────────────────────────────────────────
    # Evidence: button[data-testid="structured-search-input-search-button"]
    # The "Got it" popup is handled by configure interrupts (runs before each action).
    I define rule "submit_search"
        And I declare parents "set_guests"
        When I click locator "[data-testid='structured-search-input-search-button']"

    # ── Action rule: apply filters via URL params ─────────────────────────────
    # Evidence: price_max, min_bedrooms, superhost all work as URL query params.
    # Adding superhost=true narrowed Miami results from 1000+ to 533.
    I define rule "apply_filters"
        And I declare parents "submit_search"
        When I wait 3000 ms
        And I evaluate js "() => { const u = new URL(window.location.href); u.searchParams.set('price_max', '${PRICE_MAX}'); u.searchParams.set('min_bedrooms', '${MIN_BEDROOMS}'); u.searchParams.set('superhost', '${SUPERHOST}'); window.location.href = u.toString(); }"
        When I wait 5000 ms

    # ── State gate: confirm search results loaded ─────────────────────────────
    I define rule "root"
        And I declare parents "apply_filters"
        Given url contains "airbnb.com/s/"
        And selector "[data-testid='card-container']" exists

    # ── Pagination ────────────────────────────────────────────────────────────
    # Evidence: nav[aria-label="Search results pagination"], a[aria-label="Next"]
    I define rule "pages"
        And I declare parents "root"
        When I paginate by next button "a[aria-label='Next']" up to ${MAX_PAGES} pages

    # ── Extraction: 18 cards per page ─────────────────────────────────────────
    # Evidence (confirmed on p1 and p2 via agent-browser):
    #   title       — [data-testid="listing-card-title"]  "Home in Miami"
    #   name        — [data-testid="listing-card-name"]   "2 Beds Studio | Parking free"
    #   price       — [data-testid="price-availability-row"]  "$2,784 $2,069..."
    #   rating      — .r4a59j5 span[aria-hidden]  "4.87 (149)" or "New"
    #   listing_url — a[aria-labelledby]  href="/rooms/{id}?..."
    #   badge       — .t1qa5xaj  "Guest favorite" / "Superhost" (absent on some)
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
