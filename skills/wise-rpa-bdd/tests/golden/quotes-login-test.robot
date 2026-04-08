*** Comments ***
Requirement    Log in to quotes.toscrape.com using the login page (username: admin,
...            password: admin), then scrape quotes visible to authenticated users.
...            Extract quote text, author, and tags. Paginate via next button for 3 pages.
Expected       quote_text,author,tags
Min Records    30

# ── Evidence (live DOM — curl exploration session) ───────────────────────────
#
# Fetched: https://quotes.toscrape.com/login  (login form)
# Method:  curl against live HTML; selectors verified from raw markup.
#
# Login form         : form[action="/login"][method="post"]
# Username input     : input#username          — <input type="text" class="form-control" id="username" name="username" />
# Password input     : input#password          — <input type="password" class="form-control" id="password" name="password" />
# Submit button      : input[type='submit']    — <input type="submit" value="Login" class="btn btn-primary" />
# CSRF token         : input[name="csrf_token"] — hidden, auto-handled by browser session
#
# Auth indicator     : a[href="/logout"]        — present after login (replaces a[href="/login"])
# Login link         : a[href="/login"]         — present when unauthenticated
#
# Fetched: https://quotes.toscrape.com/  (quote listing, pages 1–3)
#
# Quote container    : div.quote               — 10 per page (confirmed p1/2/3)
#                      <div class="quote" itemscope itemtype="http://schema.org/CreativeWork">
#
# Quote text         : span.text               — <span class="text" itemprop="text">"…"</span>
#                      Includes typographic/curly quotes. Always present.
#
# Author             : small.author            — <small class="author" itemprop="author">Albert Einstein</small>
#                      Direct text node. Always populated.
#
# Tags               : a.tag                   — <a class="tag" href="/tag/change/page/1/">change</a>
#                      Multiple per quote; zero tags possible on some quotes.
#
# Next button        : li.next a               — <li class="next"><a href="/page/2/">Next …</a></li>
#                      Absent on last page (page 10) — natural stop.
#
# Pagination: 3-page limit → 30 records expected (10 per page).
# ─────────────────────────────────────────────────────────────────────────────

*** Settings ***
Documentation     Auth test: log in to quotes.toscrape.com via state setup, then
...               scrape quote text, author, and tags across 3 paginated pages.
...               Evidence: login form at /login with input#username, input#password,
...               input[type='submit']. Post-login indicator: a[href="/logout"].
...               Quote selectors: div.quote, span.text, small.author, a.tag.
...               Pagination: li.next a, limit=3 pages, 10 quotes/page → 30 records.
Library           Browser
Library           WiseRpaBDD
Suite Setup       Given I start deployment "${DEPLOYMENT}"
Suite Teardown    Then I finalize deployment

*** Variables ***
${DEPLOYMENT}           quotes-authenticated
${ENTRY_URL}            https://quotes.toscrape.com/
${ARTIFACT_QUOTES}      quotes

*** Test Cases ***
Artifact Catalog
    Given I register artifact "${ARTIFACT_QUOTES}"
    ...    field=quote_text    type=string    required=true
    ...    field=author        type=string    required=true
    ...    field=tags          type=array     required=true
    And I set artifact options for "${ARTIFACT_QUOTES}"
    ...    output=true
    ...    structure=flat
    ...    description=Quotes scraped after authenticated login (one row per quote)

Auth Setup
    [Documentation]    Configure login flow — skip if logout link already present
    Given I configure state setup
    ...    skip_when=a[href="/logout"]
    ...    action=open       url="https://quotes.toscrape.com/login"
    ...    action=input      css="input#username"          value="admin"
    ...    action=password   css="input#password"          value="admin"
    ...    action=click      css="input[type='submit']"

Resource quote_pages
    [Documentation]    Produces: quotes
    [Setup]    Given I start resource "quote_pages" at "${ENTRY_URL}"
    And I set resource globals
    ...    timeout_ms=30000
    ...    retries=2
    ...    page_load_delay_ms=1000

    # Rule: root — state gate confirming correct domain and quote presence
    And I begin rule "root"
    Given url matches "quotes.toscrape.com"
    And selector ".quote" exists

    # Rule: pages — drive next-button pagination across at most 3 pages
    And I begin rule "pages"
    And I declare parents "root"
    When I paginate by next button "li.next a" up to 3 pages

    # Rule: items — expand over each div.quote, extract fields, emit
    And I begin rule "items"
    And I declare parents "pages"
    When I expand over elements ".quote"
    Then I extract fields
    ...    field=quote_text    extractor=text       locator="span.text"
    ...    field=author        extractor=text       locator="small.author"
    ...    field=tags          extractor=grouped    locator="a.tag"
    And I emit to artifact "${ARTIFACT_QUOTES}"

Quality Gates
    # 3 pages × 10 quotes/page = 30 records minimum
    And I set quality gate min records to 30
    And I set filled percentage for "quote_text" to 100
    And I set filled percentage for "author" to 100
    And I set filled percentage for "tags" to 80
