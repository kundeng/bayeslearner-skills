# AI Adapter Pattern

Use this reference when a scrape needs exploit-time AI for semantic extraction, normalization, classification, or enrichment that deterministic selectors cannot provide directly.

## Purpose

The AI adapter is an **optional extension path**. It sits around the normal WISE flow, not replacing exploration, DOM capture, or deterministic extraction.

Pattern:

1. Use `agent-browser` and normal extraction rules to capture source content
2. AI operates on **already-extracted text** (via the `input` field reference), never on the live DOM
3. Validate the returned structure before assembly

## When to Use

Use AI extraction when:

- the page contains unstructured prose that must be normalized into a schema
- extraction requires semantic grouping or fuzzy interpretation
- post-processing needs judgment that would be brittle with hand-written rules

Do NOT use AI when:

- ordinary CSS selectors can extract the needed fields directly
- simple deterministic cleanup can solve the problem
- the agent is reaching for AI just because it is available

## Abstract Interface

The `AIAdapter` interface (`references/runner/src/ai.ts`) defines three methods:

```typescript
interface AIAdapter {
  /** Structured extraction: text/HTML → JSON matching an optional schema. */
  extract(prompt: string, context: string, schema?: Record<string, unknown>): Record<string, unknown>;

  /** Classify text into one of the given categories. */
  classify(prompt: string, text: string, categories: string[]): string;

  /** Free-form text-to-text transform. */
  transform(prompt: string, input: string): string;
}
```

## Shipped Implementation: AIChatAdapter

The `AIChatAdapter` (`references/runner/src/aichat-adapter.ts`) wraps the `aichat` CLI — a single-binary tool that supports multiple LLM providers.

- **Install:** https://github.com/sigoden/aichat
- **No SDK dependency** — shells out via `execSync`, passes prompt via stdin
- **Model selection:** configure via `aichat` config or `--model` flag

## Profile Usage

### AI extraction (on captured HTML)

```yaml
nodes:
  - name: reviews
    parents: [root]
    extract:
      - html: { name: raw_html, css: ".reviews" }      # deterministic capture
      - ai:
          name: parsed_reviews
          prompt: "Extract reviewer name, rating, and text from these reviews."
          input: raw_html                                # AI operates on this field
          schema:
            type: array
            items:
              type: object
              properties:
                reviewer: { type: string }
                rating: { type: number }
                text: { type: string }
```

### AI classification

```yaml
extract:
  - text: { name: description, css: ".desc" }
  - ai:
      name: category
      prompt: "Classify this product."
      input: description
      categories: [electronics, clothing, home, food, other]
```

### AI enrichment via hooks

```yaml
hooks:
  post_extract:
    - name: ai_adapter.normalize
      config:
        prompt: "Normalize this address to JSON"
        schema: { street: string, city: string, state: string, zip: string }
```

## Null Adapter

When no AI backend is configured, the `NullAIAdapter` is used automatically. It returns placeholder values so profiles with AI extraction rules can still run (with degraded output) rather than crashing.

## Evaluation Questions

When reviewing an agent run, check:

- Did it prove deterministic extraction was insufficient before adding AI?
- Did it keep page capture on normal WISE plumbing?
- Did it isolate AI to the semantic step instead of handing the entire scrape to AI?
- Did it define the expected output shape clearly?
- Did it explain why AI was justified?
