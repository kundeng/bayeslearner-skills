*** Settings ***
Documentation     Example multi-resource documentation crawl suite
Library           WiseRpaBDD
Suite Setup       Given I start deployment "${DEPLOYMENT}"
Suite Teardown    Then I finalize deployment

*** Variables ***
${DEPLOYMENT}    splunk-itsi-docs
${ARTIFACT_ITSI_PAGES_NESTED}    itsi_pages_nested
${ARTIFACT_ITSI_PAGES_FLAT}    itsi_pages_flat
${ENTRY_DISCOVER_INSTALL}    https://help.splunk.com/en/splunk-it-service-intelligence/splunk-it-service-intelligence/install-and-upgrade/4.21/introduction/about-splunk-it-service-intelligence
${ENTRY_DISCOVER_ADMINISTER}    https://help.splunk.com/en/splunk-it-service-intelligence/splunk-it-service-intelligence/administer
${ENTRY_DISCOVER_INTEGRATE}    https://help.splunk.com/en/splunk-it-service-intelligence/splunk-it-service-intelligence/discover-and-integrate-it-components
${ENTRY_DISCOVER_DETECT}    https://help.splunk.com/en/splunk-it-service-intelligence/splunk-it-service-intelligence/detect-and-act-on-notable-events
${ENTRY_DISCOVER_VISUALIZE}    https://help.splunk.com/en/splunk-it-service-intelligence/splunk-it-service-intelligence/visualize-and-assess-service-health
${ENTRY_DISCOVER_INSIGHTS}    https://help.splunk.com/en/splunk-it-service-intelligence/splunk-it-service-intelligence/reduce-time-to-insights
${ENTRY_DISCOVER_RESTAPI}    https://help.splunk.com/en/splunk-it-service-intelligence/splunk-it-service-intelligence/leverage-rest-apis
${ENTRY_DISCOVER_RELEASENOTES}    https://help.splunk.com/en/splunk-it-service-intelligence/splunk-it-service-intelligence/release-notes-and-resources
${ENTRY_DISCOVER_CHOOSE}    https://help.splunk.com/en/splunk-it-service-intelligence/splunk-it-service-intelligence/choose-an-it-monitoring-app

*** Test Cases ***
Artifact Catalog
    Given I register artifact "${ARTIFACT_ITSI_PAGES_NESTED}"
    ...    field=title    type=string    required=true
    ...    field=body    type=string    required=true
    And I set artifact options for "${ARTIFACT_ITSI_PAGES_NESTED}"
    ...    format=json
    ...    output=true
    ...    structure=nested
    ...    dedupe=title
    ...    description=ITSI documentation pages as nested tree records
    Given I register artifact "${ARTIFACT_ITSI_PAGES_FLAT}"
    ...    field=title    type=string    required=true
    ...    field=body    type=string    required=true
    And I set artifact options for "${ARTIFACT_ITSI_PAGES_FLAT}"
    ...    format=markdown
    ...    output=true
    ...    structure=flat
    ...    dedupe=title
    ...    description=ITSI documentation pages as flat denormalized records

Resource discover_install
    [Setup]    Given I start resource "discover_install" at "${ENTRY_DISCOVER_INSTALL}"
    And I set resource globals
    ...    timeout_ms=30000
    ...    retries=2
    And I begin rule "toc"
    And selector "nav a[href*='/install-and-upgrade/']" exists
    When I expand over elements "nav a[href*='/install-and-upgrade/4.21/']:not([href*='%'])" with order "bfs"
    Then I extract fields
    ...    field=url    extractor=link    locator="nav a[href*='/install-and-upgrade/4.21/']"
    ...    field=title    extractor=text    locator="nav a[href*='/install-and-upgrade/4.21/']"

