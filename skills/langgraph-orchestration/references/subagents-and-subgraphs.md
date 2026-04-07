# Subagents And Subgraphs

Use this file when the task involves delegation boundaries.

## Choose Between Them

Use a **subagent** when the boundary is mostly about role, tools, and context.

Use a **subgraph** when the boundary is mostly about workflow shape and state.

That is the simplest reliable rule.

## Subagent Pattern

Good subagent boundaries:

- "research this and give me evidence"
- "review this diff"
- "summarize these logs"
- "edit these files with only filesystem tools"

Bad subagent boundaries:

- one node that does trivial string formatting
- a child that needs almost all the same tools and context as the parent
- deterministic routing that should have been a graph edge

## Subgraph Pattern

Good subgraph boundaries:

- reusable approval flow
- reusable extract-transform-validate workflow
- multi-node review process with internal routing
- a workflow module that must be testable in isolation

## Stateless vs Stateful Subgraphs

Use a stateless subgraph when:

- it behaves like a pure helper workflow
- it does not need interrupts
- it does not need its own durable state across calls

Use a stateful or checkpointed subgraph when:

- it may interrupt
- you need inspection or recovery
- the subgraph participates in a longer-lived thread

Be careful calling the same stateful subgraph multiple times from one parent
node. Namespace collisions and resumption behavior matter.

## Parent / Child Tool Isolation

Default to minimal tools.

```python
research_subagent = {
    "name": "researcher",
    "description": "Find evidence and summarize it.",
    "system_prompt": "You research. You do not modify files.",
    "tools": [internet_search, fetch_url],
}

editor_subagent = {
    "name": "editor",
    "description": "Modify local files carefully.",
    "system_prompt": "You edit files and explain the patch.",
    "tools": [read_file, edit_file, apply_patch_tool],
}
```

Do not give the researcher write tools just because the parent has them.

## Embedding A Graph Inside A Graph

You can invoke a compiled subgraph inside a parent node like a function, but
remember resumability semantics:

- if the subgraph interrupts, the parent node restarts from its beginning on
  resume
- code before the subgraph invocation may re-run
- side effects before invocation must therefore be idempotent or guarded

## Coordination Pattern

A good orchestrator does four things:

1. decides which worker should act
2. sends a narrow brief
3. receives a bounded output
4. synthesizes or routes onward

If the child is getting the entire conversation and all tools "just in case",
the delegation boundary is probably weak.

## Review Pattern

When designing the boundary, explicitly answer:

- what state enters?
- what tool slice is available?
- what output shape comes back?
- who owns approval for side effects?
- does the child need its own checkpointing behavior?
