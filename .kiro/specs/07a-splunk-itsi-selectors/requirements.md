# Splunk-ITSI Selector Fix

## Problem
The extract resources in `tests/golden/splunk-itsi-focused-test.robot` navigate
to Splunk help pages but the state check `selector "article[role='article']" exists`
fails on many pages, producing 0 extracted records.

## Task
1. Open https://help.splunk.com/en/splunk-it-service-intelligence/splunk-it-service-intelligence/discover-and-integrate-it-components/4.21/get-started/what-is-an-entity-integration in a browser
2. Find the correct CSS selector for the main content area (the old `article[role='article']` may be stale)
3. Find the correct selector for the page title (currently `h1.title`)
4. Update both extract test cases in `tests/golden/splunk-itsi-focused-test.robot` with working selectors
5. Run: `cd skills/wise-rpa-bdd && PYTHONPATH=scripts uv run robot --outputdir /tmp/ralph-splunk tests/golden/splunk-itsi-focused-test.robot`
6. Verify: "Wrote N records" appears in the output with N > 0
7. Commit the fix

## Accept when
- `splunk-itsi-focused-test.robot` produces > 0 records for both entity and events extracts
- The selectors used are semantic (not fragile CSS class hashes)
