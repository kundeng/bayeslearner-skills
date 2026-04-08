#!/usr/bin/env python3
"""Generate strict Robot Framework BDD suites from the regression profile corpus."""

from __future__ import annotations

import argparse
import re
from pathlib import Path
from typing import Any

import yaml


def quote(value: Any) -> str:
    return f'"{value}"'


def var_name(prefix: str, name: str) -> str:
    slug = re.sub(r"[^A-Za-z0-9]+", "_", name).strip("_").upper()
    return f"${{{prefix}_{slug}}}"


def scalar(value: Any) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    return str(value)


def add_step(lines: list[str], text: str) -> None:
    lines.append(f"    {text}")


def add_continuation(lines: list[str], *cells: str) -> None:
    padded = "    ".join(cells)
    lines.append(f"    ...    {padded}")


def artifact_catalog(lines: list[str], artifacts: dict[str, Any], artifact_vars: dict[str, str]) -> None:
    lines.append("Artifact Catalog")
    for name, spec in artifacts.items():
        add_step(lines, f'Given I register artifact "{artifact_vars[name]}"')
        for field_name, field_spec in spec.get("fields", {}).items():
            add_continuation(
                lines,
                f"field={field_name}",
                f"type={field_spec.get('type', 'string')}",
                f"required={scalar(field_spec.get('required', False))}",
            )
        options: list[str] = []
        for key in ("format", "output", "structure", "dedupe", "query", "consumes", "description"):
            if key in spec:
                options.append(f"{key}={scalar(spec[key])}")
        if options:
            add_step(lines, f'And I set artifact options for "{artifact_vars[name]}"')
            for option in options:
                add_continuation(lines, option)
    lines.append("")


def render_state(lines: list[str], state: dict[str, Any]) -> None:
    if "url_pattern" in state:
        add_step(lines, f'Given url matches {quote(state["url_pattern"])}')
    if "selector_exists" in state:
        add_step(lines, f'And selector {quote(state["selector_exists"])} exists')
    if "table_headers" in state:
        headers = " | ".join(str(h) for h in state["table_headers"])
        add_step(lines, f'And table headers are {quote(headers)}')


def render_action(lines: list[str], action: list[dict[str, Any]]) -> None:
    for step in action:
        if "click" in step:
            payload = step["click"]
            add_step(lines, f'When I click locator {quote(payload["css"])}')
            for key, value in step.items():
                if key != "click":
                    add_continuation(lines, f"{key}={scalar(value)}")
            for key, value in payload.items():
                if key != "css":
                    add_continuation(lines, f"{key}={scalar(value)}")
        elif "wait" in step:
            payload = step["wait"]
            if payload.get("idle"):
                add_step(lines, "When I wait for idle")
            elif "ms" in payload:
                add_step(lines, f'When I wait {payload["ms"]} ms')
        elif "navigate" in step:
            payload = step["navigate"]
            add_step(lines, f'When I open {quote(payload["to"])}')
        elif "input" in step:
            payload = step["input"]
            add_step(lines, f'When I type {quote(payload["value"])} into locator {quote(payload["css"])}')
        elif "select" in step:
            payload = step["select"]
            add_step(lines, f'When I type {quote(payload["value"])} into locator {quote(payload["css"])}')


def render_expand(lines: list[str], expand: dict[str, Any]) -> None:
    over = expand.get("over")
    if over == "elements":
        scope = expand["scope"]
        order = expand.get("order")
        if order:
            add_step(lines, f'When I expand over elements {quote(scope)} with order {quote(order)}')
        else:
            add_step(lines, f'When I expand over elements {quote(scope)}')
        for key in ("limit", "sentinel", "sentinel_gone", "stable"):
            if key in expand:
                add_continuation(lines, f"{key}={scalar(expand[key])}")
    elif over == "pages":
        strategy = expand.get("strategy", "next")
        control = expand.get("control", "")
        limit = expand.get("limit", 1)
        if strategy == "numeric":
            start = expand.get("start", 1)
            add_step(lines, f'When I paginate by numeric control {quote(control)} from {start} up to {limit} pages')
        else:
            add_step(lines, f'When I paginate by next button {quote(control)} up to {limit} pages')
        for key in ("sentinel", "sentinel_gone", "stable"):
            if key in expand:
                add_continuation(lines, f"{key}={scalar(expand[key])}")
    elif over == "combinations":
        add_step(lines, "When I expand over combinations")
        for axis in expand.get("axes", []):
            add_continuation(
                lines,
                f"action={scalar(axis.get('action', 'type'))}",
                f"control={scalar(axis.get('control', ''))}",
                f"values={scalar(axis.get('values', 'auto'))}",
            )


