---
name: langgraph-orchestration
description: Use this skill for LangGraph, Deep Agents, LangChain agents built on LangGraph, MCP-to-LangGraph tool bridging, stateful workflows, subgraphs, subagents, interrupts, checkpointing, streaming, and multi-agent orchestration. Trigger when code imports langgraph, deepagents, langchain_mcp_adapters, langchain.agents, or when the user asks for agent graphs, orchestration, durable execution, HITL, or LangGraph architecture and patterns.
metadata:
  author: kundeng
  version: "1.0.0"
---

# LangGraph Orchestration

Use this skill when the task is about building or fixing an orchestrated agent
system on the LangGraph stack.

This skill is written for the agent, not as user-facing docs. Favor shipped
patterns and official APIs over improvised orchestration.

## First Move

Classify the request before touching code:

1. **High-level agent harness**: prefer `deepagents.create_deep_agent(...)`
2. **General-purpose tool-calling agent**: prefer `langchain.agents.create_agent(...)`
3. **Custom workflow / graph topology**: prefer `langgraph.graph.StateGraph`
4. **MCP tool integration**: prefer `langchain_mcp_adapters`
5. **Human approval / resumability**: prefer `interrupt()` + checkpointer
6. **Specialist delegation**: prefer deep-agent subagents, or explicit subgraphs

If more than one applies, choose the highest abstraction that still preserves
the required control. Do not drop to raw `StateGraph` just because it is more
familiar.

## Read Only What You Need

- `references/decision-guide.md` for framework choice and migration choices
- `references/langgraph-patterns.md` for `StateGraph`, `Command`, `Send`,
  reducers, routing, and durable execution
- `references/deep-agents.md` for `create_deep_agent`, middleware, skills,
  filesystem, memory, and subagents
- `references/mcp-bridging.md` for `langchain_mcp_adapters` patterns
- `references/subagents-and-subgraphs.md` for delegation boundaries and
  isolation rules
- `references/interrupts-hitl.md` for approval gates, resumability, and thread
  handling
- `references/claude-sdk-adapter.md` when embedding Claude Agent SDK workers
  into a LangGraph / Deep Agents orchestrator

## Defaults That Age Well

- Prefer `langchain.agents.create_agent(...)` over deprecated LangGraph
  prebuilt agent helpers.
- Prefer `deepagents` when you want planning, file tools, subagents, skills, or
  long-running coding/research behavior.
- Prefer `StateGraph` when topology matters: parallel branches, orchestrator /
  worker, cycles, reducer-controlled state, explicit routing.
- Prefer `CompiledSubAgent` only when you already have a compiled runnable /
  graph that should be embedded.
- Prefer `langchain_mcp_adapters.client.MultiServerMCPClient` instead of custom
  MCP transport code.
- Prefer a durable checkpointer in production. Memory checkpointers are for
  local dev.
- Prefer typed state (`TypedDict` or Pydantic) and reducer annotations over
  ad hoc dict mutation.
- Prefer `thread_id` as the stable resume cursor whenever checkpointing is in
  play.

## Decision Table

| Need | Default |
|---|---|
| Fastest path to a capable agent with tools | `create_agent(...)` |
| Coding / research agent with planning, skills, files, delegation | `create_deep_agent(...)` |
| Deterministic workflow or custom branching | `StateGraph(...)` |
| Fan-out workers created at runtime | `Send(...)` |
| Pause for approval or data from outside the graph | `interrupt()` + `Command(resume=...)` |
| Expose MCP servers as tools | `MultiServerMCPClient` + `load_mcp_tools(...)` |
| Reuse a graph inside another orchestrator | subgraph or `CompiledSubAgent` |

## Working Rules

- Do not hand-roll agent loops when `create_agent` or `create_deep_agent`
  already covers the shape.
- Do not put LLM reasoning into MCP servers. MCP servers should expose tools,
  data, or side effects.
- Do not treat checkpointing as optional if you need interrupts, resumability,
  or durable execution.
- Do not call `asyncio.run()` inside an already-running loop when loading MCP
  tools.
- Do not share the full toolset with every subagent by default. Narrow tool
  scopes.
- Do not let parent and child agents silently share mutable state. Pass narrow
  typed context instead.
- Do not bury control flow in prompt text when the graph should express it in
  code.

## What Good Looks Like

Good LangGraph-stack code usually has:

- one clear abstraction level
- explicit state schema
- explicit routing edges or delegation boundaries
- resumability model chosen up front
- streaming or logging path for observability
- tool isolation for specialist workers
- approval gates around risky side effects

## Output Style

When implementing:

1. State which abstraction you picked and why
2. Use the smallest viable graph / agent shape
3. Add typed state or typed runtime context
4. Add checkpointing if the flow can pause, fail, or span turns
5. Keep prompts specific to the node or subagent role
6. Verify the invoked APIs match current LangGraph / LangChain patterns
