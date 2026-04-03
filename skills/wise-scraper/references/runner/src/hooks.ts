/**
 * Hook system for the WISE scraper runner.
 *
 * Hooks allow site-specific customization at well-defined points:
 *   post_discover  — after URL/page list is built
 *   pre_extract    — before opening a page or extracting a node
 *   post_extract   — after a page's raw data is captured
 *   pre_assemble   — after all pages extracted, before assembly
 *   post_assemble  — after final output is built
 */

import type { BrowserDriver } from "./driver.js";
import type { HookDef } from "./schema.js";

/** Hook config shape — matches both ResourceHooks and deployment-level hooks. */
type Hooks = Partial<Record<HookPoint, HookDef[]>>;

export interface HookContext {
  driver?: BrowserDriver;
  resource?: string;
  node?: string;
  url?: string;
  data?: Record<string, unknown>;
  record?: unknown;
  targets?: Array<{ url: string; consumedData: Record<string, unknown> | null }>;
  hookName?: string;
  hookConfig?: Record<string, unknown>;
  [key: string]: unknown;
}

export type HookFn<T = HookContext> = (ctx: T) => T | void;

export type HookPoint =
  | "post_discover"
  | "pre_extract"
  | "post_extract"
  | "pre_assemble"
  | "post_assemble";

const VALID_POINTS: HookPoint[] = [
  "post_discover",
  "pre_extract",
  "post_extract",
  "pre_assemble",
  "post_assemble",
];

interface HookEntry {
  fn: HookFn<any>;
  name: string;
}

export class HookRegistry {
  private globalHooks: Hooks;
  private pendingResourceHooks: Hooks;
  private activeResourceHooks: Hooks;
  private namedHooks: Record<HookPoint, Map<string, HookEntry>>;
  private missingHooks = new Set<string>();

  constructor() {
    this.globalHooks = this.emptyHooks();
    this.pendingResourceHooks = this.emptyHooks();
    this.activeResourceHooks = this.emptyHooks();
    this.namedHooks = this.emptyNamedHooks();
  }

  register<T = unknown>(point: HookPoint, fn: HookFn<T>, name?: string): void {
    if (!VALID_POINTS.includes(point)) {
      throw new Error(`Invalid hook point '${point}'. Valid: ${VALID_POINTS.join(", ")}`);
    }
    const entry: HookEntry = { fn, name: name ?? fn.name ?? "anonymous" };
    this.namedHooks[point].set(entry.name, entry);
  }

  /** Mark the start of a resource run and activate any pending resource hooks. */
  beginResource(_resourceName?: string): void {
    this.activeResourceHooks = this.pendingResourceHooks;
    this.pendingResourceHooks = this.emptyHooks();
  }

  /** Clear the active resource scope after a resource finishes. */
  endResource(): void {
    this.activeResourceHooks = this.emptyHooks();
  }

  invoke<T>(point: HookPoint, ctx: T): T {
    const globalDefs = this.globalHooks[point] ?? [];
    const resourceDefs = this.activeResourceHooks[point] ?? [];
    let next = this.runDefs(point, globalDefs, ctx);
    next = this.runDefs(point, resourceDefs, next);
    return next;
  }

  invokeDefs<T>(point: HookPoint, defs: HookDef[] | undefined, ctx: T): T {
    return this.runDefs(point, defs ?? [], ctx);
  }

  loadFromConfig(hooksConfig: Hooks, scope: "global" | "resource" = "global"): void {
    if (!hooksConfig) return;

    const target = scope === "resource" ? this.pendingResourceHooks : this.globalHooks;

    for (const [point, list] of Object.entries(hooksConfig) as [string, HookDef[] | undefined][]) {
      if (!VALID_POINTS.includes(point as HookPoint)) continue;
      const defs = list ?? [];
      if (defs.length === 0) continue;
      const hookPoint = point as HookPoint;
      target[hookPoint] = [...(target[hookPoint] ?? []), ...defs];
    }
  }

  async loadFromModule(modulePath: string): Promise<void> {
    try {
      const mod = await import(modulePath);
      if (typeof mod.registerHooks === "function") {
        mod.registerHooks(this);
      }
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e);
      console.error(`[hook] Failed to load module '${modulePath}': ${msg}`);
      throw e instanceof Error ? e : new Error(msg);
    }
  }

  private runDefs<T>(point: HookPoint, defs: HookDef[], ctx: T): T {
    let next = ctx;
    for (const def of defs) {
      const entry = this.namedHooks[point].get(def.name);
      if (!entry) {
        const key = `${point}:${def.name}`;
        if (!this.missingHooks.has(key)) {
          this.missingHooks.add(key);
          console.warn(`[hook] No implementation registered for '${def.name}' at ${point}`);
        }
        continue;
      }

      try {
        const result = entry.fn(this.makeHookContext(next, def));
        if (result !== undefined && result !== null) next = result as T;
      } catch (e: unknown) {
        const msg = e instanceof Error ? e.message : String(e);
        console.error(`[hook] '${entry.name}' at ${point} failed: ${msg}`);
      }
    }
    return next;
  }

  private makeHookContext<T>(ctx: T, hookDef: HookDef): T {
    if (ctx && typeof ctx === "object") {
      return {
        ...(ctx as Record<string, unknown>),
        hookName: hookDef.name,
        hookConfig: (hookDef.config ?? {}) as Record<string, unknown>,
      } as T;
    }
    return ctx;
  }

  private emptyHooks(): Hooks {
    const hooks: Hooks = {};
    for (const point of VALID_POINTS) hooks[point] = [];
    return hooks;
  }

  private emptyNamedHooks(): Record<HookPoint, Map<string, HookEntry>> {
    const hooks = {} as Record<HookPoint, Map<string, HookEntry>>;
    for (const point of VALID_POINTS) hooks[point] = new Map<string, HookEntry>();
    return hooks;
  }
}
