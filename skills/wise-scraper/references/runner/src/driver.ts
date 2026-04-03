/**
 * Abstract BrowserDriver interface.
 *
 * All browser interaction goes through this interface. The engine never
 * touches browser internals directly — it calls these synchronous methods.
 *
 * Synchronous by design: the underlying implementation (agent-browser,
 * Playwright, Puppeteer) handles async internally. The NER graph walk
 * is inherently sequential within a single resource.
 *
 * Parallelism lives at the resource level (separate driver instances).
 */

import type { Locator } from "./schema.js";

// ── wait conditions ─────────────────────────────────────

export type DriverWait =
  | { idle: true }
  | { selector: string }
  | { ms: number };

// ── the interface ───────────────────────────────────────

export interface BrowserDriver {
  // --- identity ---
  /** Session identifier. One driver instance = one browser session/tab. */
  readonly session: string;

  // --- lifecycle ---
  open(url: string, opts?: { wait?: DriverWait }): boolean;
  getUrl(): string | null;
  close(): void;

  // --- DOM evaluation (the core primitive) ---
  eval(js: string): string | null;
  evalJson<T = unknown>(js: string): T | null;

  // --- interaction primitives ---
  click(target: Locator, opts?: { type?: "real" | "scripted" }): void;
  select(target: Locator, value: string): void;
  scroll(direction: "down" | "up", px?: number): void;
  wait(condition: DriverWait): void;
  hover(target: Locator): void;
  type(target: Locator, value: string): void;

  // --- state observation ---
  exists(css: string): boolean;
  textContent(css: string): string | null;
  snapshot(): string;

  // --- settings ---
  timeoutMs: number;
  retries: number;
}

// ── helpers ─────────────────────────────────────────────

/** Convert a Locator to a selector string suitable for browser APIs. */
export function locatorToSelector(loc: Locator): string {
  if (loc.css) return loc.css;
  if (loc.text) return `text=${loc.text}`;
  if (loc.role) {
    let s = `role=${loc.role}`;
    if (loc.name) s += `[name=${loc.name}]`;
    return s;
  }
  throw new Error(`Cannot resolve locator: ${JSON.stringify(loc)}`);
}

/** Escape a string for safe embedding in single-quoted JS strings inside template literals. */
export function escapeJs(s: string): string {
  return s
    .replace(/\\/g, "\\\\")
    .replace(/`/g, "\\`")
    .replace(/\$\{/g, "\\${")
    .replace(/'/g, "\\'")
    .replace(/\r/g, "\\r")
    .replace(/\n/g, "\\n")
    .replace(/\u2028/g, "\\u2028")
    .replace(/\u2029/g, "\\u2029");
}

/** Escape a string for safe embedding in shell commands (wraps in single quotes). */
export function shellEscape(s: string): string {
  // Replace each embedded single quote with: end quote, escaped quote, start quote
  return "'" + s.replace(/'/g, "'\\''") + "'";
}
