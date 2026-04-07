#!/usr/bin/env python3
"""Validate strict BDD formatting for Robot Framework suites."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


BDD_PREFIXES = ("Given ", "When ", "Then ", "And ", "But ")
SECTION_RE = re.compile(r"^\*\*\* (.+) \*\*\*$")
CELL_SPLIT_RE = re.compile(r"\s{2,}|\t+")


def starts_with_bdd(text: str) -> bool:
    return any(text.startswith(prefix) for prefix in BDD_PREFIXES)


def validate(path: Path) -> list[str]:
    errors: list[str] = []
    section = ""

    for lineno, raw_line in enumerate(path.read_text().splitlines(), start=1):
        line = raw_line.rstrip()
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        match = SECTION_RE.match(stripped)
        if match:
            section = match.group(1).lower()
            continue

        if section == "settings":
            if stripped.startswith(("Suite Setup", "Test Setup", "Suite Teardown", "Test Teardown")):
                parts = [p for p in CELL_SPLIT_RE.split(stripped) if p]
                if len(parts) >= 2 and not starts_with_bdd(parts[1]):
                    errors.append(f"{path}:{lineno}: setup/teardown must use BDD keyword")
            continue

        if section in {"test cases", "keywords"}:
            if raw_line.startswith("    ..."):
                continue
            if not raw_line.startswith(" "):
                if section == "keywords" and not starts_with_bdd(stripped):
                    errors.append(f"{path}:{lineno}: keyword definition must start with BDD prefix")
                continue
            parts = [p for p in CELL_SPLIT_RE.split(stripped) if p]
            if not parts:
                continue
            if parts[0] in {"[Setup]", "[Teardown]"}:
                if len(parts) < 2 or not starts_with_bdd(parts[1]):
                    errors.append(f"{path}:{lineno}: setup/teardown step must use BDD keyword")
                continue
            if parts[0] == "[Documentation]":
                continue
            if not starts_with_bdd(parts[0]):
                errors.append(f"{path}:{lineno}: step must start with BDD prefix")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("suite", type=Path)
    args = parser.parse_args()

    errors = validate(args.suite)
    if errors:
        for error in errors:
            print(error)
        return 1
    print(f"BDD format OK: {args.suite}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
