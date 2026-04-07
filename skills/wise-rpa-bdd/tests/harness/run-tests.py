#!/usr/bin/env python3
"""Validate wise-rpa-bdd against the bundled regression profile corpus."""

from __future__ import annotations

import argparse
import subprocess
import sys
import tempfile
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[4]
NEW_SKILL = REPO_ROOT / "skills" / "wise-rpa-bdd"
REGRESSION_PROFILES = REPO_ROOT / "skills" / "wise-scraper" / "tests" / "profiles"
SCRIPTS = NEW_SKILL / "scripts"


def discover_profiles(filter_text: str | None) -> list[Path]:
    profiles = sorted(REGRESSION_PROFILES.rglob("*.yaml"))
    if filter_text:
        profiles = [path for path in profiles if filter_text in path.name or filter_text in str(path)]
    return profiles


def run(cmd: list[str], cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, cwd=cwd, text=True, capture_output=True, check=False)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--filter")
    args = parser.parse_args()

    profiles = discover_profiles(args.filter)
    if not profiles:
        print("No profiles found.")
        return 1

    print(f"Testing {len(profiles)} regression profiles with wise-rpa-bdd")
    failures: list[tuple[Path, str]] = []

    with tempfile.TemporaryDirectory(prefix="wise-rpa-bdd-") as tmp:
        tmpdir = Path(tmp)
        for profile in profiles:
            suite = tmpdir / f"{profile.stem}.robot"
            print(f"\n== {profile.relative_to(REPO_ROOT)} ==")

            gen = run(
                [sys.executable, str(SCRIPTS / "generate_from_wise_yaml.py"), str(profile), str(suite)],
                cwd=REPO_ROOT,
            )
            if gen.returncode != 0:
                failures.append((profile, gen.stderr or gen.stdout))
                print("  generate: FAIL")
                continue
            print("  generate: PASS")

            validate = run([sys.executable, str(SCRIPTS / "validate_suite.py"), str(suite)], cwd=REPO_ROOT)
            if validate.returncode != 0:
                failures.append((profile, validate.stdout + validate.stderr))
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
                    str(SCRIPTS),
                    str(suite),
                ],
                cwd=REPO_ROOT,
            )
            if dryrun.returncode != 0:
                failures.append((profile, dryrun.stdout + dryrun.stderr))
                print("  robot dryrun: FAIL")
                continue
            print("  robot dryrun: PASS")

    if failures:
        print(f"\n{len(failures)} profile(s) failed.")
        for profile, output in failures[:10]:
            print(f"\n-- {profile.relative_to(REPO_ROOT)} --")
            print(output.strip().splitlines()[-10:])
        return 1

    print("\nAll profiles passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
