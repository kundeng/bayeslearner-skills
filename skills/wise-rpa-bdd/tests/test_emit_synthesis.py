#!/usr/bin/env python3
"""Test that the generator synthesizes emit steps when resource.produces is set but no node has emit."""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

from generate_from_wise_yaml import generate_suite  # noqa: E402


def make_profile(*, has_explicit_emit: bool) -> dict:
    """Build a minimal profile with produces on the resource."""
    node_with_extract: dict = {
        "name": "leaf",
        "parents": ["root"],
        "extract": [{"text": {"name": "title", "css": "h1"}}],
    }
    if has_explicit_emit:
        node_with_extract["emit"] = [{"to": "items"}]

    return {
        "name": "test-deployment",
        "artifacts": {
            "items": {
                "fields": {"title": {"type": "string", "required": True}},
                "output": True,
            },
        },
        "resources": [
            {
                "name": "test_resource",
                "produces": ["items"],
                "entry": {"url": "https://example.com", "root": "root"},
                "nodes": [
                    {"name": "root", "parents": []},
                    node_with_extract,
                ],
            },
        ],
    }


def test_explicit_emit_preserved():
    """When a node has explicit emit, the generator should use it."""
    profile = make_profile(has_explicit_emit=True)
    suite = generate_suite(profile, Path("/a/b/c/d/test.yaml"))
    assert 'And I emit to artifact "${ARTIFACT_ITEMS}"' in suite


def test_synthesized_emit_from_produces():
    """When resource.produces is set but no node has emit, generator must synthesize emit steps."""
    profile = make_profile(has_explicit_emit=False)
    suite = generate_suite(profile, Path("/a/b/c/d/test.yaml"))
    assert 'And I emit to artifact "${ARTIFACT_ITEMS}"' in suite, (
        "Generator must synthesize emit steps from resource.produces when no node has explicit emit"
    )


def test_multi_artifact_synthesized_emit():
    """When produces lists multiple artifacts, all should get emit steps."""
    profile = make_profile(has_explicit_emit=False)
    profile["artifacts"]["items_flat"] = {
        "fields": {"title": {"type": "string", "required": True}},
        "output": True,
    }
    profile["resources"][0]["produces"] = ["items", "items_flat"]

    suite = generate_suite(profile, Path("/a/b/c/d/test.yaml"))
    assert 'And I emit to artifact "${ARTIFACT_ITEMS}"' in suite
    assert 'And I emit to artifact "${ARTIFACT_ITEMS_FLAT}"' in suite


def test_no_emit_when_no_produces():
    """When resource has no produces, no emit steps should be synthesized."""
    profile = make_profile(has_explicit_emit=False)
    del profile["resources"][0]["produces"]
    suite = generate_suite(profile, Path("/a/b/c/d/test.yaml"))
    assert "I emit to artifact" not in suite


if __name__ == "__main__":
    passed = 0
    failed = 0
    for name, func in list(globals().items()):
        if name.startswith("test_") and callable(func):
            try:
                func()
                print(f"  PASS: {name}")
                passed += 1
            except AssertionError as e:
                print(f"  FAIL: {name}: {e}")
                failed += 1
    print(f"\n{passed} passed, {failed} failed")
    raise SystemExit(1 if failed else 0)