Resource discover_administer
    [Setup]    Given I start resource "discover_administer" at "${ENTRY_DISCOVER_ADMINISTER}"
    And I set resource globals
    ...    timeout_ms=30000
    ...    retries=2
    And I begin rule "toc"
    And selector "nav a[href*='/administer/']" exists
    When I expand over elements "nav a[href*='/administer/4.21/']:not([href*='%'])" with order "bfs"
    Then I extract fields
    ...    field=url    extractor=link    locator="nav a[href*='/administer/4.21/']"
    ...    field=title    extractor=text    locator="nav a[href*='/administer/4.21/']"

Resource discover_integrate
    [Setup]    Given I start resource "discover_integrate" at "${ENTRY_DISCOVER_INTEGRATE}"
    And I set resource globals
    ...    timeout_ms=30000
    ...    retries=2
    And I begin rule "toc"
    And selector "nav a[href*='/discover-and-integrate-it-components/']" exists
    When I expand over elements "nav a[href*='/discover-and-integrate-it-components/4.21/']:not([href*='%'])" with order "bfs"
    Then I extract fields
    ...    field=url    extractor=link    locator="nav a[href*='/discover-and-integrate-it-components/4.21/']"
    ...    field=title    extractor=text    locator="nav a[href*='/discover-and-integrate-it-components/4.21/']"

Resource discover_detect
    [Setup]    Given I start resource "discover_detect" at "${ENTRY_DISCOVER_DETECT}"
    And I set resource globals
    ...    timeout_ms=30000
    ...    retries=2
    And I begin rule "toc"
    And selector "nav a[href*='/detect-and-act-on-notable-events/']" exists
    When I expand over elements "nav a[href*='/detect-and-act-on-notable-events/4.21/']:not([href*='%'])" with order "bfs"
    Then I extract fields
    ...    field=url    extractor=link    locator="nav a[href*='/detect-and-act-on-notable-events/4.21/']"
    ...    field=title    extractor=text    locator="nav a[href*='/detect-and-act-on-notable-events/4.21/']"

Resource discover_visualize
    [Setup]    Given I start resource "discover_visualize" at "${ENTRY_DISCOVER_VISUALIZE}"
    And I set resource globals
    ...    timeout_ms=30000
    ...    retries=2
    And I begin rule "toc"
    And selector "nav a[href*='/visualize-and-assess-service-health/']" exists
    When I expand over elements "nav a[href*='/visualize-and-assess-service-health/4.21/']:not([href*='%'])" with order "bfs"
    Then I extract fields
    ...    field=url    extractor=link    locator="nav a[href*='/visualize-and-assess-service-health/4.21/']"
    ...    field=title    extractor=text    locator="nav a[href*='/visualize-and-assess-service-health/4.21/']"

Resource discover_insights
    [Setup]    Given I start resource "discover_insights" at "${ENTRY_DISCOVER_INSIGHTS}"
    And I set resource globals
    ...    timeout_ms=30000
    ...    retries=2
    And I begin rule "toc"
    And selector "nav a[href*='/reduce-time-to-insights/']" exists
    When I expand over elements "nav a[href*='/reduce-time-to-insights/4.21/']:not([href*='%'])" with order "bfs"
    Then I extract fields
    ...    field=url    extractor=link    locator="nav a[href*='/reduce-time-to-insights/4.21/']"
    ...    field=title    extractor=text    locator="nav a[href*='/reduce-time-to-insights/4.21/']"

Resource discover_restapi
    [Setup]    Given I start resource "discover_restapi" at "${ENTRY_DISCOVER_RESTAPI}"
    And I set resource globals
    ...    timeout_ms=30000
    ...    retries=2
    And I begin rule "toc"
    And selector "nav a[href*='/leverage-rest-apis/']" exists
    When I expand over elements "nav a[href*='/leverage-rest-apis/4.21/']:not([href*='%'])" with order "bfs"
    Then I extract fields
    ...    field=url    extractor=link    locator="nav a[href*='/leverage-rest-apis/4.21/']"
    ...    field=title    extractor=text    locator="nav a[href*='/leverage-rest-apis/4.21/']"

