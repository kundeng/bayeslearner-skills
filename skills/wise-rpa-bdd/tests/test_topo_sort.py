"""Unit tests for topological sort and diamond DAG execution."""

from __future__ import annotations

import sys
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

# Add scripts dir to path so we can import WiseRpaBDD
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))

from WiseRpaBDD import (
    Action,
    DeploymentContext,
    ExecutionEngine,
    Expansion,
    FieldSpec,
    ResourceContext,
    RuleNode,
)


# ---------------------------------------------------------------------------
# _resolve_node_order tests
# ---------------------------------------------------------------------------

class TestResolveNodeOrder:
    def test_empty(self):
        assert ExecutionEngine._resolve_node_order([]) == []

    def test_single_node(self):
        n = RuleNode(name="A")
        assert ExecutionEngine._resolve_node_order([n]) == ["A"]

    def test_linear_chain(self):
        a = RuleNode(name="A")
        b = RuleNode(name="B", parents=["A"])
        c = RuleNode(name="C", parents=["B"])
        order = ExecutionEngine._resolve_node_order([a, b, c])
        assert order == ["A", "B", "C"]

    def test_diamond_dag(self):
        """A → B, A → C, B → D, C → D — D appears once, after both B and C."""
        a = RuleNode(name="A")
        b = RuleNode(name="B", parents=["A"])
        c = RuleNode(name="C", parents=["A"])
        d = RuleNode(name="D", parents=["B", "C"])
        order = ExecutionEngine._resolve_node_order([a, b, c, d])
        assert order[0] == "A"
        assert order[-1] == "D"
        assert order.index("B") < order.index("D")
        assert order.index("C") < order.index("D")
        assert len(order) == 4  # each node exactly once

    def test_two_independent_roots(self):
        a = RuleNode(name="A")
        b = RuleNode(name="B")
        order = ExecutionEngine._resolve_node_order([a, b])
        assert set(order) == {"A", "B"}

    def test_cycle_detected(self):
        a = RuleNode(name="A", parents=["B"])
        b = RuleNode(name="B", parents=["A"])
        with pytest.raises(ValueError, match="Cycle detected"):
            ExecutionEngine._resolve_node_order([a, b])

    def test_self_cycle_detected(self):
        a = RuleNode(name="A", parents=["A"])
        with pytest.raises(ValueError, match="Cycle detected"):
            ExecutionEngine._resolve_node_order([a])

    def test_complex_dag(self):
        """A → B, A → C, B → D, C → D, D → E — verify full ordering."""
        nodes = [
            RuleNode(name="A"),
            RuleNode(name="B", parents=["A"]),
            RuleNode(name="C", parents=["A"]),
            RuleNode(name="D", parents=["B", "C"]),
            RuleNode(name="E", parents=["D"]),
        ]
        order = ExecutionEngine._resolve_node_order(nodes)
        assert order[0] == "A"
        assert order[-1] == "E"
        for i, name in enumerate(order):
            node = next(n for n in nodes if n.name == name)
            for parent in node.parents:
                assert order.index(parent) < i, \
                    f"{name} should come after {parent}"

    def test_parent_outside_set_ignored(self):
        """Parents not in the node set are ignored (external dependencies)."""
        b = RuleNode(name="B", parents=["A"])  # A not in set
        order = ExecutionEngine._resolve_node_order([b])
        assert order == ["B"]


# ---------------------------------------------------------------------------
# _find_children tests
# ---------------------------------------------------------------------------

class TestFindChildren:
    def setup_method(self):
        self.engine = ExecutionEngine.__new__(ExecutionEngine)

    def test_no_children(self):
        rules = {"A": RuleNode(name="A")}
        assert self.engine._find_children("A", rules) == []

    def test_finds_and_sorts_children(self):
        rules = {
            "A": RuleNode(name="A"),
            "B": RuleNode(name="B", parents=["A"]),
            "C": RuleNode(name="C", parents=["A"]),
        }
        children = self.engine._find_children("A", rules)
        names = [c.name for c in children]
        assert set(names) == {"B", "C"}


# ---------------------------------------------------------------------------
# Diamond DAG execution — D runs once
# ---------------------------------------------------------------------------

