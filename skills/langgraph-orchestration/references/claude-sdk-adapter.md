# Claude SDK Adapter

Use this when the orchestration layer is LangGraph or Deep Agents, but one of
the workers already exists as a Claude Agent SDK agent or should be implemented
that way.

## When This Pattern Is Worth It

Use it when:

- you already have a strong Claude SDK worker
- the parent graph should own routing, state, approvals, or resumability
- the child is a specialist with its own tools and prompt contract

Do not use it when a plain subagent spec would do the job.

## Core Shape

Wrap the Claude SDK agent in a LangChain-compatible runnable, then mount it as
`CompiledSubAgent`.

```python
from claude_agent_sdk import Agent
from deepagents import CompiledSubAgent
from langchain_core.messages import AIMessage


class ClaudeSDKRunnable:
    def __init__(self, agent: Agent):
        self.agent = agent

    async def ainvoke(self, input_dict: dict, config=None) -> dict:
        messages = input_dict.get("messages", [])
        prompt = messages[-1]["content"] if messages else ""

        result = await self.agent.run(prompt)

        return {
            "messages": messages + [AIMessage(content=result.text)]
        }


def make_claude_sdk_subagent(
    *,
    name: str,
    description: str,
    system_prompt: str,
    tools: list,
    model: str = "claude-opus-4-6",
) -> CompiledSubAgent:
    worker = Agent(
        model=model,
        system_prompt=system_prompt,
        tools=tools,
    )
    runnable = ClaudeSDKRunnable(worker)
    return CompiledSubAgent(
        name=name,
        description=description,
        runnable=runnable,
    )
```

## Deep-Agent Integration

```python
from deepagents import create_deep_agent

reviewer = make_claude_sdk_subagent(
    name="reviewer",
    description="Reviews changes and identifies regressions.",
    system_prompt="You are a careful review specialist.",
    tools=[lookup_policy, review_diff],
)

coordinator = create_deep_agent(
    model="claude-sonnet-4-6",
    subagents=[reviewer],
    tools=[internet_search],
    system_prompt="You coordinate execution and delegate review work.",
)
```

## State And Message Contract

Keep the bridge narrow:

- feed the child the minimal task brief
- return normal message output
- keep durable orchestration state in the parent graph

If the child needs durable state or internal routing, build it as a LangGraph
subgraph instead of hiding workflow inside the adapter.

## Observability Guidance

Instrument both layers if you need debugging:

- LangGraph / LangChain traces for orchestration
- Claude SDK traces for child reasoning and tool calls

That split is only worth the extra complexity if the child is materially more
than a prompt + tools bundle.
