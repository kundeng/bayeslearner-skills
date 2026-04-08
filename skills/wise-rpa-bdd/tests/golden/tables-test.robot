*** Comments ***
Requirement    Scrape all table rows from https://www.webscraper.io/test-sites/tables — extract row number, first name, last name, and username from both HTML tables on the page.
Expected       #,First Name,Last Name,Username
Min Records    6

# ── Evidence (live DOM — /rrpa-explore session) ────────────────────────────────
#
# Fetched: https://www.webscraper.io/test-sites/tables  (WebFetch, 2026-04-08)
# Method:  WebFetch HTML inspection; selectors confirmed from raw page HTML.
#
# Page title   : "Table Playground | Web Scraper Test Sites"
# Auth         : none — public page, no login or cookie consent observed.
# Pagination   : none — all 6 rows on a single page across two tables.
#
# Table count  : 2 plain <table> elements — no class or id attributes on either.
#   Selector   : "table"  — matches both tables in document order.
#   Wrapper    : no outer div wrapper with distinctive class; tables sit inside
#                the main content column directly.
#
# Table structure (both tables identical shape):
#   <table>
#     <thead>
#       <tr><th>#</th><th>First Name</th><th>Last Name</th><th>Username</th></tr>
#     </thead>
#     <tbody> … </tbody>
#   </table>
#
# Table 1 data (rows 1–3):
#   1 | Mark   | Otto     | @mdo
#   2 | Jacob  | Thornton | @fat
#   3 | Larry  | the Bird | @twitter
#
# Table 2 data (rows 4–6):
#   4 | Harry  | Potter   | @hp
#   5 | John   | Snow     | @dunno
#   6 | Tim    | Bean     | @timbean
#
# Extraction strategy:
#   Expand over elements "table" (matches both tables in order).
#   Use header-mapped table extraction: header_row=0, headers #/First Name/Last Name/Username.
#   Emit flattened by "rows" for flat output; also emit nested for tree chaining.
#
# Quality gates:
#   min_records = 6  (3 rows × 2 tables)
#   First Name, Last Name, Username = 100% fill (all cells populated in both tables)
#
# ───────────────────────────────────────────────────────────────────────────────

*** Settings ***
Documentation     Scrape row number, first name, last name, and username from both
...               HTML tables on https://www.webscraper.io/test-sites/tables.
...               Evidence: 2 plain <table> elements (no class/id), identical 4-column
...               structure with thead/tbody. 3 rows each → 6 total records.
...               Strategy: expand over elements "table", header-mapped extraction.
Library           Browser
Library           WiseRpaBDD
Suite Setup       Given I start deployment "${DEPLOYMENT}"
Suite Teardown    Then I finalize deployment

*** Variables ***
${DEPLOYMENT}               tables-test
${ENTRY_URL}                https://www.webscraper.io/test-sites/tables
${ARTIFACT_TABLE_DATA}      table_data
${ARTIFACT_TABLE_NESTED}    table_data_nested

*** Test Cases ***
Artifact Catalog
    # Flat artifact — one record per table row; ready for CSV/JSONL export
    Given I register artifact "${ARTIFACT_TABLE_DATA}"
    ...    field=#             type=string    required=true
    ...    field=First Name    type=string    required=true
    ...    field=Last Name     type=string    required=true
    ...    field=Username      type=string    required=true
    And I set artifact options for "${ARTIFACT_TABLE_DATA}"
    ...    output=true
    ...    structure=flat
    ...    description=Table rows as flat denormalized records (one row per entry)
    # Nested artifact — preserves table → rows tree structure for downstream chaining
    Given I register artifact "${ARTIFACT_TABLE_NESTED}"
    ...    field=#             type=string    required=true
    ...    field=First Name    type=string    required=true
    ...    field=Last Name     type=string    required=true
    ...    field=Username      type=string    required=true
    And I set artifact options for "${ARTIFACT_TABLE_NESTED}"
    ...    output=true
    ...    structure=nested
    ...    description=Table data as nested tree records (rows array embedded per table)

Resource table_scrape
    # ── Resource: two-table listing on a single page ────────────────────────────
    # Entry: https://www.webscraper.io/test-sites/tables  (no auth required)
    # Two-rule tree: root (state gate) → each_table (expand + extract)
    # No pagination — all 6 rows present on first load.
    # Selector "table" matches both tables in document order (confirmed via WebFetch).
    [Documentation]    Produces: table_data, table_data_nested
    [Setup]    Given I start resource "table_scrape" at "${ENTRY_URL}"
    And I set resource globals
    ...    timeout_ms=30000
    ...    retries=2

    # Rule: root — state gate confirming we are on the correct page before acting.
    # Evidence: URL contains "test-sites/tables"; selector "table" present (2 matches).
    And I begin rule "root"
    Given url contains "test-sites/tables"
    And selector "table" exists

    # Rule: each_table — expand over both <table> elements in document order.
    # Evidence: 2 plain <table> elements; no class/id distinguishes them.
    #           Expanding over "table" visits table 1 (rows 1–3) then table 2 (rows 4–6).
    # Extraction: header-mapped — header_row=0 reads <th> text from <thead>.
    #   # → "#" header, First Name → "First Name", Last Name → "Last Name",
    #   Username → "Username" (all confirmed from live HTML above).
    # Emit flattened by "rows" for flat output (one record per tbody row).
    And I begin rule "each_table"
    And I declare parents "root"
    When I expand over elements "table"
    Then I extract table "rows" from "table"
    ...    header_row=0
    ...    field=#             header="#"
    ...    field=First Name    header="First Name"
    ...    field=Last Name     header="Last Name"
    ...    field=Username      header="Username"
    And I emit to artifact "${ARTIFACT_TABLE_DATA}" flattened by "rows"
    And I emit to artifact "${ARTIFACT_TABLE_NESTED}"

Quality Gates
    # 2 tables × 3 rows each = 6 records minimum
    # All four columns fully populated in both tables (confirmed from live HTML)
    And I set quality gate min records to 6
    And I set filled percentage for "First Name" to 100
    And I set filled percentage for "Last Name" to 100
    And I set filled percentage for "Username" to 100
