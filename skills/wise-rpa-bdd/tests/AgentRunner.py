"""Robot Framework keyword library for testing the wise-rpa-bdd skill.

Provides keywords to:
1. Invoke Claude via Agent SDK with a requirement (full explore flow)
2. Validate BDD format of generated .robot files
3. Run robot --dryrun to prove keyword resolution
4. Compare against vetted golden baselines

Also usable standalone:
    python AgentRunner.py validate path/to/suite.robot
    python AgentRunner.py dryrun   path/to/suite.robot
"""

from __future__ import annotations

import asyncio
import re
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

from robot.api import logger
from robot.api.deco import keyword, library


SKILL_DIR = Path(__file__).resolve().parent.parent
REPO_ROOT = SKILL_DIR.parent.parent

# ---------------------------------------------------------------------------
# BDD format validation (replaces validate_suite.py)
# ---------------------------------------------------------------------------

BDD_PREFIXES = ("Given ", "When ", "Then ", "And ", "But ")
SECTION_RE = re.compile(r"^\*\*\* (.+) \*\*\*$")
CELL_SPLIT_RE = re.compile(r"\s{2,}|\t+")


def _starts_with_bdd(text: str) -> bool:
    return any(text.startswith(p) for p in BDD_PREFIXES)


def validate_bdd(path: Path) -> list[str]:
    """Check that every executable step uses Given/When/Then/And/But."""
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
            if stripped.startswith(("Suite Setup", "Test Setup",
                                    "Suite Teardown", "Test Teardown")):
                parts = [p for p in CELL_SPLIT_RE.split(stripped) if p]
                if len(parts) >= 2 and not _starts_with_bdd(parts[1]):
                    errors.append(f"{path}:{lineno}: setup/teardown must use BDD keyword")
            continue
        if section in {"test cases", "keywords"}:
            if raw_line.startswith("    ..."):
                continue
            if not raw_line.startswith(" "):
                if section == "keywords" and not _starts_with_bdd(stripped):
                    errors.append(f"{path}:{lineno}: keyword definition must start with BDD prefix")
                continue
            parts = [p for p in CELL_SPLIT_RE.split(stripped) if p]
            if not parts:
                continue
            if parts[0] in {"[Setup]", "[Teardown]"}:
                if len(parts) < 2 or not _starts_with_bdd(parts[1]):
                    errors.append(f"{path}:{lineno}: setup/teardown step must use BDD keyword")
                continue
            if parts[0].startswith("["):
                continue
            if not _starts_with_bdd(parts[0]):
                errors.append(f"{path}:{lineno}: step must start with BDD prefix")
    return errors


# ---------------------------------------------------------------------------
# Agent invocation
# ---------------------------------------------------------------------------

def _run_agent(prompt: str, output_path: Path, model: str = "sonnet",
               max_turns: int = 50) -> str:
    """Invoke Claude with the wise-rpa-bdd skill and return the result text."""
    from claude_agent_sdk import query, ClaudeAgentOptions, ResultMessage

    full_prompt = (
        f"{prompt}\n\n"
        f"Write the generated .robot suite to: {output_path}\n\n"
        "Follow the wise-rpa-bdd skill phases:\n"
        "1. /rrpa-orient — read references/workflow.md, keyword-contract.md, "
        "and the WiseRpaBDD keyword library to understand available keywords\n"
        "2. /rrpa-explore — use Playwright MCP or agent-browser to visit the "
        "target site. Inspect the live DOM, test CSS selectors, confirm pagination "
        "controls, map element structure. DO NOT SKIP. "
        "Every selector in the .robot file must come from live exploration. "
        "Output: confirmed selectors, DOM notes, sample data.\n"
        "3. /rrpa-draft — draft the .robot suite using WiseRpaBDD keywords "
        "grounded in explore evidence. Include quality gates.\n"
        "4. /rrpa-review — run robot --dryrun --pythonpath scripts/ "
        "to verify all keywords resolve. Fix issues and loop back to draft "
        "until dryrun passes clean.\n"
        "Do NOT run the suite against a live site for full scraping."
    )

    options = ClaudeAgentOptions(
        model=model,
        cwd=str(REPO_ROOT),
        permission_mode="bypassPermissions",
        max_turns=max_turns,
        allowed_tools=["Read", "Write", "Edit", "Glob", "Grep", "Bash"],
    )

    result_text = ""

    async def _run():
        nonlocal result_text
        async for msg in query(prompt=full_prompt, options=options):
            if isinstance(msg, ResultMessage):
                result_text = msg.result or ""

    asyncio.run(_run())
    return result_text


# ---------------------------------------------------------------------------
# RF keyword library
# ---------------------------------------------------------------------------

