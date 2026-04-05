---
name: e2e-testing
description: Design and implement end-to-end tests using BDD/Gherkin scenarios and browser automation. Use this skill when the user wants to write E2E tests, define user journeys, create acceptance tests for a web app, set up browser testing infrastructure, or convert requirements into executable Gherkin scenarios. Also use when the user asks about testing strategy, wants to add E2E tests to an existing project, or mentions Cucumber, BDD, Gherkin, Playwright, Cypress, or browser testing.
---

# E2E Testing with BDD + Browser Automation

Design user journey scenarios in Gherkin, implement them with browser automation, and run them as part of the test suite.

## When to Use This Skill

- Project has a web UI or REST API that needs acceptance testing
- User wants to define "user journeys" or "acceptance criteria"
- Features are integrated and ready for E2E validation
- User mentions Cucumber, BDD, Gherkin, Playwright, Cypress, or browser testing

## Core Approach

**Gherkin scenarios are the spec. Browser automation is the implementation.**

```
User journeys → .feature files (Gherkin) → step definitions (browser automation) → test runner
```

This is NOT a separate testing phase bolted on at the end. E2E tests are written alongside implementation, just like unit tests. The difference is timing — E2E tests make sense after features are integrated, not while building individual components.

## Choosing Your Toolchain

Pick based on what the project already uses:

| Stack | Recommended toolchain | Why |
|-------|----------------------|-----|
| Python backend, minimal frontend | **pytest-bdd + Playwright (Python)** | One test runner, shares fixtures with unit tests |
| React/TypeScript frontend | **Playwright Test (JS/TS)** or **Cypress** | Tests share types, selectors, and utilities with app code |
| Token-constrained AI agent | **agent-browser** (accessibility-snapshot based) | Uses element refs (`@e1`, `@e2`) instead of full DOM — much cheaper on tokens than screenshot-based approaches |
| API-only (no browser) | **pytest-bdd + httpx** | Same Gherkin pattern, no browser needed |

**When to use JavaScript test frameworks:**
If the frontend is React/TypeScript, consider Playwright Test (TS) or Cypress because:
- Test code can import app components, types, and constants directly
- Selectors stay in sync with the component tree
- Same CI toolchain (Node, npm scripts) — no Python/Node split
- Cypress has built-in component testing for React

**When to use Python Playwright:**
If the backend is Python and the frontend is simple, or you want one unified test runner for unit + integration + E2E tests under pytest.

**When to use agent-browser for UAT:**
For AI-driven exploratory acceptance testing, `agent-browser` is token-efficient because it works with accessibility snapshots rather than screenshots or full DOM dumps. Good for user acceptance testing (UAT) where you want an agent to navigate the app like a user and report issues. Not a replacement for structured Gherkin tests — use it alongside them.

## Project Setup (Python + pytest-bdd)

### Dependencies

```toml
# pyproject.toml — add to dev dependencies
[project.optional-dependencies]
e2e = [
    "pytest-bdd>=8.0",
    "playwright>=1.49",
    "pytest-playwright>=0.6",
]
```

```bash
uv sync --extra e2e
playwright install chromium
```

### Directory Structure

```
tests/
  e2e/
    features/           # Gherkin .feature files (the specs)
      login.feature
      checkout.feature
    step_defs/          # Step implementations (Playwright code)
      conftest.py       # Shared fixtures: browser, page, server lifecycle
      test_login.py     # Steps for login.feature
      test_checkout.py  # Steps for checkout.feature
    pages/              # Page Object Model (optional, for complex UIs)
      login_page.py
      dashboard_page.py
    screenshots/        # Failure screenshots (gitignored)
```

### conftest.py Template

```python
"""Shared fixtures for E2E tests."""
import subprocess
import time
from typing import Generator

import pytest
from playwright.sync_api import Page


@pytest.fixture(scope="session")
def app_server() -> Generator[str, None, None]:
    """Start the application server for the test session."""
    proc = subprocess.Popen(
        ["your-app", "serve", "--port", "18080"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    time.sleep(3)  # wait for startup
    yield "http://localhost:18080"
    proc.terminate()
    proc.wait()


@pytest.fixture
def authenticated_page(page: Page, app_server: str) -> Page:
    """A page that's already logged in."""
    page.goto(f"{app_server}/login")
    page.fill("[data-testid=username]", "admin")
    page.fill("[data-testid=password]", "admin123")
    page.click("[data-testid=submit]")
    page.wait_for_url(f"{app_server}/dashboard")
    return page
```

