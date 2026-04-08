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

COL_PROFILE = 40
COL_STEP = 14


def discover_profiles(filter_text: str | None) -> list[Path]:
    profiles = sorted(REGRESSION_PROFILES.rglob("*.yaml"))
    if filter_text:
        profiles = [path for path in profiles if filter_text in path.name or filter_text in str(path)]
    return profiles


def run(cmd: list[str], cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, cwd=cwd, text=True, capture_output=True, check=False)


def fmt_status(ok: bool) -> str:
    return "PASS" if ok else "FAIL"


def print_header() -> None:
    header = (
        f"{'Profile':<{COL_PROFILE}}"
        f"{'Generate':<{COL_STEP}}"
        f"{'BDD Valid':<{COL_STEP}}"
        f"{'Dryrun':<{COL_STEP}}"
    )
    print(header)
    print("-" * len(header))


def print_row(name: str, gen: str, bdd: str, dry: str) -> None:
    print(
        f"{name:<{COL_PROFILE}}"
        f"{gen:<{COL_STEP}}"
        f"{bdd:<{COL_STEP}}"
        f"{dry:<{COL_STEP}}"
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--filter")
    args = parser.parse_args()

    profiles = discover_profiles(args.filter)
    if not profiles:
        print("No profiles found.")
        return 1

    print(f"Testing {len(profiles)} regression profiles with wise-rpa-bdd\n")
    print_header()

    results: list[dict] = []
    errors: list[tuple[str, str, str]] = []

    with tempfile.TemporaryDirectory(prefix="wise-rpa-bdd-") as tmp:
        tmpdir = Path(tmp)
        for profile in profiles:
            suite = tmpdir / f"{profile.stem}.robot"
            name = profile.stem
            gen_ok = bdd_ok = dry_ok = False

            gen = run(
                [sys.executable, str(SCRIPTS / "generate_from_wise_yaml.py"), str(profile), str(suite)],
                cwd=REPO_ROOT,
            )
            gen_ok = gen.returncode == 0
            if not gen_ok:
                errors.append((name, "generate", (gen.stderr or gen.stdout).strip()))
                print_row(name, fmt_status(gen_ok), "-", "-")
                results.append({"name": name, "gen": gen_ok, "bdd": False, "dry": False})
                continue

            validate = run([sys.executable, str(SCRIPTS / "validate_suite.py"), str(suite)], cwd=REPO_ROOT)
            bdd_ok = validate.returncode == 0
            if not bdd_ok:
                detail = (validate.stdout + validate.stderr).strip()
                errors.append((name, "BDD validate", detail))
                print_row(name, fmt_status(gen_ok), fmt_status(bdd_ok), "-")
                results.append({"name": name, "gen": gen_ok, "bdd": bdd_ok, "dry": False})
                continue

            dryrun = run(
                [
                    sys.executable, "-m", "robot",
                    "--dryrun", "--output", "NONE", "--log", "NONE", "--report", "NONE",
                    "--pythonpath", str(SCRIPTS),
                    str(suite),
                ],
                cwd=REPO_ROOT,
            )
            dry_ok = dryrun.returncode == 0
            if not dry_ok:
                detail = (dryrun.stdout + dryrun.stderr).strip()
                errors.append((name, "dryrun", detail))

            print_row(name, fmt_status(gen_ok), fmt_status(bdd_ok), fmt_status(dry_ok))
            results.append({"name": name, "gen": gen_ok, "bdd": bdd_ok, "dry": dry_ok})

    # Summary
    total = len(results)
    passed = sum(1 for r in results if r["gen"] and r["bdd"] and r["dry"])
    failed = total - passed
    print(f"\n{passed}/{total} passed, {failed} failed")

    # Error details
    if errors:
        print("\n=== Error Details ===")
        for name, step, detail in errors:
            print(f"\n-- {name} ({step}) --")
            lines = detail.splitlines()
            for line in lines[-15:]:
                print(f"  {line}")

    return 0 if failed == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