def render_extract(lines: list[str], extract: list[dict[str, Any]]) -> None:
    table_extracts = [item["table"] for item in extract if "table" in item]
    non_table = [item for item in extract if "table" not in item and "ai" not in item]
    ai_items = [item for item in extract if "ai" in item]

    if non_table:
        add_step(lines, "Then I extract fields")
        for item in non_table:
            extractor, payload = next(iter(item.items()))
            cells = [
                f"field={payload['name']}",
                f"extractor={extractor}",
            ]
            if "css" in payload:
                cells.append(f'locator={quote(payload["css"])}')
            if "attr" in payload:
                cells.append(f'attr={quote(payload["attr"])}')
            if "input" in payload:
                cells.append(f'input={quote(payload["input"])}')
            if "prompt" in payload:
                cells.append(f'prompt={quote(payload["prompt"])}')
            add_continuation(lines, *cells)

    if ai_items:
        render_ai_extract(lines, ai_items)

    for table in table_extracts:
        add_step(lines, f'Then I extract table {quote(table["name"])} from {quote(table["css"])}')
        if "header_row" in table:
            add_continuation(lines, f"header_row={scalar(table['header_row'])}")
        for column in table.get("columns", []):
            cells = [f"field={column['name']}"]
            if "header" in column:
                cells.append(f'header={quote(column["header"])}')
            add_continuation(lines, *cells)


def render_ai_extract(lines: list[str], ai_items: list[dict[str, Any]]) -> None:
    for item in ai_items:
        payload = item["ai"]
        add_step(lines, f'Then I extract with AI {quote(payload["name"])}')
        if "prompt" in payload:
            add_continuation(lines, f'prompt={quote(payload["prompt"])}')
        if "input" in payload:
            add_continuation(lines, f'input={quote(payload["input"])}')
        if "schema" in payload:
            import json
            add_continuation(lines, f'schema={quote(json.dumps(payload["schema"]))}')
        if "categories" in payload:
            cats = "|".join(payload["categories"])
            add_continuation(lines, f'categories={cats}')


def render_hooks(lines: list[str], hooks: dict[str, Any]) -> None:
    for lifecycle_point, hook_list in hooks.items():
        if not isinstance(hook_list, list):
            hook_list = [hook_list]
        for hook in hook_list:
            name = hook.get("name", lifecycle_point)
            add_step(lines, f'And I register hook {quote(name)} at {quote(lifecycle_point)}')
            for key, value in hook.get("config", {}).items():
                add_continuation(lines, f"{key}={scalar(value)}")


def render_setup(lines: list[str], setup: dict[str, Any]) -> None:
    add_step(lines, "Given I configure state setup")
    if "skip_when" in setup:
        add_continuation(lines, f'skip_when={setup["skip_when"]}')
    for action in setup.get("actions", []):
        if "open" in action:
            add_continuation(lines, f'action=open url="{action["open"]}"')
        elif "click" in action:
            add_continuation(lines, f'action=click css="{action["click"]["css"]}"')
        elif "input" in action:
            payload = action["input"]
            add_continuation(lines, f'action=input css="{payload["css"]}" value="{payload["value"]}"')
        elif "password" in action:
            payload = action["password"]
            add_continuation(lines, f'action=password css="{payload["css"]}" value="{payload["value"]}"')


def render_emit(lines: list[str], emit: Any, artifact_vars: dict[str, str]) -> None:
    if isinstance(emit, str):
        target = artifact_vars.get(emit, emit)
        add_step(lines, f'And I emit to artifact "{target}"')
        return
    for item in emit:
        target = item["to"]
        rendered_target = artifact_vars.get(target, target)
        if "flatten" in item:
            add_step(
                lines,
                f'And I emit to artifact "{rendered_target}" flattened by "{item["flatten"]}"',
            )
        else:
            add_step(lines, f'And I emit to artifact "{rendered_target}"')


def render_quality(lines: list[str], quality: dict[str, Any]) -> None:
    lines.append("Quality Gates")
    if "min_records" in quality:
        add_step(lines, f'And I set quality gate min records to {quality["min_records"]}')
    for field, percent in quality.get("min_filled_pct", {}).items():
        add_step(lines, f'And I set filled percentage for "{field}" to {percent}')
    lines.append("")


