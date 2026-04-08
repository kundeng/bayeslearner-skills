# AI Adapter Pattern

Use this reference when a scraping task needs AI for semantic extraction, classification, or enrichment that deterministic selectors cannot provide.

## Purpose

AI extraction is an **optional extension path**. It wraps around normal BDD extraction, not replacing it.

Pattern:
1. Use normal `extract fields` with `html` or `text` extractors to capture source content
2. AI operates on **already-extracted text** via the `input` field reference
3. Validate the returned structure via quality gates

## When to Use

Use AI extraction when:
- the page contains unstructured prose that must be normalized into a schema
- extraction requires semantic grouping or fuzzy interpretation
- post-processing needs classification that would be brittle with rules

Do NOT use AI when:
- ordinary CSS selectors can extract the needed fields directly
- simple deterministic cleanup can solve the problem
- the agent is reaching for AI just because it is available

## BDD Keywords

### AI Extraction (on captured HTML)

```robot
Then I extract fields
...    field=raw_html    extractor=html    locator=".reviews-container"
Then I extract with AI "parsed_reviews"
...    prompt="Extract all user reviews with rating, reviewer name, and text."
...    input=raw_html
...    schema={"type":"array","items":{"type":"object","properties":{"reviewer":{"type":"string"},"rating":{"type":"number"},"text":{"type":"string"}}}}
```

### AI Classification

```robot
Then I extract fields
...    field=description    extractor=text    locator=".desc"
Then I extract with AI "category"
...    prompt="Classify this product into exactly one category."
...    input=description
...    categories=electronics|clothing|home|food|other
```

### AI Enrichment via Hooks

```robot
And I register hook "ai_normalize" at "post_extract"
...    prompt="Normalize this address to JSON"
...    schema={"street":"string","city":"string","state":"string","zip":"string"}
```

## Continuation Row Reference

| Key | Purpose | Required |
|-----|---------|----------|
| `prompt` | Instruction for the AI model | Yes |
| `input` | Field name containing source text | Yes (extract) |
| `schema` | JSON schema for structured output | No (extract) |
| `categories` | Pipe-delimited category list | No (classify) |

## Null Adapter Behavior

When no AI backend is configured, AI extraction keywords produce placeholder values. This allows suites to pass `robot --dryrun` and validation even without an AI backend.

## Evaluation Questions

When reviewing an agent's AI extraction choices:
- Did it prove deterministic extraction was insufficient before adding AI?
- Did it keep page capture on normal extraction plumbing?
- Did it isolate AI to the semantic step instead of handing the entire scrape to AI?
- Did it define the expected output shape clearly?
- Did it explain why AI was justified?
