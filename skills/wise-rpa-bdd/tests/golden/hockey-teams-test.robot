*** Comments ***
Requirement    Scrape NHL hockey team stats from scrapethissite.com.
...            Collect team name, year, wins, losses, goals for, and goals against.

*** Settings ***
Documentation     Scrape NHL hockey team stats from scrapethissite.com forms page.
...               Extracts team name, year, wins, losses, goals for, and goals against
...               across 24 paginated pages (582 total team records, 25 per page, 7 on last page).
...               Pagination: a[aria-label="Next"] stops naturally when absent on page 24.
...               Evidence: tr.team rows; td.name, td.year, td.wins, td.losses, td.gf, td.ga.
...               No auth required.
Library           Browser
Library           WiseRpaBDD
Suite Setup       Given I start deployment "${DEPLOYMENT}"
Suite Teardown    Then I finalize deployment

*** Variables ***
${DEPLOYMENT}           hockey-teams
${ENTRY_URL}            https://www.scrapethissite.com/pages/forms/?page_num=1
${ARTIFACT_TEAMS}       teams

*** Test Cases ***
Artifact Catalog
    # One artifact: flat list of all hockey team records
    Given I register artifact "${ARTIFACT_TEAMS}"
    ...    field=team_name       type=string    required=true
    ...    field=year            type=number    required=true
    ...    field=wins            type=number    required=true
    ...    field=losses          type=number    required=true
    ...    field=goals_for       type=number    required=true
    ...    field=goals_against   type=number    required=true
    And I set artifact options for "${ARTIFACT_TEAMS}"
    ...    output=true
    ...    structure=flat
    ...    description=NHL team stats: name, year, wins, losses, goals for, goals against (582 records expected)

Resource hockey_scrape
    # ── Resource: paginated hockey team stats table ───────────────────────────
    # Entry: https://www.scrapethissite.com/pages/forms/?page_num=1
    # Three-rule tree: root (state gate) → pages (next-button pagination) → teams (extract)
    # Pagination: a[aria-label="Next"] present on pages 1-23; absent on page 24 → natural stop.
    [Documentation]    Produces: teams (582 records: team_name, year, wins, losses, goals_for, goals_against)
    [Setup]    Given I start resource "hockey_scrape" at "${ENTRY_URL}"
    And I set resource globals
    ...    timeout_ms=30000
    ...    retries=2
    ...    page_load_delay_ms=1000

    # Rule: root — state gate confirming we are on the hockey forms page
    # Evidence: URL contains "pages/forms"; selector "tr.team" present (25 matches on page 1)
    And I begin rule "root"
    Given url contains "pages/forms"
    And selector "tr.team" exists

    # Rule: pages — drive next-button pagination across all 24 pages
    # Evidence: a[aria-label="Next"] present on pages 1-23 (href=/pages/forms/?page_num=N);
    #           absent on page 24 — engine stops naturally.
    And I begin rule "pages"
    And I declare parents "root"
    When I paginate by next button "a[aria-label='Next']" up to 24 pages

    # Rule: teams — expand over each tr.team on every visited page, then extract
    # Evidence: 25 tr.team rows per page (pages 1-23); 7 on page 24 → 582 total.
    # Extractors:
    #   team_name     — td.name, text   (e.g. "Boston Bruins")
    #   year          — td.year, text   (e.g. "1990")
    #   wins          — td.wins, text   (e.g. "44")
    #   losses        — td.losses, text (e.g. "24")
    #   goals_for     — td.gf, text     (e.g. "299")
    #   goals_against — td.ga, text     (e.g. "264")
    And I begin rule "teams"
    And I declare parents "pages"
    When I expand over elements "tr.team"
    Then I extract fields
    ...    field=team_name       extractor=text    locator=td.name
    ...    field=year            extractor=number  locator=td.year
    ...    field=wins            extractor=number  locator=td.wins
    ...    field=losses          extractor=number  locator=td.losses
    ...    field=goals_for       extractor=number  locator=td.gf
    ...    field=goals_against   extractor=number  locator=td.ga
    And I emit to artifact "${ARTIFACT_TEAMS}"

Quality Gates
    # 24 pages × 25 items/page − 18 missing on last page = 582 total records
    # All six fields confirmed present on every row sampled
    And I set quality gate min records to 100
    And I set filled percentage for "team_name" to 95
    And I set filled percentage for "year" to 95
    And I set filled percentage for "wins" to 95
    And I set filled percentage for "losses" to 95
    And I set filled percentage for "goals_for" to 95
    And I set filled percentage for "goals_against" to 95