class TestDiamondDAGExecution:
    """Integration test: diamond DAG A→B, A→C, B→D, C→D.

    Verify that D's extraction runs exactly once.
    """

    def _make_engine(self):
        engine = ExecutionEngine.__new__(ExecutionEngine)
        engine.ctx = DeploymentContext(name="test")
        return engine

    def _mock_browser_lib(self, engine):
        bl = MagicMock()
        bl.get_url.return_value = "http://test.example.com"
        engine._bl = MagicMock(return_value=bl)
        return bl

    def test_diamond_d_runs_once(self):
        """D must execute exactly once even though B and C both list it as child."""
        engine = self._make_engine()
        bl = self._mock_browser_lib(engine)

        # Track which nodes get their extraction called
        execution_log: list[str] = []
        original_extract = ExecutionEngine._extract_from_scope

        def tracking_extract(self_inner, rule, scope, url):
            execution_log.append(rule.name)
            return {"node": rule.name}

        # Build diamond DAG
        rules = {
            "A": RuleNode(name="A"),
            "B": RuleNode(name="B", parents=["A"]),
            "C": RuleNode(name="C", parents=["A"]),
            "D": RuleNode(name="D", parents=["B", "C"]),
        }
        res = ResourceContext(
            name="test_resource",
            entry_url="http://test.example.com",
            rules=rules,
            root_names=["A"],
        )

        # Build tree (populates children via topo sort)
        roots = engine._build_rule_tree(res)
        assert len(roots) == 1
        assert roots[0].name == "A"

        # Verify children are populated correctly
        a_children = [c.name for c in rules["A"].children]
        assert "B" in a_children
        assert "C" in a_children

        d_children_of_b = "D" in [c.name for c in rules["B"].children]
        d_children_of_c = "D" in [c.name for c in rules["C"].children]
        assert d_children_of_b or d_children_of_c  # D is child of at least one

        # Execute with tracking
        with patch.object(ExecutionEngine, "_extract_from_scope", tracking_extract), \
             patch.object(ExecutionEngine, "_check_state", return_value=True), \
             patch.object(ExecutionEngine, "_execute_actions"):
            executed: set[str] = set()
            engine._walk_rule(roots[0], res, None,
                              "http://test.example.com", executed=executed)

        # D must appear exactly once
        assert execution_log.count("D") == 1, \
            f"D should run once, ran {execution_log.count('D')} times: {execution_log}"

        # All nodes executed
        assert set(execution_log) == {"A", "B", "C", "D"}

    def test_linear_chain_still_works(self):
        """Verify linear chain A→B→C still executes correctly."""
        engine = self._make_engine()
        bl = self._mock_browser_lib(engine)

        execution_log: list[str] = []

        def tracking_extract(self_inner, rule, scope, url):
            execution_log.append(rule.name)
            return {"node": rule.name}

        rules = {
            "root": RuleNode(name="root"),
            "child": RuleNode(name="child", parents=["root"]),
            "grandchild": RuleNode(name="grandchild", parents=["child"]),
        }
        res = ResourceContext(
            name="test",
            entry_url="http://test.example.com",
            rules=rules,
            root_names=["root"],
        )

        roots = engine._build_rule_tree(res)

        with patch.object(ExecutionEngine, "_extract_from_scope", tracking_extract), \
             patch.object(ExecutionEngine, "_check_state", return_value=True), \
             patch.object(ExecutionEngine, "_execute_actions"):
            executed: set[str] = set()
            engine._walk_rule(roots[0], res, None,
                              "http://test.example.com", executed=executed)

        assert execution_log == ["root", "child", "grandchild"]

    def test_cycle_detected_at_build_time(self):
        """Cycles are caught during _build_rule_tree."""
        engine = self._make_engine()

        rules = {
            "A": RuleNode(name="A", parents=["B"]),
            "B": RuleNode(name="B", parents=["A"]),
        }
        res = ResourceContext(
            name="test",
            entry_url="http://test.example.com",
            rules=rules,
            root_names=["A"],
        )

        with pytest.raises(ValueError, match="Cycle detected"):
            engine._build_rule_tree(res)
