---
name: arize
description: Instrument agentic LLM apps built on the Claude Agent SDK (claude-agent-sdk) and/or LangGraph with Arize Phoenix and OpenInference — tracing, evaluation, annotations, experiments, cost tracking, and self-hosting. Use when the user mentions Phoenix, arize-phoenix, openinference, LLM observability, LLM-as-judge evals, tracing Claude Agent SDK `query()` / `ClaudeSDKClient` calls, tool-use observability, tracing LangGraph nodes/edges, or debugging latency/cost/quality of an agent.
metadata:
  author: kundeng
  version: "1.0.0"
---

# Arize Phoenix for Claude Agent SDK & LangGraph

Phoenix is an open-source LLM observability platform from Arize, built on OpenTelemetry. **OpenInference** is the companion spec that defines LLM-specific span attributes (`llm.model_name`, `input.value`, `tool.name`, `retrieval.documents.*`, …) and ships auto-instrumentors. Any OTLP backend (Datadog, Tempo, Jaeger) also accepts the same spans.

Scope of this skill:
- **Claude Agent SDK** (`claude-agent-sdk` Python package — same SDK that powers Claude Code). **No auto-instrumentor exists**; use the manual wrapper below.
- **LangGraph** — traced via `openinference-instrumentation-langchain` (no separate LangGraph package needed).

## Packages (exact names)

```
pip install arize-phoenix                                    # Phoenix server + phoenix.otel / evals / client / experiments
pip install arize-phoenix-otel                               # phoenix.otel.register() helper
pip install openinference-instrumentation-claude-agent-sdk   # auto-instruments the Claude Agent SDK
pip install openinference-instrumentation-langchain          # covers LangChain AND LangGraph
pip install openinference-semantic-conventions               # attribute name constants
pip install opentelemetry-sdk opentelemetry-exporter-otlp
pip install claude-agent-sdk                                 # the Claude Agent SDK itself
```

Top-level package is `openinference` (no underscore). `open_inference` is wrong and ImportErrors.

## Gotchas (read first)

- **Use `ClaudeAgentSDKInstrumentor`, not `AnthropicInstrumentor`.** The Claude Agent SDK shells out to the `claude` CLI — it doesn't go through the `anthropic` Python client, so `AnthropicInstrumentor` captures nothing. Use `openinference-instrumentation-claude-agent-sdk`.
- **`auto_instrument=True` on `register()` enables everything installed.** If you've installed multiple `openinference-instrumentation-*` packages (e.g. Claude Agent SDK + LangChain), `register(auto_instrument=True)` turns them all on. Otherwise call each `.instrument()` explicitly.
- **Hide sensitive data at instrument time.** `ClaudeAgentSDKInstrumentor().instrument(hide_inputs=True, hide_outputs=True)` masks prompts and completions in spans. Cheaper and safer than redacting downstream.
- **`ClaudeSDKClient` sessions need `session.id`.** Multi-turn sessions share context; tag every span with the same `session.id` so Phoenix groups them in the Sessions view. Pick an id yourself — the SDK doesn't assign one. Pass it via OTel baggage or a wrapping span.
- **`openinference`, not `open_inference`.** Top-level package has no underscore.
- **LangGraph uses the LangChain instrumentor.** There is no `openinference-instrumentation-langgraph`. Installing `openinference-instrumentation-langchain` gives you node/edge/tool spans automatically.
- **Call `phoenix.otel.register()` once per process.** Multiple calls create competing tracer providers.
- **`BatchSpanProcessor` in production.** `register()` defaults to Batch; only change this if wiring OTel manually. `SimpleSpanProcessor` exports synchronously and adds latency to every LLM call.
- **Endpoints.** `http://localhost:6006/v1/traces` = OTLP/HTTP. `http://localhost:4317` = OTLP/gRPC. UI at `http://localhost:6006`. Prefer `PHOENIX_COLLECTOR_ENDPOINT` env var over hard-coded URLs.
- **Auth header.** Self-hosted Phoenix with auth expects `authorization: Bearer <api_key>`. Set `PHOENIX_API_KEY` and `register()` picks it up.
- **Annotation kinds are `HUMAN | LLM | CODE`** in the current SDK. Older docs say `USER/SYSTEM/EXTERNAL` — outdated.
- **Don't stuff entire file contents into attributes.** Tool results from `Read`/`Bash` can be huge. Truncate to a few KB and link to the full file out of band if you need it.
- **LangGraph streaming.** With `graph.stream(...)`, each chunk becomes an event on the same parent span. Don't wrap individual chunks in manual spans.
- **LangGraph `ToolNode` is auto-instrumented.** Don't also wrap the tool body in a manual `TOOL` span — you'll nest twice.
- **Sample at the root only.** Mid-trace sampling orphans child spans. Use `ParentBased(TraceIdRatioBased(...))`.
- **`launch_app()` is notebook-only.** Starts Phoenix in-process. For services, run the server via Docker and point SDK clients at its URL.
- **Eval judges cost money.** Running `HallucinationEvaluator(AnthropicModel("claude-sonnet-4-6"))` over 10k rows is $$. Use `run_evals(..., concurrency=20)` and cache with `provide_explanation=True`.

