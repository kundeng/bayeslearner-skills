/**
 * AIChatAdapter — AIAdapter implementation using the `aichat` CLI.
 *
 * `aichat` is a single-binary CLI that wraps multiple LLM providers.
 * This adapter shells out to it synchronously, keeping the dependency
 * footprint minimal (no SDK, no API keys in code).
 *
 * Install: https://github.com/sigoden/aichat
 */

import { execSync } from "child_process";
import type { AIAdapter } from "./ai.js";

export class AIChatAdapter implements AIAdapter {
  private model: string;
  private timeoutMs: number;

  constructor({ model = "", timeoutMs = 30000 } = {}) {
    this.model = model;
    this.timeoutMs = timeoutMs;
  }

  extract(
    prompt: string,
    context: string,
    schema?: Record<string, unknown>,
  ): Record<string, unknown> {
    const parts = [prompt, "", "Context:", context];
    if (schema) {
      parts.push("", `Respond as JSON matching this schema: ${JSON.stringify(schema)}`);
    } else {
      parts.push("", "Respond as valid JSON only, no markdown fences.");
    }
    const raw = this.call(parts.join("\n"));
    return this.parseJson(raw);
  }

  classify(prompt: string, text: string, categories: string[]): string {
    const fullPrompt = [
      prompt,
      "",
      "Text:",
      text,
      "",
      `Categories: ${categories.join(", ")}`,
      "",
      "Respond with exactly one category name, nothing else.",
    ].join("\n");
    const raw = this.call(fullPrompt).trim();
    // Best-effort match to a valid category
    const lower = raw.toLowerCase();
    return categories.find((c) => lower === c.toLowerCase()) ?? raw;
  }

  transform(prompt: string, input: string): string {
    const fullPrompt = [prompt, "", "Input:", input].join("\n");
    return this.call(fullPrompt).trim();
  }

  // ── internals ─────────────────────────────────────────

  private call(prompt: string): string {
    const args = ["aichat", "--no-stream"];
    if (this.model) args.push("-m", this.model);

    // Pass prompt via stdin to avoid shell escaping issues
    const input = Buffer.from(prompt, "utf-8");
    try {
      return execSync(args.join(" "), {
        input,
        encoding: "utf-8",
        timeout: this.timeoutMs,
        stdio: ["pipe", "pipe", "pipe"],
        windowsHide: true,
      }).trim();
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e);
      if (msg.includes("not found") || msg.includes("not recognized")) {
        throw new Error("aichat not found. Install: https://github.com/sigoden/aichat");
      }
      console.error(`[ai] aichat failed: ${msg.split("\n")[0]}`);
      return "";
    }
  }

  private parseJson(raw: string): Record<string, unknown> {
    // Strip markdown code fences if present
    let cleaned = raw.trim();
    if (cleaned.startsWith("```")) {
      cleaned = cleaned.replace(/^```\w*\n?/, "").replace(/\n?```$/, "");
    }
    try {
      return JSON.parse(cleaned);
    } catch {
      return { _raw: raw, _parse_error: "failed to parse AI response as JSON" };
    }
  }
}
