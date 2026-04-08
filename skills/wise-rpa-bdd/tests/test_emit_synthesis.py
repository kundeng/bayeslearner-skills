#!/usr/bin/env python3
"""Test generator synthesis: emit steps, AI extraction, and hook rendering."""

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


# ── Emit synthesis tests ──


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


# ── AI extraction tests ──


def test_ai_extract_basic():
    """AI extraction node generates 'Then I extract with AI' step."""
    profile = make_profile(has_explicit_emit=False)
    profile["resources"][0]["nodes"][1]["extract"] = [
        {"ai": {"name": "summary", "prompt": "Summarize the page"}}
    ]
    suite = generate_suite(profile, Path("/a/b/c/d/test.yaml"))
    assert 'Then I extract with AI "summary"' in suite
    assert 'prompt="Summarize the page"' in suite


def test_ai_extract_with_input():
    """AI extraction with input field renders the input continuation."""
    profile = make_profile(has_explicit_emit=False)
    profile["resources"][0]["nodes"][1]["extract"] = [
        {"ai": {"name": "classify", "prompt": "Classify this", "input": "body_text"}}
    ]
    suite = generate_suite(profile, Path("/a/b/c/d/test.yaml"))
    assert 'Then I extract with AI "classify"' in suite
    assert 'input="body_text"' in suite


def test_ai_extract_with_schema():
    """AI extraction with schema renders JSON schema continuation."""
    profile = make_profile(has_explicit_emit=False)
    profile["resources"][0]["nodes"][1]["extract"] = [
        {"ai": {"name": "structured", "schema": {"type": "object", "properties": {"x": {"type": "string"}}}}}
    ]
    suite = generate_suite(profile, Path("/a/b/c/d/test.yaml"))
    assert 'Then I extract with AI "structured"' in suite
    assert "schema=" in suite
    assert '"type": "object"' in suite


def test_ai_extract_with_categories():
    """AI extraction with categories renders pipe-separated list."""
    profile = make_profile(has_explicit_emit=False)
    profile["resources"][0]["nodes"][1]["extract"] = [
        {"ai": {"name": "tag", "categories": ["tech", "science", "art"]}}
    ]
    suite = generate_suite(profile, Path("/a/b/c/d/test.yaml"))
    assert 'Then I extract with AI "tag"' in suite
    assert "categories=tech|science|art" in suite


def test_ai_extract_mixed_with_css():
    """AI extraction mixed with CSS extraction in the same node."""
    profile = make_profile(has_explicit_emit=False)
    profile["resources"][0]["nodes"][1]["extract"] = [
        {"text": {"name": "title", "css": "h1"}},
        {"ai": {"name": "sentiment", "prompt": "Rate sentiment"}},
    ]
    suite = generate_suite(profile, Path("/a/b/c/d/test.yaml"))
    assert "field=title" in suite
    assert 'Then I extract with AI "sentiment"' in suite


# ── Hook rendering tests ──


def test_single_hook():
    """A single hook renders register step with lifecycle point."""
    profile = make_profile(has_explicit_emit=False)
    profile["resources"][0]["hooks"] = {
        "after_extract": [{"name": "dedup", "config": {"key": "title"}}]
    }
    suite = generate_suite(profile, Path("/a/b/c/d/test.yaml"))
    assert 'And I register hook "dedup" at "after_extract"' in suite
    assert "key=title" in suite


def test_multiple_hooks_same_lifecycle():
    """Multiple hooks at the same lifecycle point each get their own step."""
    profile = make_profile(has_explicit_emit=False)
    profile["resources"][0]["hooks"] = {
        "before_emit": [
            {"name": "transform", "config": {"format": "json"}},
            {"name": "validate", "config": {"strict": True}},
        ]
    }
    suite = generate_suite(profile, Path("/a/b/c/d/test.yaml"))
    assert 'And I register hook "transform" at "before_emit"' in suite
    assert 'And I register hook "validate" at "before_emit"' in suite
    assert "format=json" in suite
    assert "strict=true" in suite


def test_hook_default_name():
    """Hook without explicit name uses lifecycle point as name."""
    profile = make_profile(has_explicit_emit=False)
    profile["resources"][0]["hooks"] = {
        "on_complete": [{"config": {"notify": True}}]
    }
    suite = generate_suite(profile, Path("/a/b/c/d/test.yaml"))
    assert 'And I register hook "on_complete" at "on_complete"' in suite
    assert "notify=true" in suite


def test_hook_single_not_list():
    """Hook value as a single dict (not wrapped in list) still renders."""
    profile = make_profile(has_explicit_emit=False)
    profile["resources"][0]["hooks"] = {
        "after_navigate": {"name": "wait_ready", "config": {"timeout": 30}}
    }
    suite = generate_suite(profile, Path("/a/b/c/d/test.yaml"))
    assert 'And I register hook "wait_ready" at "after_navigate"' in suite
    assert "timeout=30" in suite


def test_hooks_across_lifecycle_points():
    """Hooks at different lifecycle points each render correctly."""
    profile = make_profile(has_explicit_emit=False)
    profile["resources"][0]["hooks"] = {
        "before_extract": [{"name": "scroll", "config": {"pixels": 500}}],
        "after_emit": [{"name": "log", "config": {"level": "debug"}}],
    }
    suite = generate_suite(profile, Path("/a/b/c/d/test.yaml"))
    assert 'And I register hook "scroll" at "before_extract"' in suite
    assert 'And I register hook "log" at "after_emit"' in suite
    assert "pixels=500" in suite
    assert "level=debug" in suite


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