@library(scope="SUITE", auto_keywords=False)
class AgentRunner:
    """RF keyword library for testing the wise-rpa-bdd agent end-to-end."""

    ROBOT_LIBRARY_SCOPE = "SUITE"

    def __init__(self, model: str = "sonnet", max_turns: int = 50):
        self._model = model
        self._max_turns = max_turns
        self._generated_path: Path | None = None
        self._generated_content: str = ""

    def _require_generated(self) -> Path:
        if not self._generated_path:
            raise RuntimeError(
                "No generated suite — call 'Generate Suite From Requirement' first"
            )
        return self._generated_path

    @keyword("Generate Suite From Requirement")
    def generate_suite_from_requirement(self, requirement: str,
                                         output_path: str = "") -> str:
        """Invoke the AI agent with a requirement and capture the .robot output.

        The agent follows orient → explore → evidence → draft → validate.
        """
        if output_path:
            out = Path(output_path)
        else:
            fd = tempfile.NamedTemporaryFile(suffix=".robot", delete=False)
            fd.close()
            out = Path(fd.name)

        out.parent.mkdir(parents=True, exist_ok=True)

        logger.info(f"Invoking agent: {requirement[:80]}...")
        _run_agent(requirement, out, model=self._model, max_turns=self._max_turns)

        if out.exists() and out.stat().st_size > 0:
            self._generated_path = out
            self._generated_content = out.read_text()
            logger.info(f"Agent produced: {out} ({out.stat().st_size} bytes)")
        else:
            raise RuntimeError(f"Agent did not produce a .robot file at {out}")

        return str(out)

    @keyword("Generated Suite Should Pass BDD Validation")
    def generated_suite_should_pass_bdd_validation(self) -> None:
        """Validate every executable step uses Given/When/Then/And/But."""
        path = self._require_generated()
        errors = validate_bdd(path)
        if errors:
            raise AssertionError(
                "BDD validation failed:\n" + "\n".join(f"  {e}" for e in errors)
            )
        logger.info("BDD validation: PASS")

    @keyword("Generated Suite Should Pass Dryrun")
    def generated_suite_should_pass_dryrun(self) -> None:
        """Run robot --dryrun — proves all keywords resolve with WiseRpaBDD."""
        path = self._require_generated()
        result = subprocess.run(
            ["robot", "--dryrun",
             "--output", "NONE", "--log", "NONE", "--report", "NONE",
             "--pythonpath", str(SKILL_DIR / "scripts"),
             str(path)],
            capture_output=True, text=True,
        )
        if result.returncode != 0:
            raise AssertionError(
                f"Dryrun failed (rc={result.returncode}):\n"
                f"{result.stdout}\n{result.stderr}"
            )
        logger.info("Dryrun: PASS")

    @keyword("Generated Suite Should Match Golden Baseline")
    def generated_suite_should_match_golden_baseline(self, golden_path: str) -> None:
        """Compare generated suite structure against a vetted golden baseline."""
        golden = Path(golden_path)
        if not golden.exists():
            raise FileNotFoundError(f"Golden baseline not found: {golden}")

        golden_struct = _extract_structure(golden.read_text())
        gen_struct = _extract_structure(self._generated_content)

        diffs = []
        if set(golden_struct["libraries"]) != set(gen_struct["libraries"]):
            diffs.append(
                f"Libraries: golden={golden_struct['libraries']}, "
                f"generated={gen_struct['libraries']}"
            )

        missing_kw = golden_struct["keywords_used"] - gen_struct["keywords_used"]
        if missing_kw:
            diffs.append(f"Missing keywords from golden: {missing_kw}")

        if diffs:
            raise AssertionError(
                "Golden baseline mismatch:\n"
                + "\n".join(f"  - {d}" for d in diffs)
            )
        logger.info("Golden baseline: PASS")

    @keyword("Get Generated Suite Path")
    def get_generated_suite_path(self) -> str:
        if not self._generated_path:
            raise RuntimeError("No generated suite available")
        return str(self._generated_path)


def _extract_structure(text: str) -> dict[str, Any]:
    """Extract structural elements for comparison (not exact text)."""
    keywords_used = set(re.findall(
        r'(?:Given|When|Then|And|But)\s+(.+?)(?:\s{2,}|$)', text, re.MULTILINE
    ))
    libraries = re.findall(r'^Library\s+(\S+)', text, re.MULTILINE)
    return {"keywords_used": keywords_used, "libraries": libraries}


# ---------------------------------------------------------------------------
# Standalone CLI: python AgentRunner.py validate|dryrun path/to/suite.robot
# ---------------------------------------------------------------------------

def main() -> int:
    if len(sys.argv) < 3:
        print("Usage: python AgentRunner.py validate|dryrun <suite.robot>")
        return 1

    cmd, suite = sys.argv[1], Path(sys.argv[2])
    if not suite.exists():
        print(f"File not found: {suite}")
        return 1

    if cmd == "validate":
        errors = validate_bdd(suite)
        if errors:
            for e in errors:
                print(e)
            return 1
        print(f"BDD format OK: {suite}")
        return 0

    elif cmd == "dryrun":
        result = subprocess.run(
            ["robot", "--dryrun",
             "--output", "NONE", "--log", "NONE", "--report", "NONE",
             "--pythonpath", str(SKILL_DIR / "scripts"),
             str(suite)],
            text=True,
        )
        return result.returncode

    else:
        print(f"Unknown command: {cmd}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
