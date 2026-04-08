"""Robot Framework keyword library for BDD RPA suites with Playwright execution.

Keywords build a declarative rule tree during test execution. The Suite Teardown
(finalize_deployment) walks the tree with a real Playwright browser to scrape data.

Architecture: Plan-then-Execute (deferred execution model).
- Phase A: RF keywords called sequentially build an in-memory scraping plan.
- Phase B: finalize_deployment executes the entire plan with Playwright.

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
class Expansion:
    over: str  # elements, pages_next, pages_numeric
    scope: str | None = None
    locator: str | None = None
    limit: int = 100
    start: int = 1
    order: str = "dfs"
    options: dict = field(default_factory=dict)


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


@dataclass
class ArtifactSchema:
    name: str
    fields: list[dict] = field(default_factory=list)
    output: bool = False
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
class DeploymentContext:
    name: str
    artifacts: dict[str, ArtifactSchema] = field(default_factory=dict)
    artifact_store: dict[str, list] = field(default_factory=dict)
    resources: list[ResourceContext] = field(default_factory=list)
    quality_gate: QualityGate = field(default_factory=QualityGate)
    output_dir: str = ""
    write_overrides: dict[str, str] = field(default_factory=dict)


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
# Execution engine
# ---------------------------------------------------------------------------

class ExecutionEngine:
    """Walks the rule tree with a Playwright browser."""

    def __init__(self, ctx: DeploymentContext, headed: bool = False):
        self.ctx = ctx
        self.headed = headed
        self._browser = None
        self._pw = None
        self._page = None

    def run(self) -> None:
        try:
            from playwright.sync_api import sync_playwright
        except ImportError:
            logger.error(
                "playwright not installed. Run: pip install playwright && "
                "python -m playwright install chromium"
            )
            return

        output_dir = self.ctx.output_dir or f"output/{self.ctx.name}"
        os.makedirs(output_dir, exist_ok=True)

        self._pw = sync_playwright().start()
        self._browser = self._pw.chromium.launch(headless=not self.headed)

        try:
            self._execute_resources()
            self._write_outputs(output_dir)
            self._check_quality_gates()
        finally:
            if self._browser:
                self._browser.close()
            if self._pw:
                self._pw.stop()

    def _execute_resources(self) -> None:
        # Order: resources without consumes first, then those that consume
        independent = []
        dependent = []
        for res in self.ctx.resources:
            consumes = res.consumes
            if not consumes:
                # Check if any artifact this resource produces has consumes
                for rname in res.root_names:
                    rule = res.rules.get(rname)
                    if rule:
                        for target in rule.emit_targets:
                            art = self.ctx.artifacts.get(target)
                            if art and art.consumes:
                                consumes = art.consumes
                                break
                # Also check deeply for consumes option on artifacts
                if not consumes:
                    for art_name, art in self.ctx.artifacts.items():
                        if art.consumes:
                            # Check if this resource uses this artifact
                            pass
            if consumes or res.entry_template or res.iterates_parent:
                dependent.append(res)
            else:
                independent.append(res)

        for res in independent:
            self._execute_resource(res)
        for res in dependent:
            self._execute_resource(res)

    def _execute_resource(self, res: ResourceContext) -> None:
        logger.info(f"Executing resource: {res.name}")
        globals_ = res.globals_
        timeout = int(globals_.get("timeout_ms", 30000))
        page_delay = int(globals_.get("page_load_delay_ms", 0))
        user_agent = globals_.get("user_agent")

        ctx_opts = {}
        if user_agent:
            ctx_opts["user_agent"] = user_agent

        browser_ctx = self._browser.new_context(**ctx_opts)
        browser_ctx.set_default_timeout(timeout)
        self._page = browser_ctx.new_page()

        try:
            # Resolve entry URLs
            entry_urls = self._resolve_entry_urls(res)

            for entry_url in entry_urls:
                logger.info(f"  Navigating to: {entry_url}")
                try:
                    self._page.goto(entry_url, wait_until="domcontentloaded")
                except Exception as e:
                    logger.warn(f"  Navigation failed: {e}")
                    continue

                if page_delay:
                    time.sleep(page_delay / 1000.0)

                # Build child tree from rules
                root_rules = self._build_rule_tree(res)
                for root in root_rules:
                    self._walk_rule(root, res, self._page, entry_url)
        finally:
            self._page.close()
            browser_ctx.close()

    def _resolve_entry_urls(self, res: ResourceContext) -> list[str]:
        """Resolve entry URLs, expanding templates from consumed artifacts."""
        url = res.entry_url
        if not url:
            return []

        # Check for template pattern like https://site.com{field}
        if "{" in url and "}" in url:
            # Find which artifact to consume
            consumes = res.consumes
            if not consumes:
                # Look at artifact schemas for consumes
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
                    if "{" not in rendered:
                        urls.append(rendered)
                return urls
            return []

        return [url]

    def _build_rule_tree(self, res: ResourceContext) -> list[RuleNode]:
        """Build tree from flat rules dict using parent references."""
        roots = []
        for rname in res.root_names:
            if rname in res.rules:
                root = res.rules[rname]
                self._attach_children(root, res.rules)
                roots.append(root)
        return roots

    def _attach_children(self, node: RuleNode, all_rules: dict[str, RuleNode]) -> None:
        """Recursively attach child rules based on parent declarations."""
        node.children = []
        for name, rule in all_rules.items():
            if node.name in rule.parents:
                self._attach_children(rule, all_rules)
                node.children.append(rule)

    def _walk_rule(self, rule: RuleNode, res: ResourceContext,
                   scope: Any, current_url: str) -> list[dict]:
        """Walk a rule node, executing actions and collecting records."""
        records = []

        # Check state preconditions
        if not self._check_state(rule, current_url):
            return records

        # Execute actions
        self._execute_actions(rule, res)

        # Handle expansion
        if rule.expansion:
            records = self._handle_expansion(rule, res, current_url)
        else:
            # No expansion — extract directly if there are field specs
            record = self._extract_from_scope(rule, scope, current_url)

            # Walk children
            child_records: dict[str, list] = {}
            for child in rule.children:
                child_data = self._walk_rule(child, res, scope, current_url)
                if child_data:
                    child_records[child.name] = child_data

            if record or child_records:
                if record is None:
                    record = {}
                if child_records:
                    record["_children"] = child_records
                records.append(record)

        # Emit to artifacts
        for target in rule.emit_targets:
            self._emit_records(target, rule, records, current_url)

        return records

    def _check_state(self, rule: RuleNode, current_url: str) -> bool:
        """Check state preconditions for a rule."""
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
                    if not self._page.query_selector(check.pattern):
                        return False
                except Exception:
                    return False
            elif check.type == "table_headers":
                pass  # Informational only
        return True

    def _execute_actions(self, rule: RuleNode, res: ResourceContext) -> None:
        """Execute action list for a rule."""
        for action in rule.actions:
            try:
                self._do_action(action, res)
            except Exception as e:
                logger.warn(f"  Action {action.type} failed: {e}")

    def _do_action(self, action: Action, res: ResourceContext) -> None:
        """Execute a single action."""
        delay_ms = int(action.options.get("delay_ms", 0))

        if action.type == "click":
            loc = self._page.locator(action.locator).first
            loc.click()
            if delay_ms:
                time.sleep(delay_ms / 1000.0)
        elif action.type == "type":
            loc = self._page.locator(action.locator).first
            loc.fill(action.value or "")
            if delay_ms:
                time.sleep(delay_ms / 1000.0)
        elif action.type == "select":
            loc = self._page.locator(action.locator).first
            loc.select_option(action.value or "")
        elif action.type == "scroll":
            self._page.evaluate("window.scrollBy(0, window.innerHeight)")
            time.sleep(0.5)
        elif action.type == "wait":
            self._page.wait_for_load_state("networkidle")
        elif action.type == "wait_ms":
            ms = int(action.value or 0)
            time.sleep(ms / 1000.0)
        elif action.type == "open":
            self._page.goto(action.value or "", wait_until="domcontentloaded")
            page_delay = int(res.globals_.get("page_load_delay_ms", 0))
            if page_delay:
                time.sleep(page_delay / 1000.0)
        elif action.type == "open_bound":
            # Open a URL from a previously extracted field
            pass

    def _handle_expansion(self, rule: RuleNode, res: ResourceContext,
                          current_url: str) -> list[dict]:
        """Handle element/page expansion."""
        exp = rule.expansion
        records = []

        if exp.over == "elements":
            records = self._expand_elements(rule, res, current_url)
        elif exp.over == "pages_next":
            records = self._expand_pages_next(rule, res, current_url)
        elif exp.over == "pages_numeric":
            records = self._expand_pages_numeric(rule, res, current_url)

        return records

    def _expand_elements(self, rule: RuleNode, res: ResourceContext,
                         current_url: str) -> list[dict]:
        """Expand over matching elements."""
        exp = rule.expansion
        selector = exp.scope
        limit = exp.limit
        records = []

        try:
            elements = self._page.query_selector_all(selector)
        except Exception as e:
            logger.warn(f"  Element expansion failed for '{selector}': {e}")
            return records

        if limit and len(elements) > limit:
            elements = elements[:limit]

        for elem in elements:
            record = self._extract_from_element(rule, elem, current_url)

            # Walk children with this element as scope
            child_records: dict[str, list] = {}
            for child in rule.children:
                child_data = self._walk_rule(child, res, elem, current_url)
                if child_data:
                    child_records[child.name] = child_data

            if record is not None:
                if child_records:
                    record["_children"] = child_records
                records.append(record)

        return records

    def _expand_pages_next(self, rule: RuleNode, res: ResourceContext,
                           current_url: str) -> list[dict]:
        """Paginate by clicking a next button."""
        exp = rule.expansion
        next_selector = exp.locator
        limit = exp.limit
        records = []

        for page_num in range(limit):
            page_url = self._page.url
            logger.info(f"    Page {page_num + 1}: {page_url}")

            # Walk children on this page
            for child in rule.children:
                child_data = self._walk_rule(child, res, self._page, page_url)
                if child_data:
                    records.extend(child_data)

            # Try to click next
            try:
                next_btn = self._page.query_selector(next_selector)
                if not next_btn:
                    logger.info(f"    No next button found, stopping pagination")
                    break
                next_btn.click()
                self._page.wait_for_load_state("domcontentloaded")
                page_delay = int(res.globals_.get("page_load_delay_ms", 0))
                if page_delay:
                    time.sleep(page_delay / 1000.0)
                time.sleep(0.5)  # Brief settle
            except Exception as e:
                logger.info(f"    Pagination ended: {e}")
                break

        return records

    def _expand_pages_numeric(self, rule: RuleNode, res: ResourceContext,
                              current_url: str) -> list[dict]:
        """Paginate by clicking numeric page controls."""
        exp = rule.expansion
        control_selector = exp.locator
        start = exp.start
        limit = exp.limit
        records = []

        for page_num in range(start, start + limit):
            page_url = self._page.url
            logger.info(f"    Numeric page {page_num}: {page_url}")

            # Walk children on this page
            for child in rule.children:
                child_data = self._walk_rule(child, res, self._page, page_url)
                if child_data:
                    records.extend(child_data)

            # Click the next page number
            next_num = page_num + 1
            if next_num >= start + limit:
                break

            try:
                # Try to find a link with the page number
                page_links = self._page.query_selector_all(control_selector)
                clicked = False
                for link in page_links:
                    href = link.get_attribute("href") or ""
                    text = link.text_content() or ""
                    if f"p={next_num}" in href or text.strip() == str(next_num):
                        link.click()
                        self._page.wait_for_load_state("domcontentloaded")
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

    def _extract_from_scope(self, rule: RuleNode, scope: Any,
                            current_url: str) -> dict | None:
        """Extract fields from the current page scope."""
        if not rule.field_specs and not rule.table_spec:
            return None

        if rule.field_specs:
            data = {}
            for fs in rule.field_specs:
                data[fs.name] = self._extract_field(fs, self._page)
            return {
                "node": rule.name,
                "url": current_url,
                "data": data,
                "extracted_at": datetime.now(timezone.utc).isoformat(),
            }

        if rule.table_spec:
            return self._extract_table_data(rule.table_spec, self._page, current_url, rule.name)

        return None

    def _extract_from_element(self, rule: RuleNode, element: Any,
                              current_url: str) -> dict | None:
        """Extract fields from a specific element."""
        if rule.field_specs:
            data = {}
            for fs in rule.field_specs:
                data[fs.name] = self._extract_field(fs, element)
            return {
                "node": rule.name,
                "url": current_url,
                "data": data,
                "extracted_at": datetime.now(timezone.utc).isoformat(),
            }

        if rule.table_spec:
            return self._extract_table_data(rule.table_spec, element, current_url, rule.name)

        return None

    def _extract_field(self, fs: FieldSpec, scope: Any) -> Any:
        """Extract a single field value from scope."""
        try:
            if fs.extractor == "text":
                el = scope.query_selector(fs.locator)
                if el:
                    return (el.text_content() or "").strip()
                return ""
            elif fs.extractor == "attr":
                el = scope.query_selector(fs.locator)
                if el and fs.attr:
                    return (el.get_attribute(fs.attr) or "").strip()
                return ""
            elif fs.extractor == "grouped":
                elements = scope.query_selector_all(fs.locator)
                return [
                    (el.text_content() or "").strip()
                    for el in elements
                    if (el.text_content() or "").strip()
                ]
            elif fs.extractor == "html":
                el = scope.query_selector(fs.locator)
                if el:
                    return el.inner_html()
                return ""
            elif fs.extractor == "link":
                el = scope.query_selector(fs.locator)
                if el:
                    return el.get_attribute("href") or ""
                return ""
            elif fs.extractor == "image":
                el = scope.query_selector(fs.locator)
                if el:
                    return el.get_attribute("src") or ""
                return ""
        except Exception as e:
            logger.warn(f"    Extract {fs.name} failed: {e}")
        return ""

    def _extract_table_data(self, tspec: TableSpec, scope: Any,
                            current_url: str, rule_name: str) -> dict | None:
        """Extract a table into structured records."""
        try:
            table_el = scope.query_selector(tspec.locator)
            if not table_el:
                # If the scope itself matches (e.g., expanding over "table" elements),
                # use the scope element directly
                tag = ""
                try:
                    tag = scope.evaluate("el => el.tagName.toLowerCase()")
                except Exception:
                    pass
                if tag == "table":
                    table_el = scope
            if not table_el:
                return None

            rows = table_el.query_selector_all("tr")
            if not rows or len(rows) <= tspec.header_row:
                return None

            # Get headers
            header_row = rows[tspec.header_row]
            header_cells = header_row.query_selector_all("th, td")
            headers = [(c.text_content() or "").strip() for c in header_cells]

            # Map field specs to column indices
            field_map: dict[str, int] = {}
            for fs in tspec.fields:
                for i, h in enumerate(headers):
                    if h == fs.header:
                        field_map[fs.name] = i
                        break

            # Extract data rows
            table_records = []
            for row in rows[tspec.header_row + 1:]:
                cells = row.query_selector_all("td, th")
                cell_texts = [(c.text_content() or "").strip() for c in cells]
                if not any(cell_texts):
                    continue
                rec = {}
                for fname, idx in field_map.items():
                    if idx < len(cell_texts):
                        rec[fname] = cell_texts[idx]
                    else:
                        rec[fname] = ""
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

    def _emit_records(self, target: str, rule: RuleNode,
                      records: list[dict], current_url: str) -> None:
        """Emit records to an artifact store."""
        if target not in self.ctx.artifact_store:
            self.ctx.artifact_store[target] = []

        art = self.ctx.artifacts.get(target)
        flatten_field = rule.emit_flatten_by.get(target)
        merge_key = rule.emit_merge_on.get(target)

        for record in records:
            if not record:
                continue

            if flatten_field:
                # Flatten: extract the named field (expected to be a list of dicts)
                # and emit each sub-record as a top-level record
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
                # Merge on key: update existing record with same key value
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
        """Write artifact outputs to JSON files."""
        # Write deployment summary
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

            # Apply deduplication
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

            # Apply JMESPath query if specified
            output_data = records
            if art.query:
                try:
                    import jmespath
                    output_data = jmespath.search(art.query, records)
                except ImportError:
                    logger.warn("jmespath not installed, skipping query transform")
                except Exception as e:
                    logger.warn(f"JMESPath query failed for {art_name}: {e}")

            # Determine structure
            if art.structure == "flat":
                # Flatten nested records: just emit data dicts
                flat = []
                for r in (output_data if isinstance(output_data, list) else [output_data]):
                    if isinstance(r, dict):
                        flat.append(r)
                output_data = flat

            # Write path
            override = self.ctx.write_overrides.get(art_name)
            if override:
                out_path = Path(override)
            else:
                out_path = Path(output_dir) / f"{self.ctx.name}_{art_name}.json"

            out_path.parent.mkdir(parents=True, exist_ok=True)
            with open(out_path, "w") as f:
                json.dump(output_data, f, indent=2, ensure_ascii=False)
            logger.info(f"  Wrote {len(records)} records to {out_path}")

        # Write deployment summary
        summary_path = Path(output_dir) / f"{self.ctx.name}.json"
        with open(summary_path, "w") as f:
            json.dump(summary, f, indent=2)
        logger.info(f"  Wrote deployment summary to {summary_path}")

    def _check_quality_gates(self) -> None:
        """Check quality gates and log warnings."""
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
        # Combination expansion is handled by the generator producing
        # individual click rules for each combination value

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

    # -- Hooks and configuration (stubs for now) --

    @keyword('And I register hook "${name}" at "${lifecycle_point}"')
    def register_hook(self, name: str, lifecycle_point: str, *config: str) -> None:
        self._record("register_hook", name, lifecycle_point, *config)

    @keyword("Given I configure state setup")
    def configure_state_setup(self, *actions: str) -> None:
        self._record("configure_state_setup", *actions)

    @keyword("And I configure interrupts")
    def configure_interrupts(self, *dismissals: str) -> None:
        self._record("configure_interrupts", *dismissals)

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
