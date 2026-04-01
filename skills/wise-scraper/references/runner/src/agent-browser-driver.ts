/**
 * AgentBrowserDriver — BrowserDriver implementation using agent-browser CLI.
 *
 * Uses `execSync` to call the agent-browser CLI for each operation.
 * This is the reference/fallback driver. For production, prefer the
 * library-based driver (PlaywrightDriver) that imports agent-browser's
 * internal Node.js API directly.
 *
 * All methods are synchronous — agent-browser handles async internally.
 */

import { execSync } from "child_process";
import { writeFileSync, unlinkSync } from "fs";
import { tmpdir } from "os";
import { join } from "path";
import type { BrowserDriver, DriverWait } from "./driver.js";
import { locatorToSelector, escapeJs } from "./driver.js";
import type { Locator } from "./schema.js";

export class AgentBrowserDriver implements BrowserDriver {
  timeoutMs: number;
  retries: number;

  constructor({ timeoutMs = 60000, retries = 2 } = {}) {
    this.timeoutMs = timeoutMs;
    this.retries = retries;
  }

  // ── low-level CLI ───────────────────────────────────

  private run(args: string[], timeoutS?: number): string | null {
    const timeout = (timeoutS ?? Math.ceil(this.timeoutMs / 1000) + 30) * 1000;
    const cmd = `agent-browser ${args.join(" ")}`;
    try {
      return execSync(cmd, {
        encoding: "utf-8",
        timeout,
        stdio: ["pipe", "pipe", "pipe"],
        windowsHide: true,
      }).trim();
    } catch (e: unknown) {
      const err = e as { message?: string; stderr?: string | Buffer };
      const msg = err.message ?? String(e);
      const stderr = err.stderr ? String(err.stderr).trim() : "";
      if (msg.includes("not found") || msg.includes("not recognized")) {
        throw new Error(
          "agent-browser not found. Install: npm i -g @anthropic-ai/agent-browser && agent-browser install",
        );
      }
      const short = cmd.length > 120 ? cmd.slice(0, 120) + "..." : cmd;
      const detail = stderr ? ` (${stderr.split("\n")[0]})` : "";
      console.error(`[driver] FAILED: ${short} — ${msg.split("\n")[0]}${detail}`);
      return null;
    }
  }

  private runRetry(args: string[], timeoutS?: number): string | null {
    for (let attempt = 0; attempt <= this.retries; attempt++) {
      const result = this.run(args, timeoutS);
      if (result !== null) return result;
      if (attempt < this.retries) {
        const wait = 2 * (attempt + 1);
        console.log(`  [retry ${attempt + 1}/${this.retries}] waiting ${wait}s...`);
        this.sleep(wait * 1000);
      }
    }
    return null;
  }

  private sleep(ms: number): void {
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);
  }

  // ── lifecycle ─────────────────────────────────────────

  open(url: string, opts?: { wait?: DriverWait }): boolean {
    const args = ["open", `"${url}"`];
    const w = opts?.wait;
    if (w && "idle" in w) args.push("--wait", "networkidle");
    else if (w && "selector" in w) args.push("--wait", `selector=${w.selector}`);
    args.push("--timeout", String(this.timeoutMs));
    return this.runRetry(args) !== null;
  }

  getUrl(): string | null {
    const raw = this.run(["get", "url"], 10);
    return raw ? raw.replace(/^"|"$/g, "") : null;
  }

  close(): void {
    this.run(["close"], 10);
  }

  // ── DOM evaluation ────────────────────────────────────

  eval(js: string): string | null {
    // Write JS to temp file, pass via command substitution to avoid shell escaping
    const tmpFile = join(tmpdir(), `wise-eval-${process.pid}.js`);
    try {
      writeFileSync(tmpFile, js, "utf-8");
      return this.runRetry(["eval", `"$(cat ${tmpFile})"`]);
    } finally {
      try { unlinkSync(tmpFile); } catch { /* ignore */ }
    }
  }

  evalJson<T = unknown>(js: string): T | null {
    const raw = this.eval(js);
    if (raw === null) return null;
    return this.parseOutput(raw) as T;
  }

  private parseOutput(raw: string): unknown {
    raw = raw.trim();
    if (!raw) return null;
    try {
      const first = JSON.parse(raw);
      if (typeof first === "string") {
        try { return JSON.parse(first); } catch { return first; }
      }
      return first;
    } catch {
      return raw;
    }
  }

  // ── interaction primitives ────────────────────────────

  click(target: Locator, opts?: { type?: "real" | "scripted" }): void {
    const sel = locatorToSelector(target);
    if (opts?.type === "scripted") {
      this.eval(`document.querySelector('${escapeJs(sel)}')?.click()`);
    } else {
      this.run(["click", `"${sel}"`]);
    }
  }

  select(target: Locator, value: string): void {
    const sel = locatorToSelector(target);
    this.run(["select", `"${sel}"`, `"${value}"`]);
  }

  scroll(direction: "down" | "up" = "down", px = 500): void {
    const sign = direction === "down" ? "" : "-";
    this.eval(`window.scrollBy(0, ${sign}${px})`);
  }

  wait(condition: DriverWait): void {
    if ("idle" in condition) {
      this.run(["wait", "--load", "networkidle"]);
    } else if ("selector" in condition) {
      this.run(["wait", "--selector", `"${condition.selector}"`]);
    } else if ("ms" in condition) {
      this.sleep(condition.ms);
    }
  }

  hover(target: Locator): void {
    const sel = locatorToSelector(target);
    this.run(["hover", `"${sel}"`]);
  }

  type(target: Locator, value: string): void {
    const sel = locatorToSelector(target);
    this.eval(`
      (() => {
        const el = document.querySelector('${escapeJs(sel)}');
        if (el) { el.value = ''; el.value = '${escapeJs(value)}'; el.dispatchEvent(new Event('input', {bubbles:true})); }
      })()
    `);
  }

  // ── state observation ─────────────────────────────────

  exists(css: string): boolean {
    return this.evalJson<boolean>(`
      (() => document.querySelector('${escapeJs(css)}') ? true : false)()
    `) ?? false;
  }

  textContent(css: string): string | null {
    return this.evalJson<string>(`
      (() => {
        const el = document.querySelector('${escapeJs(css)}');
        return el ? el.textContent.trim() : null;
      })()
    `);
  }

  snapshot(): string {
    return this.run(["snapshot", "--json"]) ?? "";
  }
}
