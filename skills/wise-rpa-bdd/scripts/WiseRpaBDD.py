"""Generic no-op Robot Framework keyword library for strict BDD RPA suites.

This library is intentionally lightweight. It exists so drafted suites can be
validated with ``robot --dryrun`` and inspected with real keyword resolution.
"""

from __future__ import annotations

from typing import Any

from robot.api import logger
from robot.api.deco import keyword, library


@library(scope="SUITE", auto_keywords=False)
class WiseRpaBDD:
    def __init__(self) -> None:
        self.events: list[tuple[str, tuple[Any, ...]]] = []

    def _record(self, name: str, *values: Any) -> None:
        self.events.append((name, values))
        rendered = ", ".join(str(v) for v in values if v not in (None, ""))
        logger.info(f"{name}: {rendered}" if rendered else name)

    @keyword('Given I start deployment "${deployment}"')
    def start_deployment(self, deployment: str) -> None:
        self._record("start_deployment", deployment)

    @keyword("Then I finalize deployment")
    def finalize_deployment(self) -> None:
        self._record("finalize_deployment")

    @keyword('Given I register artifact "${artifact}"')
    def register_artifact(self, artifact: str, *fields: str) -> None:
        self._record("register_artifact", artifact, *fields)

    @keyword('And I set artifact options for "${artifact}"')
    def set_artifact_options(self, artifact: str, *options: str) -> None:
        self._record("set_artifact_options", artifact, *options)

    @keyword('Given I start resource "${resource}"')
    def start_resource(self, resource: str) -> None:
        self._record("start_resource", resource)

    @keyword('Given I start resource "${resource}" at "${entry}"')
    def start_resource_at(self, resource: str, entry: str) -> None:
        self._record("start_resource_at", resource, entry)

    @keyword('Given I consume artifact "${artifact}"')
    def consume_artifact(self, artifact: str) -> None:
        self._record("consume_artifact", artifact)

    @keyword('Given I resolve entry from "${reference}"')
    def resolve_entry_from(self, reference: str) -> None:
        self._record("resolve_entry_from", reference)

    @keyword('Given I iterate over parent records from "${parent_case}"')
    def iterate_over_parent_records(self, parent_case: str) -> None:
        self._record("iterate_over_parent_records", parent_case)

    @keyword("And I set resource globals")
    def set_resource_globals(self, *globals_: str) -> None:
        self._record("set_resource_globals", *globals_)

    @keyword('And I begin rule "${rule}"')
    def begin_rule(self, rule: str) -> None:
        self._record("begin_rule", rule)

    @keyword('And I declare parents "${parents}"')
    def declare_parents(self, parents: str) -> None:
        self._record("declare_parents", parents)

    @keyword('Given url contains "${pattern}"')
    def url_contains(self, pattern: str) -> None:
        self._record("url_contains", pattern)

    @keyword('Given url matches "${pattern}"')
    def url_matches(self, pattern: str) -> None:
        self._record("url_matches", pattern)

    @keyword('But url does not contain "${pattern}"')
    def url_does_not_contain(self, pattern: str) -> None:
        self._record("url_does_not_contain", pattern)

    @keyword('And selector "${selector}" exists')
    def selector_exists(self, selector: str) -> None:
        self._record("selector_exists", selector)

    @keyword('And table headers are "${headers}"')
    def table_headers_are(self, headers: str) -> None:
        self._record("table_headers_are", headers)

    @keyword('When I open "${url}"')
    def open_url(self, url: str) -> None:
        self._record("open_url", url)

    @keyword('When I open the bound field "${field}"')
    def open_bound_field(self, field: str) -> None:
        self._record("open_bound_field", field)

    @keyword('When I click locator "${locator}"')
    def click_locator(self, locator: str, *options: str) -> None:
        self._record("click_locator", locator, *options)

    @keyword('When I type "${value}" into locator "${locator}"')
    def type_into_locator(self, value: str, locator: str, *options: str) -> None:
        self._record("type_into_locator", value, locator, *options)

    @keyword('When I type secret "${value}" into locator "${locator}"')
    def type_secret_into_locator(self, value: str, locator: str, *options: str) -> None:
        self._record("type_secret_into_locator", "***", locator, *options)

    @keyword("When I scroll down")
    def scroll_down(self) -> None:
        self._record("scroll_down")

    @keyword("When I wait for idle")
    def wait_for_idle(self) -> None:
        self._record("wait_for_idle")

    @keyword("When I wait ${ms} ms")
    def wait_ms(self, ms: Any) -> None:
        self._record("wait_ms", ms)

    @keyword('When I expand over elements "${scope}"')
    def expand_over_elements(self, scope: str, *options: str) -> None:
        self._record("expand_over_elements", scope, *options)

    @keyword('When I expand over elements "${scope}" with order "${order}"')
    def expand_over_elements_with_order(self, scope: str, order: str, *options: str) -> None:
        self._record("expand_over_elements_with_order", scope, order, *options)

    @keyword('When I paginate by next button "${locator}" up to ${limit} pages')
    def paginate_by_next_button(self, locator: str, limit: Any, *options: str) -> None:
        self._record("paginate_by_next_button", locator, limit, *options)

    @keyword('When I paginate by numeric control "${locator}" from ${start} up to ${limit} pages')
    def paginate_by_numeric_control(self, locator: str, start: Any, limit: Any, *options: str) -> None:
        self._record("paginate_by_numeric_control", locator, start, limit, *options)

    @keyword("When I expand over combinations")
    def expand_over_combinations(self, *axes: str) -> None:
        self._record("expand_over_combinations", *axes)

    @keyword("Then I extract fields")
    def extract_fields(self, *specs: str) -> None:
        self._record("extract_fields", *specs)

    @keyword('Then I extract table "${name}" from "${locator}"')
    def extract_table(self, name: str, locator: str, *specs: str) -> None:
        self._record("extract_table", name, locator, *specs)

    @keyword('And I emit to artifact "${artifact}"')
    def emit_to_artifact(self, artifact: str) -> None:
        self._record("emit_to_artifact", artifact)

    @keyword('And I emit to artifact "${artifact}" flattened by "${field}"')
    def emit_to_artifact_flattened(self, artifact: str, field: str) -> None:
        self._record("emit_to_artifact_flattened", artifact, field)

    @keyword('And I merge into artifact "${artifact}" on key "${key}"')
    def merge_into_artifact(self, artifact: str, key: str) -> None:
        self._record("merge_into_artifact", artifact, key)

    @keyword('Then I write artifact "${artifact}" to "${path}"')
    def write_artifact(self, artifact: str, path: str) -> None:
        self._record("write_artifact", artifact, path)

    @keyword("And I set quality gate min records to ${count}")
    def set_quality_gate_min_records(self, count: Any) -> None:
        self._record("set_quality_gate_min_records", count)

    @keyword('And I set filled percentage for "${field}" to ${percent}')
    def set_filled_percentage(self, field: str, percent: Any) -> None:
        self._record("set_filled_percentage", field, percent)

    @keyword('Then I extract with AI "${name}"')
    def extract_with_ai(self, name: str, *specs: str) -> None:
        self._record("extract_with_ai", name, *specs)

    @keyword('And I register hook "${name}" at "${lifecycle_point}"')
    def register_hook(self, name: str, lifecycle_point: str, *config: str) -> None:
        self._record("register_hook", name, lifecycle_point, *config)

    @keyword("Given I configure state setup")
    def configure_state_setup(self, *actions: str) -> None:
        self._record("configure_state_setup", *actions)

    @keyword("And I configure interrupts")
    def configure_interrupts(self, *dismissals: str) -> None:
        self._record("configure_interrupts", *dismissals)

    @keyword('When I select "${value}" from locator "${locator}"')
    def select_from_locator(self, value: str, locator: str, *options: str) -> None:
        self._record("select_from_locator", value, locator, *options)

    @keyword('When I check locator "${locator}"')
    def check_locator(self, locator: str, *options: str) -> None:
        self._record("check_locator", locator, *options)

    @keyword('And I set max failed percentage to ${percent}')
    def set_max_failed_percentage(self, percent: Any) -> None:
        self._record("set_max_failed_percentage", percent)

    @keyword("Then I close the browser")
    def close_browser(self) -> None:
        self._record("close_browser")