## Writing Gherkin Scenarios

### Structure

Each `.feature` file represents a user-facing capability. Scenarios are concrete examples of that capability.

```gherkin
Feature: Shopping Cart
  As a customer
  I want to manage items in my cart
  So that I can purchase what I need

  Background:
    Given I am logged in as a customer
    And the product catalog is loaded

  Scenario: Add item to cart
    When I search for "wireless mouse"
    And I click "Add to Cart" on the first result
    Then the cart badge should show "1"
    And the cart should contain "wireless mouse"

  Scenario: Remove item from cart
    Given my cart contains "wireless mouse"
    When I open the cart
    And I click "Remove" on "wireless mouse"
    Then the cart should be empty

  Scenario Outline: Quantity limits
    Given my cart contains "<product>"
    When I set the quantity to <qty>
    Then the quantity should be <expected>

    Examples:
      | product        | qty | expected |
      | wireless mouse | 0   | 1        |
      | wireless mouse | 99  | 99       |
      | wireless mouse | 100 | 99       |
```

### Scenario Design Principles

1. **Write from the user's perspective** — "I navigate to", "I should see", not "the DOM contains div.class"
2. **One journey per scenario** — don't test everything in one scenario
3. **Background for shared setup** — login, navigation, data seeding
4. **Scenario Outline for data-driven** — same journey, different inputs
5. **Keep scenarios independent** — each can run alone, no ordering dependency

### What Makes a Good Scenario

```gherkin
# GOOD — user perspective, clear intent
Scenario: Admin creates a new simulation
  Given I am logged in as admin
  When I navigate to "Data Inputs > SimData"
  And I click "New Simulation"
  And I upload "hello.simulation" and "hello.json"
  And I click "Start"
  Then I should see "Simulation running" within 10 seconds
  And the event count should start increasing

# BAD — implementation detail, fragile
Scenario: Test simulation creation
  When I POST to /api/simulations with JSON body
  And the response code is 201
  And I GET /api/simulations/1/status
  Then the JSON field "state" equals "running"
```

## Implementing Step Definitions

### Basic Pattern

```python
"""tests/e2e/step_defs/test_simulation.py"""
from pytest_bdd import scenarios, given, when, then, parsers
from playwright.sync_api import Page, expect

# Link to .feature file
scenarios("../features/simulation.feature")


@given("I am logged in as admin")
def logged_in(authenticated_page: Page) -> Page:
    return authenticated_page


@when(parsers.parse('I navigate to "{path}"'))
def navigate(page: Page, app_server: str, path: str) -> None:
    page.goto(f"{app_server}/{path}")


@when(parsers.parse('I click "{text}"'))
def click_button(page: Page, text: str) -> None:
    page.get_by_role("button", name=text).click()


@then(parsers.parse('I should see "{text}" within {seconds:d} seconds'))
def see_text(page: Page, text: str, seconds: int) -> None:
    expect(page.get_by_text(text)).to_be_visible(timeout=seconds * 1000)
```

### CLI Testing (no browser)

```python
"""E2E tests for CLI tools — no Playwright needed."""
import subprocess

from pytest_bdd import scenarios, given, when, then, parsers

scenarios("../features/cli.feature")


@when(parsers.parse('I run "{command}"'))
def run_command(command: str, tmp_path) -> dict:
    result = subprocess.run(
        command.split(), capture_output=True, text=True, cwd=tmp_path
    )
    return {"stdout": result.stdout, "stderr": result.stderr, "code": result.returncode}


@then("the process should start successfully")
def check_success(run_command: dict) -> None:
    assert run_command["code"] == 0, f"stderr: {run_command['stderr']}"
```

### Screenshots on Failure

```python
# conftest.py — auto-screenshot on test failure
@pytest.fixture(autouse=True)
def screenshot_on_failure(request, page: Page) -> Generator[None, None, None]:
    yield
    if request.node.rep_call and request.node.rep_call.failed:
        name = request.node.name.replace("/", "_")
        page.screenshot(path=f"tests/e2e/screenshots/{name}.png")
```