## One-liner setup

```python
import phoenix as px
from phoenix.otel import register

px.launch_app()                                           # dev only; skip on a server
tracer_provider = register(
    project_name="my-agent",
    auto_instrument=True,                                 # enables every installed openinference-instrumentation-*
)
```

`auto_instrument=True` picks up `openinference-instrumentation-claude-agent-sdk`, `...-langchain`, and anything else you've `pip install`-ed. For explicit control (or to pass `hide_inputs`/`hide_outputs`):

```python
from phoenix.otel import register
from openinference.instrumentation.claude_agent_sdk import ClaudeAgentSDKInstrumentor
from openinference.instrumentation.langchain import LangChainInstrumentor

tracer_provider = register(project_name="my-agent")
ClaudeAgentSDKInstrumentor().instrument(
    tracer_provider=tracer_provider,
    hide_inputs=False,                                    # True to mask prompts
    hide_outputs=False,                                   # True to mask completions
)
LangChainInstrumentor().instrument(tracer_provider=tracer_provider)   # covers LangGraph
```

For a running Phoenix server:

```python
import os
from phoenix.otel import register

tracer_provider = register(
    project_name="prod",
    endpoint="http://phoenix.mycorp.com:6006/v1/traces",
    headers={"authorization": f"Bearer {os.environ['PHOENIX_API_KEY']}"},
)
```

## Tracing Claude Agent SDK calls

With `ClaudeAgentSDKInstrumentor` active, every `query()` and `ClaudeSDKClient` call produces an AGENT root span and a TOOL child span per tool invocation (Bash, Read, Write, MCP calls, etc.) — no code changes:

```python
from claude_agent_sdk import query, ClaudeAgentOptions

options = ClaudeAgentOptions(
    system_prompt="You are a code reviewer.",
    allowed_tools=["Read", "Grep", "Bash"],
)

async for message in query(
    prompt="Review src/auth.py for bugs.",
    options=options,
):
    print(message)
# Phoenix shows: one AGENT span -> TOOL children (Read/Grep/Bash) with args + results.
```

To tag a run with session/user/version for grouping and filtering in Phoenix, wrap the call in an outer span whose attributes are inherited by the auto-generated children:

```python
from opentelemetry import trace
from openinference.semconv.trace import SpanAttributes, OpenInferenceSpanKindValues

tracer = trace.get_tracer(__name__)

async def run_review(task: str, *, session_id: str, user_id: str):
    with tracer.start_as_current_span("review") as root:
        root.set_attribute(SpanAttributes.OPENINFERENCE_SPAN_KIND,
                           OpenInferenceSpanKindValues.CHAIN.value)
        root.set_attribute(SpanAttributes.SESSION_ID, session_id)
        root.set_attribute(SpanAttributes.USER_ID, user_id)
        root.set_attribute(SpanAttributes.METADATA,
                           '{"prompt_version": "v3"}')
        async for msg in query(prompt=task, options=options):
            pass
```

