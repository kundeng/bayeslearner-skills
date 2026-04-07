# LangGraph Patterns

Use this when you are writing raw graph code.

## Core State Pattern

Start with typed state and explicit reducers.

```python
from typing import Annotated, Literal, TypedDict
import operator

from langgraph.graph import START, END, StateGraph


class ReviewState(TypedDict):
    task: str
    plan: list[str]
    findings: Annotated[list[str], operator.add]
    route: Literal["research", "implement", "done"]
    output: str
```

Why:

- `TypedDict` keeps node contracts legible
- reducers such as `operator.add` make parallel merges predictable
- explicit route fields make conditional edges easy to debug

## Minimal Router Graph

```python
def route_node(state: ReviewState):
    task = state["task"].lower()
    if "research" in task:
        return {"route": "research"}
    if "implement" in task:
        return {"route": "implement"}
    return {"route": "done"}


def choose_next(state: ReviewState):
    return state["route"]


def research_node(state: ReviewState):
    return {"findings": ["researched relevant constraints"]}


def implement_node(state: ReviewState):
    return {"output": "implemented change"}


builder = StateGraph(ReviewState)
builder.add_node("route", route_node)
builder.add_node("research", research_node)
builder.add_node("implement", implement_node)

builder.add_edge(START, "route")
builder.add_conditional_edges(
    "route",
    choose_next,
    {
        "research": "research",
        "implement": "implement",
        "done": END,
    },
)
builder.add_edge("research", END)
builder.add_edge("implement", END)

graph = builder.compile()
```

## `Command` Pattern

Use `Command` when a node should both update state and control where execution
goes next.

```python
from langgraph.types import Command


def route_with_command(state: ReviewState) -> Command[Literal["research", "implement", END]]:
    task = state["task"].lower()
    if "research" in task:
        return Command(update={"route": "research"}, goto="research")
    if "implement" in task:
        return Command(update={"route": "implement"}, goto="implement")
    return Command(goto=END)
```

Prefer `Command` when routing and state updates are tightly coupled.

## `Send` Pattern for Dynamic Workers

Use `Send` when the number of workers is not known until runtime.

```python
from typing import Annotated, TypedDict
import operator

from langgraph.constants import Send
from langgraph.graph import START, END, StateGraph


class Section(TypedDict):
    name: str
    description: str


class ReportState(TypedDict):
    topic: str
    sections: list[Section]
    completed_sections: Annotated[list[str], operator.add]
    report: str


def plan_sections(state: ReportState):
    return {
        "sections": [
            {"name": "Context", "description": "Why the topic matters"},
            {"name": "Risks", "description": "Main concerns"},
        ]
    }


def fan_out_workers(state: ReportState):
    return [
        Send("write_section", {"section": section, "topic": state["topic"]})
        for section in state["sections"]
    ]


def write_section(state):
    section = state["section"]
    return {"completed_sections": [f"{section['name']}: drafted"]}


def synthesize(state: ReportState):
    return {"report": "\n".join(state["completed_sections"])}


builder = StateGraph(ReportState)
builder.add_node("plan_sections", plan_sections)
builder.add_node("write_section", write_section)
builder.add_node("synthesize", synthesize)
builder.add_edge(START, "plan_sections")
builder.add_conditional_edges("plan_sections", fan_out_workers, ["write_section"])
builder.add_edge("write_section", "synthesize")
builder.add_edge("synthesize", END)
graph = builder.compile()
```

Use this for orchestrator / worker patterns rather than baking worker count into
the graph.

## Durable Execution Pattern

If the graph spans turns, external approvals, or failure recovery, compile with
a checkpointer and always pass `thread_id`.

```python
from langgraph.checkpoint.memory import InMemorySaver

checkpointer = InMemorySaver()
graph = builder.compile(checkpointer=checkpointer)

config = {"configurable": {"thread_id": "review-123"}}
result = graph.invoke({"task": "research and summarize"}, config=config)
```

Production guidance:

- use a durable saver instead of in-memory state
- treat `thread_id` as the durable cursor
- keep node side effects idempotent or guarded

## Streaming Pattern

Use stream mode early in development to inspect graph progress.

```python
for chunk in graph.stream(
    {"task": "research LangGraph checkpointing"},
    config={"configurable": {"thread_id": "t-1"}},
    stream_mode="values",
):
    print(chunk)
```

For interactive apps, pair message streaming with state or values streaming.

## State Design Rules

- Store durable facts in state, not transient locals
- Keep large raw documents out of state unless persistence really needs them
- Prefer small typed fields over a generic `metadata: dict`
- Use reducer annotations when parallel branches may write the same key
- Keep side-effect outputs separate from decision fields

## Common Mistakes

- routing only in prompt text, with no graph-level router
- no reducer on keys written by parallel branches
- checkpointing omitted even though interrupts are planned
- placing non-idempotent side effects before `interrupt()` or other resumable
  boundaries
- overloading one node with planning, execution, synthesis, and routing