## Running E2E Tests

```bash
# Run all E2E tests
uv run pytest tests/e2e/ -v

# Run a specific feature
uv run pytest tests/e2e/ -v -k "simulation"

# Run with headed browser (for debugging)
uv run pytest tests/e2e/ -v --headed

# Run with slow motion (for demos)
uv run pytest tests/e2e/ -v --headed --slowmo 500

# Generate HTML report
uv run pytest tests/e2e/ -v --html=tests/e2e/report.html
```

## Integration with Ralph Loops

E2E tests are NOT a separate hat. They are tasks that the **builder writes** when the planner decides features are ready for E2E validation. Include in PROMPT.md:

```
After implementing the control panel UI:
- Write Gherkin scenarios in tests/e2e/features/control_panel.feature
- Implement step definitions with Playwright in tests/e2e/step_defs/
- Run tests and fix failures before committing
```

The **planner** designs which user journeys need testing (writes or references `.feature` files). The **builder** implements the step definitions and page objects. The **reviewer** runs the full E2E suite as part of verification.

## JavaScript/TypeScript Alternative (React Projects)

When the frontend is React/TypeScript, consider staying in the JS ecosystem:

### Playwright Test (TypeScript)

```bash
npm init playwright@latest
```

```
tests/
  e2e/
    fixtures/           # Custom fixtures (authenticated page, test data)
    pages/              # Page Object classes (TypeScript)
    specs/              # Test specs
      control-panel.spec.ts
```

```typescript
// control-panel.spec.ts
import { test, expect } from '@playwright/test';

test('adjust entity variable via slider', async ({ page }) => {
  await page.goto('http://localhost:5173');
  await page.getByRole('tab', { name: 'Controls' }).click();
  await page.getByLabel('rate').fill('50');
  // Verify REST API received the update
  const response = await page.request.get('http://localhost:8080/tree?stats=true');
  const tree = await response.json();
  expect(tree.entities[0].variables.rate).toBe(50);
});
```

Playwright Test supports Gherkin via `playwright-bdd`:
```bash
npm install -D playwright-bdd
```

### Cypress

Better for component-level testing of React components. Use when you need to test components in isolation before full E2E.

```bash
npm install -D cypress
npx cypress open
```

## Agent-Driven UAT with agent-browser

For AI-driven exploratory acceptance testing, `agent-browser` uses accessibility snapshots instead of screenshots — much cheaper on tokens. Good for:

- Smoke testing after deployment ("navigate the app, report anything broken")
- Accessibility audits ("can a screen reader navigate the checkout flow?")
- Exploratory testing ("find edge cases in the admin panel")

Not a replacement for structured Gherkin tests. Use it alongside them for UAT coverage.

```bash
# AI agent can drive this directly
agent-browser navigate "http://localhost:5173"
agent-browser click @e3    # click element by accessibility ref
agent-browser snapshot     # get accessibility tree (token-efficient)
```

## Adapting to a New Project

1. **Choose your toolchain** based on the project stack (see "Choosing Your Toolchain" above)
2. Write your first `.feature` file from user journeys — start with the happy path
3. Set up the server lifecycle fixture (how to start/stop the app under test)
4. Implement step definitions — one file per feature
5. Add `tests/e2e/screenshots/` to `.gitignore`
6. Wire into CI — E2E tests run after unit/integration tests pass

## Notes

- Playwright over Selenium — faster, auto-waits, better error messages, built-in assertions
- pytest-bdd over behave — integrates with pytest fixtures, no separate runner needed
- Playwright Test (TS) over Cypress — when you need multi-browser support or network interception
- Cypress over Playwright Test — when you need component testing or prefer its interactive runner
- Page Object Model is optional — use it when you have 5+ pages or shared interaction patterns
- Keep `.feature` files in version control — they ARE the spec
- Screenshots directory is gitignored — only useful for debugging failures
- For API-only testing (no browser), the same Gherkin pattern works with `httpx` instead of Playwright
- For token-constrained AI testing, prefer accessibility snapshots over screenshots
