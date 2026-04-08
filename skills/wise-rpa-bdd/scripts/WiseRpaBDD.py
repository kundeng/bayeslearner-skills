"""Robot Framework keyword library for BDD RPA suites.

Keywords build a declarative rule tree during test execution. The Suite Teardown
(finalize_deployment) walks the tree using robotframework-browser (RF's Playwright
wrapper) to scrape data.

Architecture: Plan-then-Execute (deferred execution model).
- Phase A: RF keywords called sequentially build an in-memory scraping plan.
- Phase B: finalize_deployment executes the plan via robotframework-browser keywords.

This is necessary because RF keywords are called once each in sequence, but the
scraping logic requires nested loops (pagination x element expansion x extraction).
"""

from __future__ import annotations

import json
import os
import re
import time
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from robot.api import logger
from robot.api.deco import keyword, library


# ---------------------------------------------------------------------------
# Data structures for the rule tree
# ---------------------------------------------------------------------------

@dataclass
class FieldSpec:
    name: str
    extractor: str  # text, attr, grouped, html, link, image
    locator: str
    attr: str | None = None


@dataclass
class TableFieldSpec:
    name: str
    header: str


@dataclass
class TableSpec:
    name: str
    locator: str
    header_row: int = 0
    fields: list[TableFieldSpec] = field(default_factory=list)


@dataclass
class StateCheck:
    type: str  # url_matches, url_contains, url_not_contains, selector_exists, table_headers
    pattern: str


@dataclass
class Action:
    type: str  # click, type, select, scroll, wait, wait_ms, open, open_bound
    locator: str | None = None
    value: str | None = None
    options: dict = field(default_factory=dict)


@dataclass
class CombinationAxis:
    action: str  # type, select, click
    control: str  # CSS selector
    values: list[str] = field(default_factory=list)


@dataclass
class Expansion:
    over: str  # elements, pages_next, pages_numeric, combinations
    scope: str | None = None
    locator: str | None = None
    limit: int = 100
    start: int = 1
    order: str = "dfs"
    options: dict = field(default_factory=dict)
    axes: list[CombinationAxis] = field(default_factory=list)


@dataclass
class RuleNode:
    name: str
    parents: list[str] = field(default_factory=list)
    state_checks: list[StateCheck] = field(default_factory=list)
    actions: list[Action] = field(default_factory=list)
    expansion: Expansion | None = None
    field_specs: list[FieldSpec] = field(default_factory=list)
    table_spec: TableSpec | None = None
    ai_extraction: dict | None = None
    emit_targets: list[str] = field(default_factory=list)
    emit_flatten_by: dict[str, str] = field(default_factory=dict)
    emit_merge_on: dict[str, str] = field(default_factory=dict)
    children: list[RuleNode] = field(default_factory=list)
    retry_max: int = 0
    retry_delay_ms: int = 1000


@dataclass
class ArtifactSchema:
    name: str
    fields: list[dict] = field(default_factory=list)
    output: bool = False
    format: str = "json"  # json, jsonl, csv, markdown
    structure: str = "flat"  # nested or flat
    dedupe: str | None = None
    query: str | None = None
    consumes: str | None = None
    description: str = ""


@dataclass
class QualityGate:
    min_records: int | None = None
    filled_pcts: dict[str, float] = field(default_factory=dict)
    max_failed_pct: float | None = None


@dataclass
class ResourceContext:
    name: str
    entry_url: str = ""
    globals_: dict = field(default_factory=dict)
    rules: dict[str, RuleNode] = field(default_factory=dict)
    root_names: list[str] = field(default_factory=list)
    consumes: str | None = None
    entry_template: str | None = None
    iterates_parent: str | None = None


@dataclass
class HookDef:
    name: str
    lifecycle_point: str  # post_discover, pre_extract, post_extract, pre_assemble, post_assemble
    config: dict[str, str] = field(default_factory=dict)


@dataclass
class SetupAction:
    action: str  # open, input, password, click
    css: str = ""
    url: str = ""
    value: str = ""


@dataclass
class DeploymentContext:
    name: str
    artifacts: dict[str, ArtifactSchema] = field(default_factory=dict)
    artifact_store: dict[str, list] = field(default_factory=dict)
    resources: list[ResourceContext] = field(default_factory=list)
    quality_gate: QualityGate = field(default_factory=QualityGate)
    output_dir: str = ""
    write_overrides: dict[str, str] = field(default_factory=dict)
    hooks: list[HookDef] = field(default_factory=list)
    setup_actions: list[SetupAction] = field(default_factory=list)
    setup_skip_when: str = ""
    interrupt_selectors: list[str] = field(default_factory=list)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _parse_options(options: tuple[str, ...]) -> dict[str, str]:
    """Parse key=value option strings into a dict."""
    result = {}
    for opt in options:
        if "=" in opt:
            k, v = opt.split("=", 1)
            result[k] = _strip_quotes(v)
    return result


def _strip_quotes(s: str) -> str:
    """Strip surrounding double or single quotes from a value."""
    if len(s) >= 2 and s[0] == s[-1] and s[0] in ('"', "'"):
        return s[1:-1]
    return s


def _parse_field_specs(specs: tuple[str, ...]) -> list[FieldSpec]:
    """Parse field=X extractor=Y locator=Z attr=A sequences."""
    fields = []
    current: dict[str, str] = {}
    for spec in specs:
        if "=" not in spec:
            continue
        k, v = spec.split("=", 1)
        if k == "field" and current.get("field"):
            attr = current.get("attr")
            fields.append(FieldSpec(
                name=current["field"],
                extractor=current.get("extractor", "text"),
                locator=_strip_quotes(current.get("locator", "")),
                attr=_strip_quotes(attr) if attr else None,
            ))
            current = {}
        current[k] = v
    if current.get("field"):
        attr = current.get("attr")
        fields.append(FieldSpec(
            name=current["field"],
            extractor=current.get("extractor", "text"),
            locator=_strip_quotes(current.get("locator", "")),
            attr=_strip_quotes(attr) if attr else None,
        ))
    return fields


def _parse_table_specs(specs: tuple[str, ...]) -> tuple[int, list[TableFieldSpec]]:
    """Parse header_row=N field=X header=Y sequences."""
    header_row = 0
    fields = []
    current: dict[str, str] = {}
    for spec in specs:
        if "=" not in spec:
            continue
        k, v = spec.split("=", 1)
        if k == "header_row":
            header_row = int(v)
            continue
        if k == "field" and current.get("field"):
            fields.append(TableFieldSpec(
                name=current["field"],
                header=_strip_quotes(current.get("header", current["field"])),
            ))
            current = {}
        current[k] = v
    if current.get("field"):
        fields.append(TableFieldSpec(
            name=current["field"],
            header=_strip_quotes(current.get("header", current["field"])),
        ))
    return header_row, fields


# ---------------------------------------------------------------------------
# Execution engine (uses robotframework-browser)
# ---------------------------------------------------------------------------

