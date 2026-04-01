/**
 * Abstract AIAdapter interface for exploitation-phase NLP.
 *
 * Used for hard cases where deterministic extraction isn't enough:
 * entity recognition, classification, normalization of messy text.
 *
 * Key constraint: the AI adapter only operates on already-extracted text,
 * never on the live DOM. It is a post-extraction transform, keeping the
 * explore/exploit boundary clean.
 */

export interface AIAdapter {
  /** Structured extraction: text/HTML → JSON matching an optional schema. */
  extract(
    prompt: string,
    context: string,
    schema?: Record<string, unknown>,
  ): Record<string, unknown>;

  /** Classify text into one of the given categories. */
  classify(
    prompt: string,
    text: string,
    categories: string[],
  ): string;

  /** Free-form text-to-text transform. */
  transform(prompt: string, input: string): string;
}

/**
 * Null adapter — returns placeholders. Used when no AI is configured
 * but the profile contains ai extraction rules.
 */
export class NullAIAdapter implements AIAdapter {
  extract(_prompt: string, _context: string): Record<string, unknown> {
    return { _ai_error: "no AI adapter configured" };
  }

  classify(_prompt: string, _text: string, categories: string[]): string {
    return categories[0] ?? "unknown";
  }

  transform(_prompt: string, input: string): string {
    return input;
  }
}