def generate_suite(profile: dict[str, Any], source: Path) -> str:
    deployment = profile["name"]
    artifacts = profile.get("artifacts", {})
    resources = profile.get("resources", [])
    quality = profile.get("quality", {})

    artifact_vars = {name: var_name("ARTIFACT", name) for name in artifacts}
    entry_vars: dict[str, str] = {}
    for resource in resources:
        entry = resource.get("entry", {})
        url = entry.get("url")
        if isinstance(url, str) and not url.startswith("{"):
            entry_vars[resource["name"]] = var_name("ENTRY", resource["name"])

    lines = [
        "*** Settings ***",
        f"Documentation     Generated from {source.relative_to(source.parents[3])}",
        "Library           WiseRpaBDD",
        'Suite Setup       Given I start deployment "${DEPLOYMENT}"',
        "Suite Teardown    Then I finalize deployment",
        "",
        "*** Variables ***",
        f"${{DEPLOYMENT}}    {deployment}",
    ]

    for name, value in artifact_vars.items():
        lines.append(f"{value}    {name}")
    for resource_name, value in entry_vars.items():
        url = next(r for r in resources if r["name"] == resource_name)["entry"]["url"]
        lines.append(f"{value}    {url}")
    lines.append("")
    lines.append("*** Test Cases ***")

    if artifacts:
        artifact_catalog(lines, artifacts, artifact_vars)

    for resource in resources:
        lines.append(f'Resource {resource["name"]}')
        produced = resource.get("produces")
        consumed = resource.get("consumes")
        if produced:
            add_step(lines, f"[Documentation]    Produces: {produced}")
        entry = resource.get("entry", {})
        url = entry.get("url")
        if isinstance(url, str) and not url.startswith("{"):
            add_step(lines, f'[Setup]    Given I start resource "{resource["name"]}" at "{entry_vars[resource["name"]]}"')
        else:
            add_step(lines, f'[Setup]    Given I start resource "{resource["name"]}"')
            if consumed:
                consume_list = consumed if isinstance(consumed, list) else [consumed]
                for artifact in consume_list:
                    add_step(lines, f'Given I consume artifact "{artifact}"')
            if isinstance(url, dict) and "from" in url:
                add_step(lines, f'Given I resolve entry from "{url["from"]}"')
            elif isinstance(url, str):
                add_step(lines, f'Given I start resource "{resource["name"]}" at "{url}"')

        globals_ = resource.get("globals")
        if globals_:
            add_step(lines, "And I set resource globals")
            for key, value in globals_.items():
                add_continuation(lines, f"{key}={scalar(value)}")

        setup = resource.get("setup")
        if setup:
            render_setup(lines, setup)

        hooks = resource.get("hooks")
        if hooks:
            render_hooks(lines, hooks)

        any_emit = False
        last_extract_index: int | None = None
        for node in resource.get("nodes", []):
            add_step(lines, f'And I begin rule "{node["name"]}"')
            parents = node.get("parents", [])
            if parents:
                add_step(lines, f'And I declare parents "{", ".join(parents)}"')
            if node.get("state"):
                render_state(lines, node["state"])
            if node.get("action"):
                render_action(lines, node["action"])
            if node.get("expand"):
                render_expand(lines, node["expand"])
            if node.get("extract"):
                render_extract(lines, node["extract"])
                last_extract_index = len(lines)
            if node.get("emit"):
                render_emit(lines, node["emit"], artifact_vars)
                any_emit = True
            if node.get("consumes"):
                consume_list = node["consumes"] if isinstance(node["consumes"], list) else [node["consumes"]]
                for artifact in consume_list:
                    add_step(lines, f'Given I consume artifact "{artifact}"')

        # Synthesize emit steps when resource.produces is set but no node has explicit emit
        produced = resource.get("produces")
        if produced and not any_emit and last_extract_index is not None:
            emit_lines: list[str] = []
            for artifact_name in produced:
                target = artifact_vars.get(artifact_name, artifact_name)
                emit_lines.append(f'    And I emit to artifact "{target}"')
            for i, emit_line in enumerate(emit_lines):
                lines.insert(last_extract_index + i, emit_line)

        lines.append("")

    if quality:
        render_quality(lines, quality)

    return "\n".join(lines).rstrip() + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("target", type=Path)
    args = parser.parse_args()

    profile = yaml.safe_load(args.source.read_text())
    suite = generate_suite(profile, args.source.resolve())
    args.target.parent.mkdir(parents=True, exist_ok=True)
    args.target.write_text(suite)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