Resource discover_releasenotes
    [Setup]    Given I start resource "discover_releasenotes" at "${ENTRY_DISCOVER_RELEASENOTES}"
    And I set resource globals
    ...    timeout_ms=30000
    ...    retries=2
    And I begin rule "toc"
    And selector "nav a[href*='/release-notes-and-resources/']" exists
    When I expand over elements "nav a[href*='/release-notes-and-resources/4.21/']:not([href*='%'])" with order "bfs"
    Then I extract fields
    ...    field=url    extractor=link    locator="nav a[href*='/release-notes-and-resources/4.21/']"
    ...    field=title    extractor=text    locator="nav a[href*='/release-notes-and-resources/4.21/']"

Resource discover_choose
    [Setup]    Given I start resource "discover_choose" at "${ENTRY_DISCOVER_CHOOSE}"
    And I set resource globals
    ...    timeout_ms=30000
    ...    retries=2
    And I begin rule "toc"
    And selector "nav a[href*='/choose-an-it-monitoring-app/']" exists
    When I expand over elements "nav a[href*='/choose-an-it-monitoring-app/']:not([href*='%'])" with order "bfs"
    Then I extract fields
    ...    field=url    extractor=link    locator="nav a[href*='/choose-an-it-monitoring-app/']"
    ...    field=title    extractor=text    locator="nav a[href*='/choose-an-it-monitoring-app/']"

Resource extract_install_pages
    [Documentation]    Produces: ['itsi_pages_nested', 'itsi_pages_flat']
    [Setup]    Given I start resource "extract_install_pages"
    Given I resolve entry from "discover_install.toc.url"
    And I set resource globals
    ...    timeout_ms=30000
    ...    page_load_delay_ms=2000
    And I begin rule "page"
    And selector "h1" exists
    Then I extract fields
    ...    field=title    extractor=text    locator="h1"
    ...    field=body    extractor=html    locator="article"
    And I emit to artifact "${ARTIFACT_ITSI_PAGES_NESTED}"
    And I emit to artifact "${ARTIFACT_ITSI_PAGES_FLAT}"

Resource extract_administer_pages
    [Documentation]    Produces: ['itsi_pages_nested', 'itsi_pages_flat']
    [Setup]    Given I start resource "extract_administer_pages"
    Given I resolve entry from "discover_administer.toc.url"
    And I set resource globals
    ...    timeout_ms=30000
    ...    page_load_delay_ms=2000
    And I begin rule "page"
    And selector "h1" exists
    Then I extract fields
    ...    field=title    extractor=text    locator="h1"
    ...    field=body    extractor=html    locator="article"
    And I emit to artifact "${ARTIFACT_ITSI_PAGES_NESTED}"
    And I emit to artifact "${ARTIFACT_ITSI_PAGES_FLAT}"

Resource extract_integrate_pages
    [Documentation]    Produces: ['itsi_pages_nested', 'itsi_pages_flat']
    [Setup]    Given I start resource "extract_integrate_pages"
    Given I resolve entry from "discover_integrate.toc.url"
    And I set resource globals
    ...    timeout_ms=30000
    ...    page_load_delay_ms=2000
    And I begin rule "page"
    And selector "h1" exists
    Then I extract fields
    ...    field=title    extractor=text    locator="h1"
    ...    field=body    extractor=html    locator="article"
    And I emit to artifact "${ARTIFACT_ITSI_PAGES_NESTED}"
    And I emit to artifact "${ARTIFACT_ITSI_PAGES_FLAT}"

Resource extract_detect_pages
    [Documentation]    Produces: ['itsi_pages_nested', 'itsi_pages_flat']
    [Setup]    Given I start resource "extract_detect_pages"
    Given I resolve entry from "discover_detect.toc.url"
    And I set resource globals
    ...    timeout_ms=30000
    ...    page_load_delay_ms=2000
    And I begin rule "page"
    And selector "h1" exists
    Then I extract fields
    ...    field=title    extractor=text    locator="h1"
    ...    field=body    extractor=html    locator="article"
    And I emit to artifact "${ARTIFACT_ITSI_PAGES_NESTED}"
    And I emit to artifact "${ARTIFACT_ITSI_PAGES_FLAT}"

