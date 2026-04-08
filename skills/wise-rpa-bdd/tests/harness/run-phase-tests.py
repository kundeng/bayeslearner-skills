#!/usr/bin/env python3
"""Validate checked-in phase examples for wise-rpa-bdd."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[4]
SKILL_DIR = REPO_ROOT / "skills" / "wise-rpa-bdd"
EXAMPLES_DIR = SKILL_DIR / "examples"
SCRIPTS_DIR = SKILL_DIR / "scripts"
EXAMPLE_NAMES = ["quotes", "revspin", "splunk-itsi"]

COL_PROFILE = 20
COL_STEP = 14


def run(cmd: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, cwd=REPO_ROOT, text=True, capture_output=True, check=False)


def fmt_status(ok: bool) -> str:
    return "PASS" if ok else "FAIL"


def print_header() -> None:
    header = (
        f"{'Example':<{COL_PROFILE}}"
        f"{'Files':<{COL_STEP}}"
        f"{'BDD Valid':<{COL_STEP}}"
        f"{'Dryrun':<{COL_STEP}}"
    )
    print(header)
    print("-" * len(header))


def print_row(name: str, files: str, bdd: str, dry: str) -> None:
    print(
        f"{name:<{COL_PROFILE}}"
        f"{files:<{COL_STEP}}"
        f"{bdd:<{COL_STEP}}"
        f"{dry:<{COL_STEP}}"
    )


def main() -> int:
    print(f"Validating {len(EXAMPLE_NAMES)} phase examples\n")
    print_header()

    errors: list[tuple[str, str, str]] = []
    all_passed = True

    for name in EXAMPLE_NAMES:
        example_dir = EXAMPLES_DIR / name
        required_files = [
            example_dir / "task.md",
            example_dir / "evidence.md",
            example_dir / "suite.robot",
            example_dir / "output" / "validate.txt",
            example_dir / "output" / "dryrun.txt",
        ]

        missing = [p for p in required_files if not p.exists()]
        files_ok = len(missing) == 0
        if not files_ok:
            for m in missing:
                errors.append((name, "files", f"missing: {m.name}"))
            print_row(name, fmt_status(False), "-", "-")
            all_passed = False
            continue

        suite = example_dir / "suite.robot"
        validate = run([sys.executable, str(SCRIPTS_DIR / "validate_suite.py"), str(suite)])
        bdd_ok = validate.returncode == 0
        if not bdd_ok:
            detail = (validate.stdout + validate.stderr).strip()
            errors.append((name, "BDD validate", detail))
            print_row(name, fmt_status(files_ok), fmt_status(bdd_ok), "-")
            all_passed = False
            continue

        dryrun = run(
            [
                sys.executable, "-m", "robot",
                "--dryrun", "--output", "NONE", "--log", "NONE", "--report", "NONE",
                "--pythonpath", str(SCRIPTS_DIR),
                str(suite),
            ]
        )
        dry_ok = dryrun.returncode == 0
        if not dry_ok:
            detail = (dryrun.stdout + dryrun.stderr).strip()
            errors.append((name, "dryrun", detail))
            all_passed = False

        print_row(name, fmt_status(files_ok), fmt_status(bdd_ok), fmt_status(dry_ok))

    # Summary
    total = len(EXAMPLE_NAMES)
    passed = total if all_passed else total - len({e[0] for e in errors})
    failed = total - passed
    print(f"\n{passed}/{total} passed, {failed} failed")

    if errors:
        print("\n=== Error Details ===")
        for name, step, detail in errors:
            print(f"\n-- {name} ({step}) --")
            for line in detail.splitlines()[-15:]:
                print(f"  {line}")

    return 0 if all_passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
