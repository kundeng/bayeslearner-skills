# Decision Guide

Use this file first when the main question is "which layer should I build on?"

## Mental Model

The current stack is layered:

1. **LangGraph** is the runtime and graph primitive layer
2. **LangChain agents** are higher-level agents built on LangGraph
3. **Deep Agents** are an opinionated harness for long-running agents with
   planning, files, delegation, skills, and memory

Choose the highest layer that still gives the control you need.

## Choose `create_agent(...)` When

Use `langchain.agents.create_agent(...)` when you need:

- a tool-calling agent
- normal conversational turns
- a small custom toolset
- streaming and LangGraph runtime behavior without custom graph topology

Use this especially when the task says "build an agent" but not "build a
workflow graph".

## Choose `create_deep_agent(...)` When

Use `deepagents.create_deep_agent(...)` when you need:

- decomposition / planning
- filesystem-backed context handling
- specialist subagents
- skill loading
- long-running coding or research tasks
- memory beyond a simple turn loop

This is usually the right answer for "build me a coding / research assistant"
unless the user explicitly needs custom graph topology.

## Choose `StateGraph(...)` When

Use `langgraph.graph.StateGraph(...)` when you need:

- conditional routing
- explicit orchestrator / worker topologies
- parallel branches with reducer-managed state
- custom approval boundaries
- graph-level control over retries, pausing, and state shape
- deterministic workflow sections mixed with agent nodes

If your design doc contains words like "fan out", "merge", "cycle", "gate",
"router", or "approval node", this is usually the right layer.

## Choose Subgraphs When

Use a subgraph when a workflow fragment is:

- reusable
- stateful in its own right
- easier to test as its own unit
- not just "another prompt"

Examples:

- a document review graph used in several products
- a data-enrichment sequence with its own retries and routing
- a reusable approval flow

## Choose Deep-Agent Subagents When

Use subagents when the child is mainly:

- a specialist role
- a different tool slice
- an isolated context worker
- a delegation target for open-ended work

Examples:

- researcher
- data analyst
- code migrator
- documentation writer

## Layer Selection Cheatsheet

```python
# Small tool-calling assistant
from langchain.agents import create_agent

agent = create_agent(
    model="anthropic:claude-sonnet-4-6",
    tools=[search_docs, lookup_ticket],
    system_prompt="You answer support questions using internal tools.",
)
```

```python
# Long-running coding/research harness
from deepagents import create_deep_agent

agent = create_deep_agent(
    model="claude-sonnet-4-6",
    tools=[internet_search],
    system_prompt="You are a careful engineering agent.",
    subagents=[research_subagent, editor_subagent],
)
```

```python
# Explicit workflow graph
from typing import TypedDict
from langgraph.graph import START, END, StateGraph


class State(TypedDict):
    query: str
    route: str
    answer: str


builder = StateGraph(State)
builder.add_node("route", route_node)
builder.add_node("research", research_node)
builder.add_node("answer", answer_node)
builder.add_edge(START, "route")
builder.add_conditional_edges("route", route_fn, {"research": "research", "answer": "answer"})
builder.add_edge("research", "answer")
builder.add_edge("answer", END)
graph = builder.compile()
```

## Migration Notes

- If you see old guidance pointing to LangGraph `create_react_agent`, treat it
  as stale. Current LangChain guidance is to use `langchain.agents.create_agent`
  for high-level agent loops.
- If you are about to build a "deep" coding agent by stacking prompts on top of
  `create_agent`, stop and check whether `deepagents` is the intended tool.
