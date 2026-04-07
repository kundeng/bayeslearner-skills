#!/usr/bin/env python3
"""Agent E2E harness for the wise-rpa-bdd quotes example.

Validates that every /rrpa-* phase produced its expected artifact and that
the suite passes both BDD-format validation and robot --dryrun.
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[4]
SKILL_DIR = REPO_ROOT / "skills" / "wise-rpa-bdd"
SCRIPTS_DIR = SKILL_DIR / "scripts"
QUOTES_DIR = SKILL_DIR / "examples" / "quotes"

# All required phase artifacts in phase order.
REQUIRED_ARTIFACTS = [
    "task.md",        # orient – task brief
    "orient.md",      # orient – goal/constraints
    "explore.md",     # explore – site observations
    "evidence.md",    # evidence – confirmed selectors
    "suite.robot",    # draft – BDD suite
    "output/validate.txt",  # validate – BDD format check
    "output/dryrun.txt",    # validate – robot dryrun log
    "refine.md",      # refine – review notes
    "ship.md",        # ship – readiness summary
]


def run(cmd: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, cwd=REPO_ROOT, text=True, capture_output=True, check=False)


def check_artifacts() -> list[str]:
    """Return list of failure messages for missing or empty artifacts."""
    failures: list[str] = []
    for rel in REQUIRED_ARTIFACTS:
        path = QUOTES_DIR / rel
        if not path.exists():
            failures.append(f"MISSING: {rel}")
        elif path.stat().st_size == 0:
            failures.append(f"EMPTY:   {rel}")
    return failures


def check_validate_suite() -> tuple[bool, str]:
    """Run validate_suite.py on suite.robot."""
    suite = QUOTES_DIR / "suite.robot"
    result = run([sys.executable, str(SCRIPTS_DIR / "validate_suite.py"), str(suite)])
    ok = result.returncode == 0
    output = (result.stdout + result.stderr).strip()
    return ok, output


def check_robot_dryrun() -> tuple[bool, str]:
    """Run robot --dryrun on suite.robot."""
    suite = QUOTES_DIR / "suite.robot"
    result = run([
        sys.executable, "-m", "robot",
        "--dryrun",
        "--output", "NONE",
        "--log", "NONE",
        "--report", "NONE",
        "--pythonpath", str(SCRIPTS_DIR),
        str(suite),
    ])
    ok = result.returncode == 0
    output = (result.stdout + result.stderr).strip()
    return ok, output


def main() -> int:
    print("== Agent E2E: quotes example ==\n")
    all_ok = True

    # 1. Artifact presence
    print("--- Phase artifacts ---")
    artifact_failures = check_artifacts()
    if artifact_failures:
        all_ok = False
        for f in artifact_failures:
            print(f"  FAIL  {f}")
    else:
        print(f"  PASS  All {len(REQUIRED_ARTIFACTS)} artifacts present and non-empty")

    # 2. BDD format validation
    print("\n--- BDD format validation ---")
    ok, output = check_validate_suite()
    if ok:
        print(f"  PASS  {output}")
    else:
        all_ok = False
        print(f"  FAIL  {output}")

    # 3. Robot dryrun
    print("\n--- Robot dryrun ---")
    ok, output = check_robot_dryrun()
    if ok:
        print(f"  PASS  robot --dryrun succeeded")
        # Print summary line from robot output
        for line in output.splitlines():
            if "pass" in line.lower() or "fail" in line.lower():
                print(f"        {line}")
    else:
        all_ok = False
        print(f"  FAIL  robot --dryrun failed")
        print(output)

    # Summary
    print()
    if all_ok:
        print("RESULT: ALL CHECKS PASSED")
        return 0
    else:
        print("RESULT: SOME CHECKS FAILED")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