For `ClaudeSDKClient` (multi-turn), reuse the same `session_id` across turns:

```python
from claude_agent_sdk import ClaudeSDKClient

async with ClaudeSDKClient(options=options) as client:
    for turn_prompt in user_turns:
        with tracer.start_as_current_span("turn") as root:
            root.set_attribute(SpanAttributes.SESSION_ID, "conv-123")
            await client.query(turn_prompt)
            async for _ in client.receive_response():
                pass
```

## LangGraph tracing

`LangChainInstrumentor` auto-captures every node, edge, and tool in a `StateGraph`:

```python
from langgraph.graph import StateGraph, START, END
from langchain_anthropic import ChatAnthropic
from typing_extensions import TypedDict

class State(TypedDict):
    input: str
    output: str

def think(state: State) -> State:
    llm = ChatAnthropic(model="claude-sonnet-4-6")
    return {"output": llm.invoke(state["input"]).content}

graph = StateGraph(State)
graph.add_node("think", think)
graph.add_edge(START, "think")
graph.add_edge("think", END)
app = graph.compile()

app.invoke({"input": "hi"})
# Phoenix shows: compile root -> "think" node -> ChatAnthropic LLM span.
```

Tag each run with session + metadata so Phoenix groups the conversation:

```python
config = {
    "configurable": {"thread_id": "conv-123"},
    "metadata": {"session.id": "conv-123", "user.id": "u42"},
    "tags": ["prompt_v2"],
}
app.invoke({"input": "another turn"}, config=config)
```

## Manual spans for custom steps

```python
from opentelemetry import trace
from openinference.semconv.trace import SpanAttributes, OpenInferenceSpanKindValues

tracer = trace.get_tracer(__name__)

with tracer.start_as_current_span("rag_retrieve") as span:
    span.set_attribute(SpanAttributes.OPENINFERENCE_SPAN_KIND,
                       OpenInferenceSpanKindValues.RETRIEVER.value)
    span.set_attribute(SpanAttributes.INPUT_VALUE, query)
    for i, doc in enumerate(docs):
        span.set_attribute(f"retrieval.documents.{i}.document.id",      doc.id)
        span.set_attribute(f"retrieval.documents.{i}.document.content", doc.text)
        span.set_attribute(f"retrieval.documents.{i}.document.score",   doc.score)
```

### OpenInference span kinds

```
CHAIN  LLM  RETRIEVER  EMBEDDING  TOOL  AGENT  RERANKER  GUARDRAIL  EVALUATOR
```

Set via `SpanAttributes.OPENINFERENCE_SPAN_KIND` → `OpenInferenceSpanKindValues.<KIND>.value`.

### Common SpanAttributes

```
INPUT_VALUE, OUTPUT_VALUE, INPUT_MIME_TYPE, OUTPUT_MIME_TYPE
LLM_MODEL_NAME, LLM_INVOCATION_PARAMETERS, LLM_PROVIDER, LLM_SYSTEM
LLM_TOKEN_COUNT_PROMPT / _COMPLETION / _TOTAL
LLM_INPUT_MESSAGES, LLM_OUTPUT_MESSAGES         # indexed message.role / message.content
TOOL_NAME, TOOL_DESCRIPTION, TOOL_PARAMETERS
RETRIEVAL_DOCUMENTS                             # indexed; see above
SESSION_ID, USER_ID, METADATA, TAG_TAGS
```

## Annotations (feedback + automated judges)

```python
from phoenix.client import Client
from opentelemetry.trace import format_span_id

client = Client()                                # reads PHOENIX_COLLECTOR_ENDPOINT / PHOENIX_API_KEY

# Grab a span id while the span is live (to hand to your frontend)
span_id = format_span_id(span.get_span_context().span_id)   # 16-hex string

client.annotations.add_span_annotation(
    span_id=span_id,
    annotation_name="user_feedback",
    annotator_kind="HUMAN",                      # HUMAN | LLM | CODE
    label="positive",
    score=1.0,
    explanation="perfect summary",
)
```

