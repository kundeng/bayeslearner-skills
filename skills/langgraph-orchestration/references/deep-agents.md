# Deep Agents

Use this when the task is better served by `deepagents` than by a custom graph.

## When Deep Agents Are The Right Tool

Prefer `create_deep_agent(...)` when you want:

- a capable long-running assistant
- built-in planning
- file tools
- subagent delegation
- skills
- durable execution and streaming via the LangGraph runtime

Do not rebuild these features by hand unless the project has a concrete reason
to own the orchestration details.

## Minimal Pattern

```python
from deepagents import create_deep_agent


def internet_search(query: str) -> str:
    """Search the web."""
    ...


agent = create_deep_agent(
    model="claude-sonnet-4-6",
    tools=[internet_search],
    system_prompt="You are a careful research assistant.",
)
```

## Model Initialization Pattern

Use string model identifiers for the default path. Use explicit model objects
only when you need provider-specific parameters.

```python
from langchain.chat_models import init_chat_model
from deepagents import create_deep_agent

model = init_chat_model(
    "openai:gpt-5.2",
    temperature=0,
    max_retries=6,
)

agent = create_deep_agent(
    model=model,
    tools=[internet_search],
    system_prompt="You write precise answers and show your work.",
)
```

## Useful Parameters

These are the knobs worth remembering:

```python
from deepagents import create_deep_agent

agent = create_deep_agent(
    model="claude-sonnet-4-6",
    tools=[internet_search],
    system_prompt="You are a careful engineering agent.",
    subagents=[research_subagent],
    middleware=[custom_middleware],
    interrupt_on={"edit_file": True},
    checkpointer=checkpointer,
    store=store,
    skills=["/path/to/skills"],
    memory=["/path/to/MEMORY.md"],
    name="engineering-agent",
)
```

Practical notes:

- `tools` are merged into the built-in capability surface
- `interrupt_on` needs a checkpointer to be useful
- `skills` and `memory` are additive context sources, not replacements for good
  prompts
- the returned object is a compiled LangGraph runnable, so use `.invoke()`,
  `.ainvoke()`, `.stream()`, and `.astream()`

## Specialist Subagent Pattern

Use declarative subagent specs first.

```python
research_subagent = {
    "name": "researcher",
    "description": "Finds sources, compares claims, and summarizes evidence.",
    "system_prompt": (
        "You are a focused research subagent. Search, compare, and summarize. "
        "Do not edit files."
    ),
    "tools": [internet_search, fetch_url],
}

editor_subagent = {
    "name": "editor",
    "description": "Edits local files and applies patches carefully.",
    "system_prompt": (
        "You are a code-editing subagent. Prefer small safe edits and preserve "
        "existing behavior unless told otherwise."
    ),
    "tools": [read_file, apply_patch_tool],
}

agent = create_deep_agent(
    model="claude-sonnet-4-6",
    tools=[internet_search, fetch_url],
    subagents=[research_subagent, editor_subagent],
    system_prompt="You are the coordinator.",
)
```

Guidance:

- give each subagent a narrow role
- give each subagent a narrow tool slice
- do not assume custom subagents inherit parent skills
- override the `general-purpose` subagent only when you have a concrete reason

## Wrapping A Custom Graph As A Subagent

Use `CompiledSubAgent` when the child already exists as a runnable or graph.

```python
from deepagents import CompiledSubAgent, create_deep_agent
from langchain.agents import create_agent

review_graph = create_agent(
    model="anthropic:claude-sonnet-4-6",
    tools=[lookup_policy, review_diff],
    system_prompt="You review code for regressions and policy violations.",
)

reviewer = CompiledSubAgent(
    name="reviewer",
    description="Reviews diffs for correctness and risk.",
    runnable=review_graph,
)

agent = create_deep_agent(
    model="claude-sonnet-4-6",
    tools=[internet_search],
    subagents=[reviewer],
    system_prompt="You coordinate implementation and review.",
)
```

## Context Pattern With `ToolRuntime`

Use typed runtime context for user/session/account scoping.

```python
from dataclasses import dataclass

from langchain.tools import tool, ToolRuntime


@dataclass
class RequestContext:
    user_id: str
    account_id: str
    researcher_max_results: int = 5


@tool
def search_docs(query: str, runtime: ToolRuntime[RequestContext]) -> str:
    """Search docs for the current account."""
    account_id = runtime.context.account_id
    agent_name = runtime.config.get("metadata", {}).get("lc_agent_name", "unknown")
    limit = runtime.context.researcher_max_results if agent_name == "researcher" else 3
    return f"searching account={account_id} limit={limit} query={query}"
```

Use this instead of ambient globals.

## Middleware Awareness

Deep Agents ship with an opinionated middleware stack. Design with that in
mind, especially when skills, files, memory, or HITL are involved.

Practical consequences:

- planning is already present
- file tools already exist when filesystem middleware is enabled
- subagents already have a delegation path
- prompt-caching and memory behavior may be inserted around your custom logic

Do not duplicate built-in capabilities in your own tool list unless you mean to
replace them.

## Built-In Capability Surface

Expect Deep Agents to already provide the basics for coding / research style
work, depending on backend and middleware configuration:

- todo and planning support
- filesystem read / write / edit tools
- file discovery tools such as `ls`, `glob`, and `grep`
- delegation via the `task` tool when subagents are configured

Because of that, only add tools that introduce genuinely new external reach or
domain actions.

## Good Use Cases

- coding assistants
- research agents
- analysts that read and transform local files
- long-running multi-step task solvers

## Bad Use Cases

- tiny two-node deterministic workflows
- flows whose core value is explicit routing logic
- cases where you need hard graph topology guarantees and node-by-node control
