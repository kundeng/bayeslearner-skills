# Interrupts And HITL

Use this file when the flow must pause for approval, editing, or external input.

## Core Rule

`interrupt()` is the durable pause primitive.

To use it correctly you need:

- a checkpointer
- a `thread_id`
- a JSON-serializable payload
- a resume call using `Command(resume=...)`

## Minimal Approval Pattern

```python
from typing import TypedDict

from langgraph.checkpoint.memory import InMemorySaver
from langgraph.graph import START, END, StateGraph
from langgraph.types import Command, interrupt


class DeployState(TypedDict):
    plan: str
    approved: bool
    result: str


def draft_plan(state: DeployState):
    return {"plan": "deploy build 2026.04.07 to production"}


def approval_gate(state: DeployState):
    approved = interrupt(
        {
            "kind": "approval",
            "question": "Approve deployment?",
            "plan": state["plan"],
        }
    )
    return {"approved": bool(approved)}


def deploy(state: DeployState):
    if not state["approved"]:
        return {"result": "deployment cancelled"}
    return {"result": f"executed: {state['plan']}"}


builder = StateGraph(DeployState)
builder.add_node("draft_plan", draft_plan)
builder.add_node("approval_gate", approval_gate)
builder.add_node("deploy", deploy)
builder.add_edge(START, "draft_plan")
builder.add_edge("draft_plan", "approval_gate")
builder.add_edge("approval_gate", "deploy")
builder.add_edge("deploy", END)

graph = builder.compile(checkpointer=InMemorySaver())

config = {"configurable": {"thread_id": "deploy-1"}}

first = graph.invoke({}, config=config)
# returns interrupt payload via runtime

second = graph.invoke(Command(resume=True), config=config)
```

## Important Resume Semantics

When resumed, the node restarts from the beginning. Therefore:

- code before `interrupt()` will run again
- do not place non-idempotent side effects before `interrupt()`
- do not rely on local variables surviving the pause unless they are recomputed
  from state

## Tool-Level Interrupt Pattern

If the approval belongs to the tool itself, put the interrupt in the tool.

This is useful when:

- the same risky tool is reused in multiple agents
- approval should always happen no matter who calls the tool

Examples:

- sending email
- mutating records
- deploying infra

## Streaming Pattern

When streaming with interrupts, surface both progress and waiting state.

```python
for chunk in graph.stream(
    {},
    config={"configurable": {"thread_id": "deploy-2"}},
    stream_mode="values",
):
    print(chunk)
```

Watch for interrupt payloads in the streamed values so the caller knows the
graph is waiting.

## Production Guidance

- use a durable checkpointer, not in-memory state
- generate stable `thread_id` values from your application session or workflow id
- log approvals and resume payloads
- keep approval payloads small and structured

## Common Mistakes

- forgetting the checkpointer
- forgetting `thread_id`
- wrapping `interrupt()` in broad `try/except`
- performing side effects before the pause
- resuming a different thread than the one that was paused
