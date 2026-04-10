*** Comments ***
Requirement    Scrape table tennis rubber ratings from
...            https://revspin.net/top-rubber/overall-desc.html — extract all rubber
...            attributes sorted by durability.

*** Settings ***
Documentation     Scrape table tennis rubber ratings from revspin.net sorted by
...               durability. Click durability sort, paginate through 2 pages,
...               extract rank, rubber name, speed, spin, control, durability,
...               overall, and price from each row.
Library           Browser
Library           WiseRpaBDD
Suite Setup       Given I start deployment "${DEPLOYMENT}"
Suite Teardown    Then I finalize deployment

*** Variables ***
${DEPLOYMENT}                   revspin-durable-top2pages
${ENTRY_URL}                    https://revspin.net/top-rubber/overall-desc.html
${ARTIFACT_RUBBERS_NESTED}      rubbers_nested
${ARTIFACT_RUBBERS_FLAT}        rubbers_flat

*** Test Cases ***
Artifact Catalog
    Given I register artifact "${ARTIFACT_RUBBERS_NESTED}"
    ...    field=rank               type=string    required=true
    ...    field=rubber             type=string    required=true
    ...    field=speed              type=string    required=true
    ...    field=spin               type=string    required=true
    ...    field=control            type=string    required=true
    ...    field=tacky              type=string    required=false
    ...    field=weight             type=string    required=false
    ...    field=sponge_hardness    type=string    required=false
    ...    field=gears              type=string    required=false
    ...    field=throw_angle        type=string    required=false
    ...    field=consistency        type=string    required=false
    ...    field=durable            type=string    required=true
    ...    field=overall            type=string    required=true
    ...    field=ratings            type=string    required=false
    ...    field=price              type=string    required=false
    And I set artifact options for "${ARTIFACT_RUBBERS_NESTED}"
    ...    output=true
    ...    structure=nested
    ...    description=Table tennis rubbers ranked by durability (nested tree)
    Given I register artifact "${ARTIFACT_RUBBERS_FLAT}"
    ...    field=rank               type=string    required=true
    ...    field=rubber             type=string    required=true
    ...    field=speed              type=string    required=true
    ...    field=spin               type=string    required=true
    ...    field=control            type=string    required=true
    ...    field=tacky              type=string    required=false
    ...    field=weight             type=string    required=false
    ...    field=sponge_hardness    type=string    required=false
    ...    field=gears              type=string    required=false
    ...    field=throw_angle        type=string    required=false
    ...    field=consistency        type=string    required=false
    ...    field=durable            type=string    required=true
    ...    field=overall            type=string    required=true
    ...    field=ratings            type=string    required=false
    ...    field=price              type=string    required=false
    And I set artifact options for "${ARTIFACT_RUBBERS_FLAT}"
    ...    output=true
    ...    structure=flat
    ...    description=Table tennis rubbers ranked by durability (flat records)

Resource revspin_rubber_durable
    [Documentation]    Produces: ['rubbers_nested', 'rubbers_flat']
    [Setup]    Given I start resource "revspin_rubber_durable" at "${ENTRY_URL}"
    And I set resource globals
    ...    timeout_ms=20000
    ...    retries=2
    ...    user_agent=Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36
    I define rule "root"
        Given url matches "revspin.net/top-rubber/overall-desc.html"
        And selector "table" exists
        When I click locator "td.durability a"
        ...    type=real
        When I wait for idle
    I define rule "durability_pages"
        And I declare parents "root"
        Given url matches "revspin.net/top-rubber/durability-desc.html"
        And selector "a.btn.btn-default[href*='p=']" exists
        When I paginate by numeric control "a.btn.btn-default[href*='p=']" from 1 up to 2 pages
    I define rule "rows"
        And I declare parents "durability_pages"
        And selector "table tbody tr" exists
        When I expand over elements "table tbody tr:not(.head)"
        Then I extract fields
        ...    field=rank               extractor=text    locator="td.rank"
        ...    field=rubber             extractor=text    locator="td.product"
        ...    field=speed              extractor=text    locator="td.speed"
        ...    field=spin               extractor=text    locator="td.spin"
        ...    field=control            extractor=text    locator="td.control"
        ...    field=tacky              extractor=text    locator="td.tackiness"
        ...    field=weight             extractor=text    locator="td.weight"
        ...    field=sponge_hardness    extractor=text    locator="td.sponge_hardness"
        ...    field=gears              extractor=text    locator="td.gears"
        ...    field=throw_angle        extractor=text    locator="td.throw_angle"
        ...    field=consistency        extractor=text    locator="td.consistency"
        ...    field=durable            extractor=text    locator="td.durability"
        ...    field=overall            extractor=text    locator="td.overall"
        ...    field=ratings            extractor=text    locator="td.ratings"
        ...    field=price              extractor=text    locator="td.price"
        And I emit to artifact "${ARTIFACT_RUBBERS_NESTED}"
        And I emit to artifact "${ARTIFACT_RUBBERS_FLAT}"

Quality Gates
    And I set quality gate min records to 50
    And I set filled percentage for "rubber" to 90
    And I set filled percentage for "speed" to 80