class ExecutionEngine:
    """Walks the rule tree using robotframework-browser keywords."""

    def __init__(self, ctx: DeploymentContext, headed: bool = False):
        self.ctx = ctx
        self.headed = headed
        self._browser_lib = None

    def _bl(self):
        """Get the Browser library instance from RF."""
        if self._browser_lib is None:
            from robot.libraries.BuiltIn import BuiltIn
            self._browser_lib = BuiltIn().get_library_instance('Browser')
        return self._browser_lib

    def run(self) -> None:
        output_dir = self.ctx.output_dir or f"output/{self.ctx.name}"
        os.makedirs(output_dir, exist_ok=True)

        bl = self._bl()
        bl.new_browser(headless=not self.headed)

        try:
            self._execute_resources()
            self._write_outputs(output_dir)
            self._check_quality_gates()
        finally:
            bl.close_browser("ALL")

    def _execute_resources(self) -> None:
        """Execute resources in topological order based on artifact dependencies."""
        resources = self.ctx.resources
        if not resources:
            return

        # Build maps: which artifacts each resource produces and consumes
        res_produces: dict[str, set[str]] = {}  # resource name → artifact names
        res_consumes: dict[str, set[str]] = {}  # resource name → artifact names
        art_producer: dict[str, str] = {}       # artifact name → resource name

        for res in resources:
            produces = set()
            consumes = set()
            # Collect all emit targets from rules
            for rule in res.rules.values():
                for target in rule.emit_targets:
                    produces.add(target)
            # Collect consumption edges
            if res.consumes:
                consumes.add(res.consumes)
            if res.iterates_parent:
                # iterates_parent references a test case name, not an artifact
                # but the resource depends on whatever that case produced
                pass
            # Check artifact-level consumes
            for art_name in produces:
                art = self.ctx.artifacts.get(art_name)
                if art and art.consumes:
                    consumes.add(art.consumes)
            # Template URLs imply consumption
            if res.entry_template:
                for art_name, art in self.ctx.artifacts.items():
                    if art.consumes and art_name in produces:
                        consumes.add(art.consumes)

            res_produces[res.name] = produces
            res_consumes[res.name] = consumes
            for art in produces:
                art_producer[art] = res.name

        # Build adjacency: if resource B consumes artifact X produced by A → A must run before B
        in_degree: dict[str, int] = {r.name: 0 for r in resources}
        dependents: dict[str, list[str]] = {r.name: [] for r in resources}

        for res in resources:
            for consumed_art in res_consumes.get(res.name, set()):
                producer = art_producer.get(consumed_art)
                if producer and producer != res.name:
                    dependents[producer].append(res.name)
                    in_degree[res.name] += 1

        # Kahn's algorithm
        queue = [r.name for r in resources if in_degree[r.name] == 0]
        ordered: list[str] = []

        while queue:
            name = queue.pop(0)
            ordered.append(name)
            for dep in dependents.get(name, []):
                in_degree[dep] -= 1
                if in_degree[dep] == 0:
                    queue.append(dep)

        if len(ordered) != len(resources):
            cycle_members = [r.name for r in resources if r.name not in ordered]
            raise RuntimeError(
                f"Cycle detected in resource dependencies: {cycle_members}"
            )

        # Execute in topological order
        res_by_name = {r.name: r for r in resources}
        for name in ordered:
            self._execute_resource(res_by_name[name])

    def _execute_resource(self, res: ResourceContext) -> None:
        logger.info(f"Executing resource: {res.name}")
        bl = self._bl()
        globals_ = res.globals_
        timeout = globals_.get("timeout_ms", "30000")
        page_delay = int(globals_.get("page_load_delay_ms", 0))

        ctx_opts = {}
        user_agent = globals_.get("user_agent")
        if user_agent:
            ctx_opts["userAgent"] = user_agent

        bl.new_context(**ctx_opts)
        bl.set_browser_timeout(f"{timeout}ms")
        bl.new_page()

        try:
            # Run state setup (auth, consent) if configured
            self._run_setup(bl)

            entry_urls = self._resolve_entry_urls(res)

            for entry_url in entry_urls:
                logger.info(f"  Navigating to: {entry_url}")
                try:
                    bl.go_to(entry_url)
                except Exception as e:
                    logger.warn(f"  Navigation failed: {e}")
                    continue

                self._dismiss_interrupts(bl)

                if page_delay:
                    time.sleep(page_delay / 1000.0)

                root_rules = self._build_rule_tree(res)
                executed: set[str] = set()
                for root in root_rules:
                    self._walk_rule(root, res, None, entry_url,
                                    executed=executed)
        finally:
            bl.close_context()

    def _resolve_entry_urls(self, res: ResourceContext) -> list[str]:
        """Resolve entry URLs, expanding {field} templates from consumed artifacts."""
        url = res.entry_url
        if not url:
            return []

        if "{" in url and "}" in url:
            consumes = res.consumes
            if not consumes:
                for art in self.ctx.artifacts.values():
                    if art.consumes:
                        consumes = art.consumes
                        break

            if consumes and consumes in self.ctx.artifact_store:
                records = self.ctx.artifact_store[consumes]
                urls = []
                for record in records:
                    data = record.get("data", record)
                    rendered = url
                    for k, v in data.items():
                        rendered = rendered.replace("{" + k + "}", str(v))
                    # Also try {artifacts.name.field} cross-artifact refs
                    for art_name, art_records in self.ctx.artifact_store.items():
                        if art_records:
                            latest = art_records[-1].get("data", {})
                            for fk, fv in latest.items():
                                ref = "{artifacts." + art_name + "." + fk + "}"
                                rendered = rendered.replace(ref, str(fv))
                    if "{" not in rendered:
                        urls.append(rendered)
                return urls
            return []

        return [url]

    @staticmethod
    def _resolve_node_order(nodes: list[RuleNode]) -> list[str]:
        """Topologically sort nodes using Kahn's algorithm.

        Edges come from two sources:
        1. Parent declarations — ``rule.parents`` lists predecessors.
        2. Artifact dependencies — a node that ``emit_targets`` an artifact
           must run before any node that consumes it (future: ``consumes``
           field on RuleNode).

        Raises ``ValueError`` on cycles.
        """
        if not nodes:
            return []

        node_names = {n.name for n in nodes}

        # adjacency list and in-degree map
        adj: dict[str, list[str]] = {n.name: [] for n in nodes}
        in_deg: dict[str, int] = {n.name: 0 for n in nodes}

        def _add_edge(src: str, dst: str) -> None:
            if src not in node_names or dst not in node_names:
                return
            if src == dst:
                raise ValueError(
                    f"Cycle detected in node dependencies: {src}"
                )
            if dst not in adj[src]:
                adj[src].append(dst)
                in_deg[dst] += 1

        # 1. Parent edges: parent → child
        for n in nodes:
            for parent in n.parents:
                _add_edge(parent, n.name)

        # 2. Artifact edges: emitter → consumer (placeholder for Task 2)
        # emitter: dict[str, str] = {}
        # for n in nodes:
        #     for target in n.emit_targets:
        #         emitter[target] = n.name

        # Kahn's algorithm — stable: preserves input order for ties
        queue = [n.name for n in nodes if in_deg[n.name] == 0]
        order: list[str] = []

        while queue:
            name = queue.pop(0)
            order.append(name)
            for nxt in adj[name]:
                in_deg[nxt] -= 1
                if in_deg[nxt] == 0:
                    queue.append(nxt)

        if len(order) != len(nodes):
            missing = [n.name for n in nodes if n.name not in set(order)]
            raise ValueError(
                f"Cycle detected in node dependencies: {', '.join(missing)}"
            )

        return order

    def _find_children(self, parent_name: str,
                       all_rules: dict[str, RuleNode]) -> list[RuleNode]:
        """Return children of *parent_name*, topologically sorted."""
        children = [r for r in all_rules.values()
                    if parent_name in r.parents]
        if not children:
            return []
        sorted_names = self._resolve_node_order(children)
        return [all_rules[n] for n in sorted_names]

    def _build_rule_tree(self, res: ResourceContext) -> list[RuleNode]:
        """Return root-level rules in topological order.

        Also populates ``rule.children`` on every node so that expansion
        methods can walk immediate children per element.
        """
        # Populate children on all nodes (topologically sorted)
        for rule in res.rules.values():
            rule.children = self._find_children(rule.name, res.rules)

        # Validate: full topo sort over all rules detects cycles early
        self._resolve_node_order(list(res.rules.values()))

        # Return roots in the order they appear in root_names
        roots = []
        for rname in res.root_names:
            if rname in res.rules:
                roots.append(res.rules[rname])
        return roots

    def _walk_rule(self, rule: RuleNode, res: ResourceContext,
                   scope: str | None, current_url: str, *,
                   executed: set[str] | None = None,
                   context: dict[str, Any] | None = None) -> list[dict]:
        """Walk a rule node. scope is a CSS selector string or None for page.

        *executed* tracks which nodes have already run so that multi-parent
        nodes execute only once (after all parents complete).
        *context* carries parent-extracted fields to children.
        """
        if executed is not None:
            if rule.name in executed:
                return []
            executed.add(rule.name)

        ctx = dict(context or {})
        records: list[dict] = []

        # State check with retry
        state_ok = self._check_state(rule, current_url)
        if not state_ok and rule.retry_max > 0:
            for attempt in range(1, rule.retry_max + 1):
                logger.info(f"  Retry {attempt}/{rule.retry_max} for rule '{rule.name}'")
                time.sleep(rule.retry_delay_ms / 1000.0)
                self._execute_actions(rule, res)
                state_ok = self._check_state(rule, current_url)
                if state_ok:
                    break
        if not state_ok:
            return records

        self._execute_actions(rule, res)

        if rule.expansion:
            records = self._handle_expansion(rule, res, current_url,
                                             executed=executed, context=ctx)
        else:
            record = self._extract_from_scope(rule, scope, current_url)

            # Merge extracted data into context for children
            if record and record.get("data"):
                ctx.update(record["data"])

            child_records: dict[str, list] = {}
            for child in rule.children:
                child_data = self._walk_rule(child, res, scope, current_url,
                                             executed=executed, context=ctx)
                if child_data:
                    child_records[child.name] = child_data

            if record or child_records:
                if record is None:
                    record = {}
                if child_records:
                    record["_children"] = child_records
                records.append(record)

        for target in rule.emit_targets:
            self._emit_records(target, rule, records, current_url)

        return records

    def _check_state(self, rule: RuleNode, current_url: str) -> bool:
        bl = self._bl()
        for check in rule.state_checks:
            if check.type == "url_matches":
                if check.pattern not in current_url:
                    return False
            elif check.type == "url_contains":
                if check.pattern not in current_url:
                    return False
            elif check.type == "url_not_contains":
                if check.pattern in current_url:
                    return False
            elif check.type == "selector_exists":
                try:
                    count = bl.get_element_count(check.pattern)
                    if count == 0:
                        return False
                except Exception:
                    return False
            elif check.type == "table_headers":
                pass
        return True

    def _execute_actions(self, rule: RuleNode, res: ResourceContext) -> None:
        for action in rule.actions:
            try:
                self._do_action(action, res)
            except Exception as e:
                logger.warn(f"  Action {action.type} failed: {e}")

    def _do_action(self, action: Action, res: ResourceContext) -> None:
        bl = self._bl()
        delay_ms = int(action.options.get("delay_ms", 0))

        if action.type == "click":
            bl.click(action.locator)
            if delay_ms:
                time.sleep(delay_ms / 1000.0)
        elif action.type == "type":
            bl.fill_text(action.locator, action.value or "")
            if delay_ms:
                time.sleep(delay_ms / 1000.0)
        elif action.type == "select":
            bl.select_options_by(action.locator, "value", action.value or "")
        elif action.type == "scroll":
            bl.evaluate_javascript(None, "window.scrollBy(0, window.innerHeight)")
            time.sleep(0.5)
        elif action.type == "wait":
            bl.wait_for_load_state("networkidle")
        elif action.type == "wait_ms":
            ms = int(action.value or 0)
            time.sleep(ms / 1000.0)
        elif action.type == "open":
            bl.go_to(action.value or "")
            page_delay = int(res.globals_.get("page_load_delay_ms", 0))
            if page_delay:
                time.sleep(page_delay / 1000.0)
        elif action.type == "open_bound":
            pass

    def _handle_expansion(self, rule: RuleNode, res: ResourceContext,
                          current_url: str, *,
                          executed: set[str] | None = None,
                          context: dict[str, Any] | None = None) -> list[dict]:
        exp = rule.expansion
        if exp.over == "elements":
            return self._expand_elements(rule, res, current_url,
                                         executed=executed, context=context)
        elif exp.over == "pages_next":
            return self._expand_pages_next(rule, res, current_url,
                                           executed=executed, context=context)
        elif exp.over == "pages_numeric":
            return self._expand_pages_numeric(rule, res, current_url,
                                              executed=executed, context=context)
        elif exp.over == "combinations":
            return self._expand_combinations(rule, res, current_url,
                                             executed=executed, context=context)
        return []

    def _expand_elements(self, rule: RuleNode, res: ResourceContext,
                         current_url: str, *,
                         executed: set[str] | None = None,
                         context: dict[str, Any] | None = None) -> list[dict]:
        bl = self._bl()
        exp = rule.expansion
        selector = exp.scope
        limit = exp.limit
        use_bfs = (exp.order == "bfs")
        records = []

        try:
            count = bl.get_element_count(selector)
        except Exception as e:
            logger.warn(f"  Element expansion failed for '{selector}': {e}")
            return records

        if limit and count > limit:
            count = limit

        if use_bfs:
            # BFS: extract ALL elements first, then walk children per element
            extracted: list[tuple[str, dict | None, dict]] = []
            for i in range(count):
                elem_selector = f"{selector} >> nth={i}"
                record = self._extract_from_element(rule, elem_selector, current_url)
                elem_ctx = dict(context or {})
                if record and record.get("data"):
                    elem_ctx.update(record["data"])
                extracted.append((elem_selector, record, elem_ctx))

            for elem_selector, record, elem_ctx in extracted:
                child_records: dict[str, list] = {}
                for child in rule.children:
                    child_data = self._walk_rule(child, res, elem_selector,
                                                 current_url, executed=executed,
                                                 context=elem_ctx)
                    if child_data:
                        child_records[child.name] = child_data
                if record is not None:
                    if child_records:
                        record["_children"] = child_records
                    records.append(record)
        else:
            # DFS: process each element fully before next
            for i in range(count):
                elem_selector = f"{selector} >> nth={i}"
                record = self._extract_from_element(rule, elem_selector, current_url)

                elem_ctx = dict(context or {})
                if record and record.get("data"):
                    elem_ctx.update(record["data"])

                child_records: dict[str, list] = {}
                for child in rule.children:
                    child_data = self._walk_rule(child, res, elem_selector,
                                                 current_url, executed=executed,
                                                 context=elem_ctx)
                    if child_data:
                        child_records[child.name] = child_data

                if record is not None:
                    if child_records:
                        record["_children"] = child_records
                    records.append(record)

        return records

    def _expand_pages_next(self, rule: RuleNode, res: ResourceContext,
                           current_url: str, *,
                           executed: set[str] | None = None,
                           context: dict[str, Any] | None = None) -> list[dict]:
        bl = self._bl()
        exp = rule.expansion
        next_selector = exp.locator
        limit = exp.limit
        records = []

        for page_num in range(limit):
            page_url = bl.get_url()
            logger.info(f"    Page {page_num + 1}: {page_url}")

            for child in rule.children:
                child_data = self._walk_rule(child, res, None, page_url,
                                             executed=executed, context=context)
                if child_data:
                    records.extend(child_data)

            try:
                count = bl.get_element_count(next_selector)
                if count == 0:
                    logger.info("    No next button found, stopping pagination")
                    break
                bl.click(next_selector)
                bl.wait_for_load_state("domcontentloaded")
                page_delay = int(res.globals_.get("page_load_delay_ms", 0))
                if page_delay:
                    time.sleep(page_delay / 1000.0)
                time.sleep(0.5)
            except Exception as e:
                logger.info(f"    Pagination ended: {e}")
                break

        return records

    def _expand_pages_numeric(self, rule: RuleNode, res: ResourceContext,
                              current_url: str, *,
                              executed: set[str] | None = None,
                              context: dict[str, Any] | None = None) -> list[dict]:
        bl = self._bl()
        exp = rule.expansion
        control_selector = exp.locator
        start = exp.start
        limit = exp.limit
        records = []

        for page_num in range(start, start + limit):
            page_url = bl.get_url()
            logger.info(f"    Numeric page {page_num}: {page_url}")

            for child in rule.children:
                child_data = self._walk_rule(child, res, None, page_url,
                                             executed=executed, context=context)
                if child_data:
                    records.extend(child_data)

            next_num = page_num + 1
            if next_num >= start + limit:
                break

            try:
                count = bl.get_element_count(control_selector)
                clicked = False
                for idx in range(count):
                    link_sel = f"{control_selector} >> nth={idx}"
                    href = bl.get_attribute(link_sel, "href") or ""
                    text = bl.get_text(link_sel)
                    if f"p={next_num}" in href or text.strip() == str(next_num):
                        bl.click(link_sel)
                        bl.wait_for_load_state("domcontentloaded")
                        page_delay = int(res.globals_.get("page_load_delay_ms", 0))
                        if page_delay:
                            time.sleep(page_delay / 1000.0)
                        time.sleep(0.5)
                        clicked = True
                        break
                if not clicked:
                    logger.info(f"    No link for page {next_num}, stopping")
                    break
            except Exception as e:
                logger.info(f"    Numeric pagination ended: {e}")
                break

        return records

    def _expand_combinations(self, rule: RuleNode, res: ResourceContext,
                             current_url: str, *,
                             executed: set[str] | None = None,
                             context: dict[str, Any] | None = None) -> list[dict]:
        """Cartesian product of combination axes."""
        bl = self._bl()
        exp = rule.expansion
        axes = exp.axes
        if not axes:
            return []

        # Build value lists per axis (support "auto" discovery)
        axis_values: list[list[str]] = []
        for axis in axes:
            if axis.values == ["auto"]:
                # Discover values from the control element
                try:
                    if axis.action == "select":
                        vals = bl.evaluate_javascript(
                            axis.control,
                            "(el) => Array.from(el.options).map(o => o.value)"
                        )
                    else:
                        count = bl.get_element_count(axis.control)
                        vals = []
                        for i in range(count):
                            text = bl.get_text(f"{axis.control} >> nth={i}").strip()
                            if text:
                                vals.append(text)
                    axis_values.append(vals)
                except Exception as e:
                    logger.warn(f"  Auto-discover failed for {axis.control}: {e}")
                    axis_values.append([])
            else:
                axis_values.append(axis.values)

        # Cartesian product
        import itertools
        combos = list(itertools.product(*axis_values))
        records = []

        for combo in combos:
            # Apply each axis action
            for axis, value in zip(axes, combo):
                try:
                    if axis.action == "type":
                        bl.fill_text(axis.control, value)
                    elif axis.action == "select":
                        bl.select_options_by(axis.control, "value", value)
                    elif axis.action == "click":
                        # Find the matching element by text
                        count = bl.get_element_count(axis.control)
                        for i in range(count):
                            sel = f"{axis.control} >> nth={i}"
                            text = bl.get_text(sel).strip()
                            if text == value:
                                bl.click(sel)
                                break
                except Exception as e:
                    logger.warn(f"  Combo action {axis.action}={value} failed: {e}")

            # Wait for page to settle
            try:
                bl.wait_for_load_state("domcontentloaded")
            except Exception:
                pass
            time.sleep(0.3)

            # Walk children for this combination
            combo_ctx = dict(context or {})
            for axis, value in zip(axes, combo):
                combo_ctx[f"_combo_{axis.control}"] = value

            for child in rule.children:
                child_data = self._walk_rule(child, res, None, current_url,
                                             executed=executed, context=combo_ctx)
                if child_data:
                    records.extend(child_data)

        return records

    def _extract_from_scope(self, rule: RuleNode, scope: str | None,
                            current_url: str) -> dict | None:
        if not rule.field_specs and not rule.table_spec and not rule.ai_extraction:
            return None

        data = {}
        if rule.field_specs:
            for fs in rule.field_specs:
                data[fs.name] = self._extract_field(fs, scope)

        if rule.table_spec:
            table_result = self._extract_table_data(rule.table_spec, scope, current_url, rule.name)
            if table_result:
                data.update(table_result.get("data", {}))

        if rule.ai_extraction:
            ai_result = self._run_ai_extraction(rule.ai_extraction, data)
            if ai_result:
                data.update(ai_result)

        if not data:
            return None

        return {
            "node": rule.name,
            "url": current_url,
            "data": data,
            "extracted_at": datetime.now(timezone.utc).isoformat(),
        }

    def _extract_from_element(self, rule: RuleNode, elem_selector: str,
                              current_url: str) -> dict | None:
        if rule.field_specs:
            data = {}
            for fs in rule.field_specs:
                data[fs.name] = self._extract_field(fs, elem_selector)
            return {
                "node": rule.name,
                "url": current_url,
                "data": data,
                "extracted_at": datetime.now(timezone.utc).isoformat(),
            }

        if rule.table_spec:
            return self._extract_table_data(rule.table_spec, elem_selector, current_url, rule.name)

        return None

    def _extract_field(self, fs: FieldSpec, scope: str | None) -> Any:
        bl = self._bl()
        try:
            selector = f"{scope} >> {fs.locator}" if scope else fs.locator

            if fs.extractor == "text":
                count = bl.get_element_count(selector)
                if count == 0:
                    return ""
                return bl.get_text(selector).strip()
            elif fs.extractor == "attr":
                count = bl.get_element_count(selector)
                if count == 0 or not fs.attr:
                    return ""
                return (bl.get_attribute(selector, fs.attr) or "").strip()
            elif fs.extractor == "grouped":
                count = bl.get_element_count(selector)
                results = []
                for i in range(count):
                    text = bl.get_text(f"{selector} >> nth={i}").strip()
                    if text:
                        results.append(text)
                return results
            elif fs.extractor == "html":
                count = bl.get_element_count(selector)
                if count == 0:
                    return ""
                return bl.get_property(selector, "innerHTML") or ""
            elif fs.extractor == "link":
                count = bl.get_element_count(selector)
                if count == 0:
                    return ""
                return bl.get_attribute(selector, "href") or ""
            elif fs.extractor == "image":
                count = bl.get_element_count(selector)
                if count == 0:
                    return ""
                return bl.get_attribute(selector, "src") or ""
        except Exception as e:
            logger.warn(f"    Extract {fs.name} failed: {e}")
        return ""

    def _extract_table_data(self, tspec: TableSpec, scope: str | None,
                            current_url: str, rule_name: str) -> dict | None:
        bl = self._bl()
        try:
            table_sel = f"{scope} >> {tspec.locator}" if scope else tspec.locator
            count = bl.get_element_count(table_sel)
            if count == 0:
                # Try scope itself as table
                if scope:
                    table_sel = scope
                    count = bl.get_element_count(table_sel)
                if count == 0:
                    return None

            # Get all rows via JS for efficiency
            rows_data = bl.evaluate_javascript(
                table_sel,
                """(table) => {
                    const rows = table.querySelectorAll('tr');
                    return Array.from(rows).map(row => {
                        const cells = row.querySelectorAll('th, td');
                        return Array.from(cells).map(c => c.textContent.trim());
                    });
                }"""
            )

            if not rows_data or len(rows_data) <= tspec.header_row:
                return None

            headers = rows_data[tspec.header_row]

            field_map: dict[str, int] = {}
            for fs in tspec.fields:
                for i, h in enumerate(headers):
                    if h == fs.header:
                        field_map[fs.name] = i
                        break

            table_records = []
            for row_cells in rows_data[tspec.header_row + 1:]:
                if not any(row_cells):
                    continue
                rec = {}
                for fname, idx in field_map.items():
                    rec[fname] = row_cells[idx] if idx < len(row_cells) else ""
                table_records.append(rec)

            return {
                "node": rule_name,
                "url": current_url,
                "data": {tspec.name: table_records},
                "extracted_at": datetime.now(timezone.utc).isoformat(),
            }
        except Exception as e:
            logger.warn(f"    Table extraction failed: {e}")
            return None

    # Built-in AI mode prompts
    _AI_MODES = {
        "extract": "Extract structured data from the following content.",
        "cleanup": "Clean and normalize this content. Remove HTML artifacts, "
                   "fix formatting, and return well-structured markdown.",
        "classify": "Classify the following content.",
        "refine": "Refine and improve the quality of this text. Fix grammar, "
                  "improve clarity, normalize formatting.",
    }

    def _run_ai_extraction(self, config: dict, existing_data: dict) -> dict | None:
        """Run AI extraction on previously extracted text via Claude API."""
        opts = _parse_options(tuple(config.get("specs", [])))
        name = config.get("name", "ai_result")
        mode = opts.get("mode")
        prompt = opts.get("prompt") or self._AI_MODES.get(mode or "extract",
                                                           "Extract structured data from the text.")
        input_field = opts.get("input")
        schema = opts.get("schema")
        categories = opts.get("categories")

        # Get input text from already-extracted data
        input_text = ""
        if input_field and input_field in existing_data:
            input_text = str(existing_data[input_field])
        elif not input_field:
            input_text = json.dumps(existing_data, ensure_ascii=False)

        if not input_text:
            return None

        # Build the AI prompt
        full_prompt = prompt
        if categories:
            full_prompt += f"\n\nClassify into one of: {categories}"
        if schema:
            full_prompt += f"\n\nReturn JSON matching this schema: {schema}"
        full_prompt += f"\n\nInput:\n{input_text}"
        full_prompt += "\n\nRespond with ONLY valid JSON, no explanation."

        try:
            import anthropic
            client = anthropic.Anthropic()
            response = client.messages.create(
                model="claude-haiku-4-5-20251001",
                max_tokens=1024,
                messages=[{"role": "user", "content": full_prompt}],
            )
            result_text = response.content[0].text.strip()
            # Parse JSON response
            parsed = json.loads(result_text)
            return {name: parsed}
        except ImportError:
            logger.warn("anthropic SDK not installed, skipping AI extraction")
            return None
        except json.JSONDecodeError as e:
            logger.warn(f"AI extraction returned invalid JSON: {e}")
            return {name: result_text}
        except Exception as e:
            logger.warn(f"AI extraction failed: {e}")
            return None

    def _run_setup(self, bl: Any) -> None:
        """Execute state setup actions (auth, consent)."""
        if not self.ctx.setup_actions:
            return
        # Check skip condition
        if self.ctx.setup_skip_when:
            try:
                count = bl.get_element_count(self.ctx.setup_skip_when)
                if count > 0:
                    logger.info("  Setup skipped — skip_when selector found")
                    return
            except Exception:
                pass
        for sa in self.ctx.setup_actions:
            try:
                if sa.action == "open":
                    bl.go_to(sa.url)
                elif sa.action == "input":
                    bl.fill_text(sa.css, sa.value)
                elif sa.action == "password":
                    bl.fill_text(sa.css, sa.value)
                elif sa.action == "click":
                    bl.click(sa.css)
            except Exception as e:
                logger.warn(f"  Setup action {sa.action} failed: {e}")
        try:
            bl.wait_for_load_state("networkidle")
        except Exception:
            pass

    def _dismiss_interrupts(self, bl: Any) -> None:
        """Auto-dismiss overlay selectors (cookie banners, modals)."""
        for selector in self.ctx.interrupt_selectors:
            try:
                count = bl.get_element_count(selector)
                if count > 0:
                    bl.click(selector)
                    logger.info(f"  Dismissed interrupt: {selector}")
            except Exception:
                pass

    def _invoke_hooks(self, lifecycle_point: str, data: dict) -> dict:
        """Invoke registered hooks at a lifecycle point."""
        for hook in self.ctx.hooks:
            if hook.lifecycle_point == lifecycle_point:
                logger.info(f"  Hook '{hook.name}' at {lifecycle_point}")
                # Hooks can transform data via config-driven rules
                # For now: log and pass through. Real hook system would
                # call registered Python functions or external tools.
        return data

    def _emit_records(self, target: str, rule: RuleNode,
                      records: list[dict], current_url: str) -> None:
        if target not in self.ctx.artifact_store:
            self.ctx.artifact_store[target] = []

        flatten_field = rule.emit_flatten_by.get(target)
        merge_key = rule.emit_merge_on.get(target)

        for record in records:
            if not record:
                continue

            if flatten_field:
                data = record.get("data", {})
                items = data.get(flatten_field, [])
                if isinstance(items, list):
                    for item in items:
                        flat_rec = {
                            "node": record.get("node", rule.name),
                            "url": record.get("url", current_url),
                            "data": item if isinstance(item, dict) else {flatten_field: item},
                            "extracted_at": record.get("extracted_at",
                                                       datetime.now(timezone.utc).isoformat()),
                        }
                        self.ctx.artifact_store[target].append(flat_rec)
                continue

            if merge_key:
                data = record.get("data", {})
                key_val = data.get(merge_key)
                if key_val:
                    found = False
                    for existing in self.ctx.artifact_store[target]:
                        if existing.get("data", {}).get(merge_key) == key_val:
                            existing["data"].update(data)
                            found = True
                            break
                    if found:
                        continue

            self.ctx.artifact_store[target].append(record)

    def _write_outputs(self, output_dir: str) -> None:
        summary = {
            "deployment": self.ctx.name,
            "artifacts": {},
            "completed_at": datetime.now(timezone.utc).isoformat(),
        }

        for art_name, art in self.ctx.artifacts.items():
            records = self.ctx.artifact_store.get(art_name, [])
            summary["artifacts"][art_name] = {
                "record_count": len(records),
                "output": art.output,
                "structure": art.structure,
            }

            if not art.output:
                continue

            if art.dedupe and records:
                seen = set()
                deduped = []
                for r in records:
                    key_val = r.get("data", {}).get(art.dedupe)
                    if key_val and key_val not in seen:
                        seen.add(key_val)
                        deduped.append(r)
                    elif not key_val:
                        deduped.append(r)
                records = deduped

            output_data = records
            if art.query:
                try:
                    import jmespath
                    output_data = jmespath.search(art.query, records)
                except ImportError:
                    logger.warn("jmespath not installed, skipping query transform")
                except Exception as e:
                    logger.warn(f"JMESPath query failed for {art_name}: {e}")

            if art.structure == "flat":
                flat = []
                for r in (output_data if isinstance(output_data, list) else [output_data]):
                    if isinstance(r, dict):
                        flat.append(r)
                output_data = flat

            # Determine output path and format
            fmt = art.format or "json"
            ext = {"json": ".json", "jsonl": ".jsonl", "csv": ".csv",
                   "markdown": ".md"}.get(fmt, ".json")

            override = self.ctx.write_overrides.get(art_name)
            if override:
                out_path = Path(override)
            else:
                out_path = Path(output_dir) / f"{self.ctx.name}_{art_name}{ext}"

            out_path.parent.mkdir(parents=True, exist_ok=True)

            if fmt == "jsonl":
                with open(out_path, "w") as f:
                    for item in (output_data if isinstance(output_data, list)
                                 else [output_data]):
                        f.write(json.dumps(item, ensure_ascii=False) + "\n")
            elif fmt == "csv":
                import csv as csv_mod
                rows = output_data if isinstance(output_data, list) else [output_data]
                if rows:
                    # Flatten data dicts for CSV
                    flat_rows = []
                    for r in rows:
                        if isinstance(r, dict) and "data" in r:
                            flat_rows.append(r["data"])
                        elif isinstance(r, dict):
                            flat_rows.append(r)
                    if flat_rows:
                        keys = list(flat_rows[0].keys())
                        with open(out_path, "w", newline="") as f:
                            writer = csv_mod.DictWriter(f, fieldnames=keys)
                            writer.writeheader()
                            writer.writerows(flat_rows)
            elif fmt == "markdown":
                with open(out_path, "w") as f:
                    for item in (output_data if isinstance(output_data, list)
                                 else [output_data]):
                        data = item.get("data", item) if isinstance(item, dict) else item
                        if isinstance(data, dict):
                            title = data.get("title", "")
                            body = data.get("body", "")
                            if title:
                                f.write(f"# {title}\n\n")
                            if body:
                                f.write(f"{body}\n\n")
                        else:
                            f.write(f"{data}\n\n")
            else:  # json
                with open(out_path, "w") as f:
                    json.dump(output_data, f, indent=2, ensure_ascii=False)

            logger.info(f"  Wrote {len(records)} records to {out_path}")

        summary_path = Path(output_dir) / f"{self.ctx.name}.json"
        with open(summary_path, "w") as f:
            json.dump(summary, f, indent=2)
        logger.info(f"  Wrote deployment summary to {summary_path}")

    def _check_quality_gates(self) -> None:
        qg = self.ctx.quality_gate
        total_records = sum(len(v) for v in self.ctx.artifact_store.values())

        if qg.min_records and total_records < qg.min_records:
            logger.warn(
                f"QUALITY GATE FAIL: min_records={qg.min_records}, "
                f"actual={total_records}"
            )

        for field_name, min_pct in qg.filled_pcts.items():
            total = 0
            filled = 0
            for records in self.ctx.artifact_store.values():
                for r in records:
                    data = r.get("data", {})
                    if field_name in data:
                        total += 1
                        val = data[field_name]
                        if val and val != "" and val != []:
                            filled += 1
            if total > 0:
                actual_pct = (filled / total) * 100
                if actual_pct < min_pct:
                    logger.warn(
                        f"QUALITY GATE WARN: {field_name} filled={actual_pct:.1f}% "
                        f"< required={min_pct}%"
                    )


