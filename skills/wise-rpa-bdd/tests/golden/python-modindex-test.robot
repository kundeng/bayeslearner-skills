*** Comments ***
Requirement    Scrape the Python standard library module index from https://docs.python.org/3/py-modindex.html — extract all module names and their one-line descriptions from the index table. Single page extraction.
Expected       module_name,description
Min Records    250

# ── Evidence (live DOM — curl + WebFetch exploration, 2026-04-07) ────────────
#
# Fetched: https://docs.python.org/3/py-modindex.html  (single page, no pagination)
# Method:  curl against live HTML; selectors confirmed from raw HTML source.
#
# Page title     : "Python Module Index — Python 3.14.4 documentation"
# Auth           : none — public page, no login or cookie consent required.
# Pagination     : none — all modules rendered on a single page.
#
# Container      : table.indextable.modindextable
#   Selector     : "table.modindextable" — single table element, holds entire index.
#
# Row structure  : <tr> elements with 3 <td> cells each:
#   td:nth-child(1) — empty spacer (indent level indicator)
#   td:nth-child(2) — module name link: <a href="..."><code class="xref">module_name</code></a>
#   td:nth-child(3) — description: <em>One-line description.</em>
#                      May also contain <strong>Deprecated:</strong> prefix.
#
# Non-data rows  : tr.pcap (padding) and tr.cap (letter headings like "a", "b", etc.)
#   These rows have no <code class="xref"> element; text extractor on "code.xref"
#   will yield empty → filtered by required=true on module_name field.
#
# Example entries (first 4 data rows):
#   __future__     | Future statement definitions
#   __main__       | The environment where top-level code is run. ...
#   _thread        | Low-level threading API.
#   _tkinter       | A binary module that contains the low-level interface to Tcl/Tk.
#
# Total modules   : ~316 (confirmed via grep count of code.xref elements)
#
# Extraction strategy:
#   Expand over elements "table.modindextable tr" to iterate all table rows.
#   Extract module_name via text extractor on "code.xref" (present only in data rows).
#   Extract description via text extractor on "td:nth-child(3)" (captures full cell text
#   including any "Deprecated:" prefix and the em-wrapped description).
#   Non-data rows (cap/pcap) lack code.xref → module_name empty → filtered by required=true.
#
# Quality gates:
#   min_records = 250  (conservative; actual count ~316)
#   module_name  = 100% fill (always present in valid data rows)
#   description  = 90% fill  (most modules have descriptions; some deprecated stubs may be terse)
#
# ─────────────────────────────────────────────────────────────────────────────

*** Settings ***
Documentation     Scrape all Python standard library module names and one-line
...               descriptions from the official module index at
...               https://docs.python.org/3/py-modindex.html.
...               Evidence: single table.modindextable with ~316 module rows.
...               Each row has module name in code.xref and description in td:nth-child(3).
...               Non-data rows (letter headings) filtered by required=true on module_name.
Library           Browser
Library           WiseRpaBDD
Suite Setup       Given I start deployment "${DEPLOYMENT}"
Suite Teardown    Then I finalize deployment

*** Variables ***
${DEPLOYMENT}            python-modindex
${ENTRY_URL}             https://docs.python.org/3/py-modindex.html
${ARTIFACT_MODULES}      modules

*** Test Cases ***
Artifact Catalog
    Given I register artifact "${ARTIFACT_MODULES}"
    ...    field=module_name    type=string    required=true
    ...    field=description    type=string    required=false
    And I set artifact options for "${ARTIFACT_MODULES}"
    ...    output=true
    ...    structure=flat
    ...    description=Python standard library modules with names and one-line descriptions

Resource modindex_scrape
    [Documentation]    Produces: modules
    [Setup]    Given I start resource "modindex_scrape" at "${ENTRY_URL}"
    And I set resource globals
    ...    timeout_ms=30000
    ...    retries=2

    # Rule: root — state gate confirming correct page before extraction.
    # Evidence: URL contains "py-modindex"; table.modindextable present on page.
    And I begin rule "root"
    Given url contains "py-modindex"
    And selector "table.modindextable" exists

    # Rule: each_module — expand over every <tr> in the module index table.
    # Evidence: ~316 <tr> elements inside table.modindextable.
    #   Data rows contain <code class="xref"> with module name and <em> with description.
    #   Section-header rows (tr.cap, tr.pcap) lack code.xref → module_name empty →
    #   filtered out by the required=true constraint on the artifact field.
    # Extractors:
    #   module_name — text from "code.xref" (the module name link text)
    #   description — text from "td:nth-child(3)" (full description cell text)
    And I begin rule "each_module"
    And I declare parents "root"
    When I expand over elements "table.modindextable tr"
    Then I extract fields
    ...    field=module_name    extractor=text    locator="code.xref"
    ...    field=description    extractor=text    locator="td:nth-child(3)"
    And I emit to artifact "${ARTIFACT_MODULES}"

Quality Gates
    # ~316 modules total; require at least 250 to allow for minor edge cases
    # module_name always present in valid data rows (enforced by required=true)
    # description present for most modules; some deprecated entries may have terse text
    And I set quality gate min records to 250
    And I set filled percentage for "module_name" to 100
    And I set filled percentage for "description" to 90