Automated judge as a CODE annotation:

```python
def fact_check(span_id: str, output: str):
    score = my_fact_checker(output)
    client.annotations.add_span_annotation(
        span_id=span_id,
        annotation_name="factual_accuracy",
        annotator_kind="CODE",
        score=score,
        label="verified" if score > 0.8 else "suspect",
    )
```

## Evaluators

```python
import phoenix as px
from phoenix.evals import (
    AnthropicModel,
    HallucinationEvaluator, QAEvaluator, RelevanceEvaluator,
    llm_classify, run_evals,
)
from phoenix.trace import SpanEvaluations

judge = AnthropicModel(model="claude-sonnet-4-6")

df = px.Client().get_spans_dataframe('span_kind == "LLM"', project_name="my-agent")
# df columns per evaluator:
#   HallucinationEvaluator: input, output, reference (retrieved context)
#   QAEvaluator:            input, output, reference (gold answer)
#   RelevanceEvaluator:     input, reference (per retrieved doc)

halluc_df, qa_df = run_evals(
    dataframe=df,
    evaluators=[HallucinationEvaluator(judge), QAEvaluator(judge)],
    provide_explanation=True,
    concurrency=20,
)

px.Client().log_evaluations(
    SpanEvaluations(eval_name="Hallucination",  dataframe=halluc_df),
    SpanEvaluations(eval_name="QA Correctness", dataframe=qa_df),
)
```

Custom LLM-as-judge for agent trajectories (did the agent pick good tools?):

```python
template = """
Evaluate whether the agent chose appropriate tools.
Task: {input}
Tools used: {tools_used}
Final output: {output}
Label must be exactly one of: good, acceptable, poor.
"""
rails = ["good", "acceptable", "poor"]

result_df = llm_classify(
    dataframe=df, template=template, rails=rails,
    model=judge, provide_explanation=True, concurrency=20,
)
```

## Experiments (A/B and regression tests)

```python
import pandas as pd
from phoenix.client import Client
from phoenix.experiments import run_experiment
from phoenix.evals import AnthropicModel

client = Client()

dataset = client.datasets.upload_dataset(
    dataset_name="review_tasks",
    dataframe=pd.DataFrame({
        "input":  ["Review src/auth.py", "Review src/db.py"],
        "output": ["...", "..."],                      # gold answers
    }),
    input_keys=["input"], output_keys=["output"],
)

def task(example):
    # any function that returns a string — here, an agent run
    return run_agent(example.input["input"])

def contains_bug_report(output, expected):
    return "bug" in output.lower()

experiment = run_experiment(
    dataset=dataset,
    task=task,
    evaluators=[contains_bug_report],
    experiment_name="reviewer_v2",
    experiment_metadata={"system_prompt_version": "v2"},
)
```

## Token counting & cost

`ClaudeAgentSDKInstrumentor` already records tokens and cost on the AGENT span from the `ResultMessage`. If you need them in application code as well (for budget enforcement, alerting, etc.):

```python
from claude_agent_sdk import ResultMessage

async for msg in query(prompt=p, options=opts):
    if isinstance(msg, ResultMessage):
        cost   = msg.total_cost_usd           # may be None if cost tracking disabled
        it     = msg.usage.get("input_tokens", 0)
        ot     = msg.usage.get("output_tokens", 0)
        dur_ms = msg.duration_ms
```

If `total_cost_usd` is None, compute it yourself:

```python
PRICING = {                                   # USD per 1K tokens; keep in config
    "claude-sonnet-4-6": {"input": 0.003, "output": 0.015},
    "claude-haiku-4-5":  {"input": 0.0008, "output": 0.004},
    "claude-opus-4-6":   {"input": 0.015, "output": 0.075},
}
def cost(model, it, ot):
    p = PRICING[model]
    return (it / 1000) * p["input"] + (ot / 1000) * p["output"]
```

