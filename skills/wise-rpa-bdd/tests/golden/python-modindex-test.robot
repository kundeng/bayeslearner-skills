*** Comments ***
Requirement    Scrape the Python standard library module index from docs.python.org.
...            Collect each module name and its one-line description.

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
    I define rule "root"
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
    I define rule "each_module"
        And I declare parents "root"
        When I expand over elements "table.modindextable tr"
        Then I extract fields
        ...    field=module_name    extractor=text    locator="code.xref"
        ...    field=description    extractor=text    locator="td:nth-child(3)"
        And I emit to artifact "${ARTIFACT_MODULES}"

Quality Gates
    # ~368 modules total; some sub-modules have no visible name text (only a link),
    # and deprecated/internal modules often have no description on the index page.
    And I set quality gate min records to 250
    And I set filled percentage for "module_name" to 85
    And I set filled percentage for "description" to 80
