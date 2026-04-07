# MCP Bridging

Use this file when the task is "get MCP tools into a LangGraph / LangChain /
Deep Agents workflow".

## Rule

Use `langchain_mcp_adapters` instead of custom MCP transport glue.

The adapter library already handles converting MCP tool definitions into
LangChain-compatible tools and supports multiple MCP servers.

## Minimal Async Pattern

```python
import asyncio

from langchain.agents import create_agent
from langchain_mcp_adapters.client import MultiServerMCPClient


async def main():
    client = MultiServerMCPClient(
        {
            "filesystem": {
                "transport": "stdio",
                "command": "npx",
                "args": ["-y", "@modelcontextprotocol/server-filesystem", "/workspace"],
            },
            "docs": {
                "transport": "streamable_http",
                "url": "https://example.com/mcp",
            },
        }
    )

    tools = await client.get_tools()

    agent = create_agent(
        model="openai:gpt-5.2",
        tools=tools,
        system_prompt="You use MCP tools carefully and explain failures clearly.",
    )

    result = await agent.ainvoke(
        {"messages": [{"role": "user", "content": "List project files and summarize docs"}]}
    )
    print(result)


asyncio.run(main())
```

Use async end-to-end if you can.

## Session Pattern

When the adapter API exposes sessions rather than a flat `get_tools()` call,
load tools from the session and then hand them to your graph or agent.

```python
from langchain_mcp_adapters.tools import load_mcp_tools


async with client.session("filesystem") as session:
    filesystem_tools = await load_mcp_tools(session)
```

## Deep-Agent Pattern

```python
from deepagents import create_deep_agent


async def build_agent():
    client = MultiServerMCPClient(
        {
            "jira": {"transport": "streamable_http", "url": "https://jira.example/mcp"},
            "github": {"transport": "streamable_http", "url": "https://github.example/mcp"},
        }
    )
    tools = await client.get_tools()
    return create_deep_agent(
        model="claude-sonnet-4-6",
        tools=tools,
        system_prompt="You coordinate engineering work across issue trackers and repos.",
    )
```

## Tool-Slicing Pattern

Do not expose every MCP tool to every subagent.

```python
all_tools = await client.get_tools()

issue_tools = [tool for tool in all_tools if tool.name.startswith("jira_")]
repo_tools = [tool for tool in all_tools if tool.name.startswith("github_")]
```

Then assign slices to specialist subagents.

## Transport Guidance

- use `stdio` for local servers or local helpers
- use SSE / streamable HTTP when the server is remote
- keep transport configuration in code or config, not buried in prompt text

## Common Mistakes

- manually re-wrapping MCP JSON schemas into custom LangChain tools
- mixing sync and async carelessly
- calling `asyncio.run()` from environments that already have an event loop
- exposing high-risk side-effect tools with no approval boundary
- placing business logic inside the MCP server that belongs in the orchestrator

## Approval Pattern For Risky MCP Tools

Wrap risky side effects behind interrupts or approval nodes in the graph, or use
HITL around the tool invocation path.

Example categories:

- delete / write / deploy
- outbound email or messaging
- ticket transitions
- database mutation