# ---------------------------------------------------------------------------
# Robot Framework keyword library
# ---------------------------------------------------------------------------

@library(scope="SUITE", auto_keywords=False)
class WiseRpaBDD:
    def __init__(self) -> None:
        self.events: list[tuple[str, tuple[Any, ...]]] = []
        self._deployment: DeploymentContext | None = None
        self._current_resource: ResourceContext | None = None
        self._current_rule: RuleNode | None = None
        self._rule_stack: list[str] = []  # Track rule creation order

    def _record(self, name: str, *values: Any) -> None:
        self.events.append((name, values))
        rendered = ", ".join(str(v) for v in values if v not in (None, ""))
        logger.info(f"{name}: {rendered}" if rendered else name)

    # -- Deployment lifecycle --

    @keyword('Given I start deployment "${deployment}"')
    def start_deployment(self, deployment: str) -> None:
        self._record("start_deployment", deployment)
        self._deployment = DeploymentContext(name=deployment)

    @keyword("Then I finalize deployment")
    def finalize_deployment(self) -> None:
        self._record("finalize_deployment")
        if not self._deployment:
            logger.error("No deployment context — nothing to finalize")
            return

        # Identify root rules for each resource before execution
        self._finalize_resource_roots()

        headed = os.environ.get("WISE_RPA_HEADED", "").lower() in ("1", "true", "yes")
        engine = ExecutionEngine(self._deployment, headed=headed)
        engine.run()

    # -- Artifact registration --

    @keyword('Given I register artifact "${artifact}"')
    def register_artifact(self, artifact: str, *fields: str) -> None:
        self._record("register_artifact", artifact, *fields)
        if not self._deployment:
            return
        parsed_fields = []
        current: dict[str, str] = {}
        for f in fields:
            if "=" not in f:
                continue
            k, v = f.split("=", 1)
            if k == "field" and current.get("field"):
                parsed_fields.append(current.copy())
                current = {}
            current[k] = v
        if current.get("field"):
            parsed_fields.append(current.copy())

        self._deployment.artifacts[artifact] = ArtifactSchema(
            name=artifact, fields=parsed_fields
        )
        self._deployment.artifact_store[artifact] = []

    @keyword('And I set artifact options for "${artifact}"')
    def set_artifact_options(self, artifact: str, *options: str) -> None:
        self._record("set_artifact_options", artifact, *options)
        if not self._deployment:
            return
        art = self._deployment.artifacts.get(artifact)
        if not art:
            return
        opts = _parse_options(options)
        art.output = opts.get("output", "").lower() in ("true", "1", "yes")
        art.format = opts.get("format", art.format)
        art.structure = opts.get("structure", art.structure)
        art.dedupe = opts.get("dedupe", art.dedupe)
        art.query = opts.get("query", art.query)
        art.consumes = opts.get("consumes", art.consumes)
        art.description = opts.get("description", art.description)

    # -- Resource management --

    @keyword('Given I start resource "${resource}"')
    def start_resource(self, resource: str) -> None:
        self._record("start_resource", resource)
        if not self._deployment:
            return
        self._current_resource = ResourceContext(name=resource)
        self._deployment.resources.append(self._current_resource)
        self._rule_stack = []

    @keyword('Given I start resource "${resource}" at "${entry}"')
    def start_resource_at(self, resource: str, entry: str) -> None:
        self._record("start_resource_at", resource, entry)
        if not self._deployment:
            return
        rc = ResourceContext(name=resource, entry_url=entry)
        # Detect template URLs
        if "{" in entry and "}" in entry:
            rc.entry_template = entry
        self._current_resource = rc
        self._deployment.resources.append(rc)
        self._rule_stack = []

    @keyword('Given I consume artifact "${artifact}"')
    def consume_artifact(self, artifact: str) -> None:
        self._record("consume_artifact", artifact)
        if self._current_resource:
            self._current_resource.consumes = artifact

    @keyword('Given I resolve entry from "${reference}"')
    def resolve_entry_from(self, reference: str) -> None:
        self._record("resolve_entry_from", reference)

    @keyword('Given I iterate over parent records from "${parent_case}"')
    def iterate_over_parent_records(self, parent_case: str) -> None:
        self._record("iterate_over_parent_records", parent_case)
        if self._current_resource:
            self._current_resource.iterates_parent = parent_case

    @keyword("And I set resource globals")
    def set_resource_globals(self, *globals_: str) -> None:
        self._record("set_resource_globals", *globals_)
        if not self._current_resource:
            return
        self._current_resource.globals_ = _parse_options(globals_)

    # -- Rule management --

    @keyword('And I begin rule "${rule}"')
    def begin_rule(self, rule: str) -> None:
        self._record("begin_rule", rule)
        if not self._current_resource:
            return
        node = RuleNode(name=rule)
        self._current_resource.rules[rule] = node
        self._current_rule = node
        self._rule_stack.append(rule)

    @keyword('And I declare parents "${parents}"')
    def declare_parents(self, parents: str) -> None:
        self._record("declare_parents", parents)
        if not self._current_rule:
            return
        self._current_rule.parents = [p.strip() for p in parents.split(",")]

    @keyword("And I set retry ${max} times with ${delay} ms delay")
    def set_retry(self, max: Any, delay: Any) -> None:
        self._record("set_retry", max, delay)
        if self._current_rule:
            self._current_rule.retry_max = int(max)
            self._current_rule.retry_delay_ms = int(delay)

    # -- State checks --

    @keyword('Given url contains "${pattern}"')
    def url_contains(self, pattern: str) -> None:
        self._record("url_contains", pattern)
        if self._current_rule:
            self._current_rule.state_checks.append(
                StateCheck(type="url_contains", pattern=pattern)
            )

    @keyword('Given url matches "${pattern}"')
    def url_matches(self, pattern: str) -> None:
        self._record("url_matches", pattern)
        if self._current_rule:
            self._current_rule.state_checks.append(
                StateCheck(type="url_matches", pattern=pattern)
            )

    @keyword('But url does not contain "${pattern}"')
    def url_does_not_contain(self, pattern: str) -> None:
        self._record("url_does_not_contain", pattern)
        if self._current_rule:
            self._current_rule.state_checks.append(
                StateCheck(type="url_not_contains", pattern=pattern)
            )

    @keyword('And selector "${selector}" exists')
    def selector_exists(self, selector: str) -> None:
        self._record("selector_exists", selector)
        if self._current_rule:
            self._current_rule.state_checks.append(
                StateCheck(type="selector_exists", pattern=selector)
            )

    @keyword('And table headers are "${headers}"')
    def table_headers_are(self, headers: str) -> None:
        self._record("table_headers_are", headers)
        if self._current_rule:
            self._current_rule.state_checks.append(
                StateCheck(type="table_headers", pattern=headers)
            )

    # -- Actions --

    @keyword('When I open "${url}"')
    def open_url(self, url: str) -> None:
        self._record("open_url", url)
        if self._current_rule:
            self._current_rule.actions.append(
                Action(type="open", value=url)
            )

    @keyword('When I open the bound field "${field}"')
    def open_bound_field(self, field: str) -> None:
        self._record("open_bound_field", field)
        if self._current_rule:
            self._current_rule.actions.append(
                Action(type="open_bound", value=field)
            )

    @keyword('When I click locator "${locator}"')
    def click_locator(self, locator: str, *options: str) -> None:
        self._record("click_locator", locator, *options)
        if self._current_rule:
            self._current_rule.actions.append(
                Action(type="click", locator=locator, options=_parse_options(options))
            )

    @keyword('When I type "${value}" into locator "${locator}"')
    def type_into_locator(self, value: str, locator: str, *options: str) -> None:
        self._record("type_into_locator", value, locator, *options)
        if self._current_rule:
            self._current_rule.actions.append(
                Action(type="type", locator=locator, value=value,
                       options=_parse_options(options))
            )

    @keyword('When I type secret "${value}" into locator "${locator}"')
    def type_secret_into_locator(self, value: str, locator: str, *options: str) -> None:
        self._record("type_secret_into_locator", "***", locator, *options)
        if self._current_rule:
            self._current_rule.actions.append(
                Action(type="type", locator=locator, value=value,
                       options=_parse_options(options))
            )

    @keyword("When I scroll down")
    def scroll_down(self) -> None:
        self._record("scroll_down")
        if self._current_rule:
            self._current_rule.actions.append(Action(type="scroll"))

    @keyword("When I wait for idle")
    def wait_for_idle(self) -> None:
        self._record("wait_for_idle")
        if self._current_rule:
            self._current_rule.actions.append(Action(type="wait"))

    @keyword("When I wait ${ms} ms")
    def wait_ms(self, ms: Any) -> None:
        self._record("wait_ms", ms)
        if self._current_rule:
            self._current_rule.actions.append(
                Action(type="wait_ms", value=str(ms))
            )

    @keyword('When I select "${value}" from locator "${locator}"')
    def select_from_locator(self, value: str, locator: str, *options: str) -> None:
        self._record("select_from_locator", value, locator, *options)
        if self._current_rule:
            self._current_rule.actions.append(
                Action(type="select", locator=locator, value=value,
                       options=_parse_options(options))
            )

    @keyword('When I check locator "${locator}"')
    def check_locator(self, locator: str, *options: str) -> None:
        self._record("check_locator", locator, *options)
        if self._current_rule:
            self._current_rule.actions.append(
                Action(type="click", locator=locator, options=_parse_options(options))
            )

    # -- Expansion --

    @keyword('When I expand over elements "${scope}"')
    def expand_over_elements(self, scope: str, *options: str) -> None:
        self._record("expand_over_elements", scope, *options)
        if not self._current_rule:
            return
        opts = _parse_options(options)
        self._current_rule.expansion = Expansion(
            over="elements", scope=scope,
            limit=int(opts.get("limit", 0)) or 10000,
            options=opts,
        )

    @keyword('When I expand over elements "${scope}" with order "${order}"')
    def expand_over_elements_with_order(self, scope: str, order: str, *options: str) -> None:
        self._record("expand_over_elements_with_order", scope, order, *options)
        if not self._current_rule:
            return
        opts = _parse_options(options)
        self._current_rule.expansion = Expansion(
            over="elements", scope=scope, order=order,
            limit=int(opts.get("limit", 0)) or 10000,
            options=opts,
        )

    @keyword('When I paginate by next button "${locator}" up to ${limit} pages')
    def paginate_by_next_button(self, locator: str, limit: Any, *options: str) -> None:
        self._record("paginate_by_next_button", locator, limit, *options)
        if not self._current_rule:
            return
        self._current_rule.expansion = Expansion(
            over="pages_next", locator=locator,
            limit=int(limit), options=_parse_options(options),
        )

    @keyword('When I paginate by numeric control "${locator}" from ${start} up to ${limit} pages')
    def paginate_by_numeric_control(self, locator: str, start: Any, limit: Any, *options: str) -> None:
        self._record("paginate_by_numeric_control", locator, start, limit, *options)
        if not self._current_rule:
            return
        self._current_rule.expansion = Expansion(
            over="pages_numeric", locator=locator,
            start=int(start), limit=int(limit),
            options=_parse_options(options),
        )

    @keyword("When I expand over combinations")
    def expand_over_combinations(self, *axes: str) -> None:
        self._record("expand_over_combinations", *axes)
        if not self._current_rule:
            return
        # Parse axis specs: action=type control="#sel" values=a|b|c
        parsed_axes: list[CombinationAxis] = []
        current: dict[str, str] = {}
        for spec in axes:
            if "=" not in spec:
                continue
            k, v = spec.split("=", 1)
            if k == "action" and current.get("action"):
                parsed_axes.append(CombinationAxis(
                    action=current["action"],
                    control=_strip_quotes(current.get("control", "")),
                    values=current.get("values", "").split("|"),
                ))
                current = {}
            current[k] = v
        if current.get("action"):
            parsed_axes.append(CombinationAxis(
                action=current["action"],
                control=_strip_quotes(current.get("control", "")),
                values=current.get("values", "").split("|"),
            ))
        self._current_rule.expansion = Expansion(
            over="combinations", axes=parsed_axes,
        )

    # -- Extraction --

    @keyword("Then I extract fields")
    def extract_fields(self, *specs: str) -> None:
        self._record("extract_fields", *specs)
        if not self._current_rule:
            return
        self._current_rule.field_specs = _parse_field_specs(specs)

    @keyword('Then I extract table "${name}" from "${locator}"')
    def extract_table(self, name: str, locator: str, *specs: str) -> None:
        self._record("extract_table", name, locator, *specs)
        if not self._current_rule:
            return
        header_row, fields = _parse_table_specs(specs)
        self._current_rule.table_spec = TableSpec(
            name=name, locator=locator,
            header_row=header_row, fields=fields,
        )

    @keyword('Then I extract with AI "${name}"')
    def extract_with_ai(self, name: str, *specs: str) -> None:
        self._record("extract_with_ai", name, *specs)
        if self._current_rule:
            self._current_rule.ai_extraction = {"name": name, "specs": list(specs)}

    # -- Emit --

    @keyword('And I emit to artifact "${artifact}"')
    def emit_to_artifact(self, artifact: str) -> None:
        self._record("emit_to_artifact", artifact)
        if self._current_rule:
            self._current_rule.emit_targets.append(artifact)

    @keyword('And I emit to artifact "${artifact}" flattened by "${field}"')
    def emit_to_artifact_flattened(self, artifact: str, field: str) -> None:
        self._record("emit_to_artifact_flattened", artifact, field)
        if self._current_rule:
            self._current_rule.emit_targets.append(artifact)
            self._current_rule.emit_flatten_by[artifact] = field

    @keyword('And I merge into artifact "${artifact}" on key "${key}"')
    def merge_into_artifact(self, artifact: str, key: str) -> None:
        self._record("merge_into_artifact", artifact, key)
        if self._current_rule:
            self._current_rule.emit_targets.append(artifact)
            self._current_rule.emit_merge_on[artifact] = key

    @keyword('Then I write artifact "${artifact}" to "${path}"')
    def write_artifact(self, artifact: str, path: str) -> None:
        self._record("write_artifact", artifact, path)
        if self._deployment:
            self._deployment.write_overrides[artifact] = path

    # -- Quality gates --

    @keyword("And I set quality gate min records to ${count}")
    def set_quality_gate_min_records(self, count: Any) -> None:
        self._record("set_quality_gate_min_records", count)
        if self._deployment:
            self._deployment.quality_gate.min_records = int(count)

    @keyword('And I set filled percentage for "${field}" to ${percent}')
    def set_filled_percentage(self, field: str, percent: Any) -> None:
        self._record("set_filled_percentage", field, percent)
        if self._deployment:
            self._deployment.quality_gate.filled_pcts[field] = float(percent)

    @keyword('And I set max failed percentage to ${percent}')
    def set_max_failed_percentage(self, percent: Any) -> None:
        self._record("set_max_failed_percentage", percent)
        if self._deployment:
            self._deployment.quality_gate.max_failed_pct = float(percent)

    # -- Hooks and configuration --

    @keyword('And I register hook "${name}" at "${lifecycle_point}"')
    def register_hook(self, name: str, lifecycle_point: str, *config: str) -> None:
        self._record("register_hook", name, lifecycle_point, *config)
        if self._deployment:
            self._deployment.hooks.append(HookDef(
                name=name, lifecycle_point=lifecycle_point,
                config=_parse_options(config),
            ))

    @keyword("Given I configure state setup")
    def configure_state_setup(self, *actions: str) -> None:
        self._record("configure_state_setup", *actions)
        if not self._deployment:
            return
        for spec in actions:
            if "=" not in spec:
                continue
            k, v = spec.split("=", 1)
            v = _strip_quotes(v)
            if k == "skip_when":
                self._deployment.setup_skip_when = v
            elif k == "action":
                # Parse: action=open url="..." or action=click css="..."
                # The action type is the value, rest comes in subsequent opts
                self._deployment.setup_actions.append(SetupAction(action=v))
            elif k in ("url", "css", "value") and self._deployment.setup_actions:
                setattr(self._deployment.setup_actions[-1], k, v)

    @keyword("And I configure interrupts")
    def configure_interrupts(self, *dismissals: str) -> None:
        self._record("configure_interrupts", *dismissals)
        if not self._deployment:
            return
        for spec in dismissals:
            if "=" not in spec:
                continue
            k, v = spec.split("=", 1)
            if k == "dismiss":
                self._deployment.interrupt_selectors.append(_strip_quotes(v))

    @keyword("Then I close the browser")
    def close_browser(self) -> None:
        self._record("close_browser")

    # -- Resource test case hook --
    # When RF runs a test case with [Setup] that calls start_resource_at,
    # all subsequent keywords in that test case are in that resource context.
    # Rules without parents are root rules.
    # At the end we need to identify roots for each resource.

    def _finalize_resource_roots(self) -> None:
        """Called before execution to identify root rules for each resource."""
        if not self._deployment:
            return
        for res in self._deployment.resources:
            for name, rule in res.rules.items():
                if not rule.parents:
                    res.root_names.append(name)