Resource extract_visualize_pages
    [Documentation]    Produces: ['itsi_pages_nested', 'itsi_pages_flat']
    [Setup]    Given I start resource "extract_visualize_pages"
    Given I resolve entry from "discover_visualize.toc.url"
    And I set resource globals
    ...    timeout_ms=30000
    ...    page_load_delay_ms=2000
    And I begin rule "page"
    And selector "h1" exists
    Then I extract fields
    ...    field=title    extractor=text    locator="h1"
    ...    field=body    extractor=html    locator="article"
    And I emit to artifact "${ARTIFACT_ITSI_PAGES_NESTED}"
    And I emit to artifact "${ARTIFACT_ITSI_PAGES_FLAT}"

Resource extract_insights_pages
    [Documentation]    Produces: ['itsi_pages_nested', 'itsi_pages_flat']
    [Setup]    Given I start resource "extract_insights_pages"
    Given I resolve entry from "discover_insights.toc.url"
    And I set resource globals
    ...    timeout_ms=30000
    ...    page_load_delay_ms=2000
    And I begin rule "page"
    And selector "h1" exists
    Then I extract fields
    ...    field=title    extractor=text    locator="h1"
    ...    field=body    extractor=html    locator="article"
    And I emit to artifact "${ARTIFACT_ITSI_PAGES_NESTED}"
    And I emit to artifact "${ARTIFACT_ITSI_PAGES_FLAT}"

Resource extract_restapi_pages
    [Documentation]    Produces: ['itsi_pages_nested', 'itsi_pages_flat']
    [Setup]    Given I start resource "extract_restapi_pages"
    Given I resolve entry from "discover_restapi.toc.url"
    And I set resource globals
    ...    timeout_ms=30000
    ...    page_load_delay_ms=2000
    And I begin rule "page"
    And selector "h1" exists
    Then I extract fields
    ...    field=title    extractor=text    locator="h1"
    ...    field=body    extractor=html    locator="article"
    And I emit to artifact "${ARTIFACT_ITSI_PAGES_NESTED}"
    And I emit to artifact "${ARTIFACT_ITSI_PAGES_FLAT}"

Resource extract_releasenotes_pages
    [Documentation]    Produces: ['itsi_pages_nested', 'itsi_pages_flat']
    [Setup]    Given I start resource "extract_releasenotes_pages"
    Given I resolve entry from "discover_releasenotes.toc.url"
    And I set resource globals
    ...    timeout_ms=30000
    ...    page_load_delay_ms=2000
    And I begin rule "page"
    And selector "h1" exists
    Then I extract fields
    ...    field=title    extractor=text    locator="h1"
    ...    field=body    extractor=html    locator="article"
    And I emit to artifact "${ARTIFACT_ITSI_PAGES_NESTED}"
    And I emit to artifact "${ARTIFACT_ITSI_PAGES_FLAT}"

Resource extract_choose_pages
    [Documentation]    Produces: ['itsi_pages_nested', 'itsi_pages_flat']
    [Setup]    Given I start resource "extract_choose_pages"
    Given I resolve entry from "discover_choose.toc.url"
    And I set resource globals
    ...    timeout_ms=30000
    ...    page_load_delay_ms=2000
    And I begin rule "page"
    And selector "h1" exists
    Then I extract fields
    ...    field=title    extractor=text    locator="h1"
    ...    field=body    extractor=html    locator="article"
    And I emit to artifact "${ARTIFACT_ITSI_PAGES_NESTED}"
    And I emit to artifact "${ARTIFACT_ITSI_PAGES_FLAT}"

Quality Gates
    And I set quality gate min records to 150
