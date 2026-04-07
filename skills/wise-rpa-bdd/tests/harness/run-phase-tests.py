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


def run(cmd: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, cwd=REPO_ROOT, text=True, capture_output=True, check=False)


def main() -> int:
    failures: list[str] = []
    for name in EXAMPLE_NAMES:
        example_dir = EXAMPLES_DIR / name
        task = example_dir / "task.md"
        evidence = example_dir / "evidence.md"
        suite = example_dir / "suite.robot"
        validate_output = example_dir / "output" / "validate.txt"
        dryrun_output = example_dir / "output" / "dryrun.txt"
        print(f"\n== {name} ==")

        for path in (task, evidence, suite, validate_output, dryrun_output):
            if not path.exists():
                failures.append(f"missing file: {path}")
                print(f"  missing: {path.name}")
        if failures:
            continue

        print("  orient/evidence/output files: PASS")

        validate = run([sys.executable, str(SCRIPTS_DIR / "validate_suite.py"), str(suite)])
        if validate.returncode != 0:
            failures.append(validate.stdout + validate.stderr)
            print("  bdd format: FAIL")
            continue
        print("  bdd format: PASS")

        dryrun = run(
            [
                sys.executable,
                "-m",
                "robot",
                "--dryrun",
                "--output",
                "NONE",
                "--log",
                "NONE",
                "--report",
                "NONE",
                "--pythonpath",
                str(SCRIPTS_DIR),
                str(suite),
            ]
        )
        if dryrun.returncode != 0:
            failures.append(dryrun.stdout + dryrun.stderr)
            print("  robot dryrun: FAIL")
            continue
        print("  robot dryrun: PASS")

    if failures:
        print(f"\n{len(failures)} failure(s)")
        for failure in failures[:10]:
            print(failure)
        return 1

    print("\nAll phase examples passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