Attach cost per span so Phoenix aggregates:

```python
span.set_attribute("llm.cost.total", c)
```

Budget guard:

```python
class CostBudget:
    def __init__(self, daily_limit): self.limit, self.spent = daily_limit, 0.0
    def check(self, c):
        if self.spent + c > self.limit:
            raise RuntimeError(f"daily ${self.limit} budget exceeded")
        self.spent += c
```

## Self-hosting Phoenix (minimal)

```yaml
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: phoenix
      POSTGRES_USER: phoenix
      POSTGRES_PASSWORD: change_me
    volumes: [pg:/var/lib/postgresql/data]
  phoenix:
    image: arizephoenix/phoenix:latest
    depends_on: [postgres]
    environment:
      PHOENIX_SQL_DATABASE_URL: postgresql://phoenix:change_me@postgres:5432/phoenix
      PHOENIX_PORT: "6006"
      PHOENIX_GRPC_PORT: "4317"
      PHOENIX_ENABLE_AUTH: "true"
      PHOENIX_SECRET: "<32+ byte base64>"
    ports: ["6006:6006", "4317:4317"]
volumes: {pg: {}}
```

Key env vars:

```
PHOENIX_SQL_DATABASE_URL       postgresql://...
PHOENIX_PORT                   6006                (OTLP/HTTP on /v1/traces)
PHOENIX_GRPC_PORT              4317                (OTLP/gRPC)
PHOENIX_ENABLE_AUTH            true
PHOENIX_SECRET                 <base64>            (required with auth)
PHOENIX_API_KEY                <key>               (client-side)
PHOENIX_COLLECTOR_ENDPOINT     http://phoenix:6006 (SDKs read this)
```

## Sampling

```python
from opentelemetry.sdk.trace.sampling import ParentBased, TraceIdRatioBased
from opentelemetry.sdk.trace import TracerProvider

tp = TracerProvider(sampler=ParentBased(root=TraceIdRatioBased(0.1)))   # 10% of roots
```

## Deciding what to reach for

- **"Trace my Claude Agent SDK app."** → `register(auto_instrument=True)` (or `ClaudeAgentSDKInstrumentor().instrument(...)` for privacy controls). Wrap calls in a CHAIN span to attach `session.id`/`user.id`.
- **"Trace my LangGraph app."** → `LangChainInstrumentor().instrument()`. Pass `config={"metadata": {"session.id": ...}}` on `invoke`.
- **"Custom step to trace."** → Manual span with `OpenInferenceSpanKindValues` + `SpanAttributes`.
- **"How good is the agent?"** → `phoenix.evals` with `AnthropicModel` judge + `run_evals` + `log_evaluations`.
- **"Did this change help?"** → `phoenix.experiments.run_experiment` against a dataset.
- **"Users hate my answers."** → `client.annotations.add_span_annotation(... annotator_kind="HUMAN" ...)` from thumbs up/down.
- **"Bill is scary."** → Pull `msg.total_cost_usd` from the `ResultMessage` and set `llm.cost.total` on the root span.

## Production checklist

- Every agent root span has `session.id`, `user.id`, `agent.num_turns`, `agent.duration_ms`, `llm.cost.total`, `agent.allowed_tools`, and `prompt.version`.
- Tool use spans have `tool.name`, `tool.parameters`, and `tool.use_id`; errors captured via `span.record_exception` + `StatusCode.ERROR`.
- Tool results and long content are truncated before going into attributes.
- User feedback logged as HUMAN annotations; judge results via `log_evaluations`.
- `BatchSpanProcessor` (default from `register()`); root-level `ParentBased` sampler in high-QPS prod.
- p99 latency + daily cost alerts vs. a 7-day baseline.
- Phoenix ≥3 replicas; Postgres backed up daily with tested restores; `PHOENIX_API_KEY` rotated.
