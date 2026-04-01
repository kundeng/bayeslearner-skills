/**
 * NER Graph Engine — walks the node graph and executes deterministic scraping.
 *
 * Core loop for every node:
 *   1. Check state (preconditions)
 *   2. Execute actions (browser interactions)
 *   3. Observe (extract data)
 *   4. Expand — generate successor states (elements | pages | combinations)
 *   5. For each successor: walk children
 *
 * Expansion unifies what the old engine handled as three separate code paths
 * (multiple, pagination, matrix) into a single mechanism.
 */

import type { BrowserDriver, DriverWait } from "./driver.js";
import { locatorToSelector, escapeJs } from "./driver.js";
import type { AIAdapter } from "./ai.js";
import { HookRegistry } from "./hooks.js";
import { InterruptHandler } from "./interrupts.js";
import { ArtifactStore } from "./store.js";
import type {
  Resource,
  NER,
  State,
  Action,
  Extraction,
  Expand,
  Locator,
  ExtractedRecord,
  SetupAction,
  StopCondition,
} from "./schema.js";

export class Engine {
  private driver: BrowserDriver;
  private ai: AIAdapter;
  private hooks: HookRegistry;
  private interrupts: InterruptHandler;
  private store: ArtifactStore | null;
  private visited = new Set<string>();   // URL dedup

  constructor(driver: BrowserDriver, ai: AIAdapter, hooks: HookRegistry, store?: ArtifactStore) {
    this.driver = driver;
    this.ai = ai;
    this.hooks = hooks;
    this.interrupts = new InterruptHandler(driver);
    this.store = store ?? null;
  }

  // ── public API ────────────────────────────────────────

  runResource(resource: Resource): ExtractedRecord[] {
    const nodeMap: Record<string, NER> = {};
    for (const n of resource.nodes) nodeMap[n.name] = n;

    const globals = resource.globals;
    if (globals?.timeout_ms) this.driver.timeoutMs = globals.timeout_ms;
    if (globals?.retries !== undefined) this.driver.retries = globals.retries;

    // Run state setup if needed (auth, locale, etc.)
    if (resource.setup) this.runSetup(resource.setup);

    const rootNode = nodeMap[resource.entry.root];
    if (!rootNode) throw new Error(`Root node '${resource.entry.root}' not found`);

    // If resource consumes artifact(s), iterate over their merged records.
    const consumeNames = this.toArray(resource.consumes);
    if (consumeNames.length > 0 && this.store) {
      const consumed = this.mergeConsumed(consumeNames);
      if (consumed.length === 0) {
        console.warn(`[engine] Consumed artifacts empty: ${consumeNames.join(", ")}`);
        return [];
      }
      console.log(`[engine] Consuming ${consumed.length} records from [${consumeNames.join(", ")}]`);
      return this.runResourceOverRecords(resource, rootNode, nodeMap, consumed);
    }

    // Otherwise: single entry URL, run once
    return this.runResourceOnce(resource, rootNode, nodeMap, resource.entry.url, null);
  }

  /** Run the resource once per consumed record, resolving {field_ref} in entry URL. */
  private runResourceOverRecords(
    resource: Resource,
    rootNode: NER,
    nodeMap: Record<string, NER>,
    records: ExtractedRecord[],
  ): ExtractedRecord[] {
    const globals = resource.globals;
    const allRecords: ExtractedRecord[] = [];

    for (let i = 0; i < records.length; i++) {
      const rec = records[i];
      const url = this.resolveTemplate(resource.entry.url, rec.data);
      console.log(`[engine] [${i + 1}/${records.length}] ${url}`);

      const result = this.runResourceOnce(resource, rootNode, nodeMap, url, rec.data);
      allRecords.push(...result);

      if (globals?.request_interval_ms && i < records.length - 1) {
        this.driver.wait({ ms: globals.request_interval_ms });
      }
    }
    return allRecords;
  }

  /** Run the resource on a single URL. */
  private runResourceOnce(
    resource: Resource,
    rootNode: NER,
    nodeMap: Record<string, NER>,
    url: string,
    consumedData: Record<string, unknown> | null,
  ): ExtractedRecord[] {
    const globals = resource.globals;

    if (!url.startsWith("http")) {
      console.error(`[engine] Invalid URL: ${url}`);
      return [];
    }

    if (this.visited.has(url)) {
      console.log(`[engine] Skipping visited: ${url}`);
      return [];
    }
    this.visited.add(url);

    if (!this.driver.open(url, { wait: { idle: true } })) {
      console.error(`[engine] Failed to open: ${url}`);
      return [];
    }

    if (globals?.page_load_delay_ms) {
      this.driver.wait({ ms: globals.page_load_delay_ms });
    }

    this.interrupts.check();

    const records: ExtractedRecord[] = [];
    this.walkNode(rootNode, nodeMap, records, 0, {});
    return records;
  }

  /** Resolve {field_ref} placeholders in a template string from a data record. */
  private resolveTemplate(template: string, data: Record<string, unknown>): string {
    return template.replace(/\{(\w+)\}/g, (_match, field: string) => {
      const val = data[field];
      return (val !== undefined && val !== null) ? String(val) : `{${field}}`;
    });
  }

  // ── state setup ───────────────────────────────────────

  private runSetup(setup: { skip_when: string; actions: SetupAction[] }): void {
    if (this.driver.exists(setup.skip_when)) {
      console.log("[setup] skip_when selector found, skipping setup");
      return;
    }
    console.log("[setup] Running state setup...");
    for (const act of setup.actions) {
      if ("open" in act) {
        this.driver.open(act.open, { wait: { idle: true } });
      } else if ("click" in act) {
        this.driver.click(act.click);
      } else if ("input" in act) {
        this.driver.type(act.input.target, act.input.value);
      } else if ("password" in act) {
        const value = process.env[act.password.env];
        if (!value) throw new Error(`Env var '${act.password.env}' not set for password setup`);
        this.driver.type(act.password.target, value);
      }
    }
    this.driver.wait({ idle: true });
  }

  // ── graph walker ──────────────────────────────────────

  private walkNode(
    node: NER,
    allNodes: Record<string, NER>,
    records: ExtractedRecord[],
    depth: number,
    context: Record<string, unknown>,    // accumulated fields from ancestors
  ): void {
    const indent = "  ".repeat(depth);

    // If this node consumes artifact(s), iterate over their records
    const consumeNames = this.toArray(node.consumes);
    if (consumeNames.length > 0 && this.store) {
      const consumed = this.mergeConsumed(consumeNames);
      if (consumed.length === 0) {
        console.log(`${indent}[node] ${node.name} — consumed artifacts empty, skipping`);
        return;
      }
      console.log(`${indent}[node] ${node.name} — consuming ${consumed.length} records`);
      for (let i = 0; i < consumed.length; i++) {
        const rec = consumed[i];
        console.log(`${indent}  [consume ${i + 1}/${consumed.length}]`);
        const mergedContext = { ...context, ...rec.data };
        this.walkNodeOnce(node, allNodes, records, depth, mergedContext);
      }
      return;
    }

    this.walkNodeOnce(node, allNodes, records, depth, context);
  }

  /**
   * Execute a single pass of a node.
   * Context = accumulated fields from all ancestors + consumed records.
   * Each node's extraction merges into context before passing to children.
   */
  private walkNodeOnce(
    node: NER,
    allNodes: Record<string, NER>,
    records: ExtractedRecord[],
    depth: number,
    context: Record<string, unknown>,
  ): void {
    const indent = "  ".repeat(depth);
    console.log(`${indent}[node] ${node.name}`);

    // 1. Check state (preconditions) — with retry support
    if (node.state && !this.checkState(node.state)) {
      if (node.retry) {
        const ok = this.retryNode(node, allNodes, indent);
        if (!ok) {
          console.log(`${indent}  State check failed after ${node.retry.max} retries, skipping`);
          return;
        }
      } else {
        console.log(`${indent}  State check failed, skipping`);
        return;
      }
    }

    // 2. Execute actions (context available for {field_ref})
    for (const action of node.action ?? []) {
      this.executeAction(action, records, indent, context);
    }

    // Check for interrupts after actions
    this.interrupts.check();

    // 3. Observe (extract data) — merge with ancestor context
    // Skip node-level extraction if this node has expand — expansion handles
    // per-element extraction. Node-level extract + expand would double-count.
    if (!node.expand) {
      const extracted = this.extract(node, indent);
      const childContext = extracted ? { ...context, ...extracted } : context;

      if (extracted) {
        const data = { ...context, ...extracted };
        let record = this.makeRecord(node.name, data);
        record = this.hooks.invoke("post_extract", record);
        records.push(record);
        this.yieldToArtifacts(node, record);
      }

      if (node.delay_ms) this.driver.wait({ ms: node.delay_ms });
      this.walkChildren(node.name, allNodes, records, depth, childContext);
    } else {
      // 4. Expand handles extraction per-element, passing context down
      if (node.delay_ms) this.driver.wait({ ms: node.delay_ms });
      this.expandAndDescend(node, allNodes, records, depth, context);
    }
  }

  /** Yield a record into the node's declared artifact stream(s). */
  private yieldToArtifacts(node: NER, record: ExtractedRecord): void {
    if (!node.yields || !this.store) return;
    const names = this.toArray(node.yields);
    for (const name of names) {
      this.store.put(name, [record]);
    }
  }

  /** Normalize string | string[] | undefined to string[]. */
  private toArray(val: string | string[] | undefined): string[] {
    if (!val) return [];
    return Array.isArray(val) ? val : [val];
  }

  /** Merge records from multiple consumed artifacts. */
  private mergeConsumed(artifactNames: string[]): ExtractedRecord[] {
    if (!this.store) return [];
    const all: ExtractedRecord[] = [];
    for (const name of artifactNames) {
      all.push(...this.store.get(name));
    }
    return all;
  }

  // ── retry ─────────────────────────────────────────────

  /**
   * Re-execute parent's actions and re-check this node's state,
   * up to retry.max times. Returns true if state eventually passes.
   */
  private retryNode(
    node: NER,
    allNodes: Record<string, NER>,
    indent: string,
  ): boolean {
    const retry = node.retry!;
    for (let attempt = 1; attempt <= retry.max; attempt++) {
      console.log(`${indent}  [retry ${attempt}/${retry.max}] waiting ${retry.delay_ms}ms...`);
      this.driver.wait({ ms: retry.delay_ms });

      // Re-execute parent actions to attempt state recovery
      for (const parentName of node.parents) {
        const parent = allNodes[parentName];
        if (parent?.action) {
          for (const action of parent.action) {
            this.executeAction(action, [], indent);
          }
        }
      }

      if (this.checkState(node.state!)) {
        console.log(`${indent}  [retry] State check passed on attempt ${attempt}`);
        return true;
      }
    }
    return false;
  }

  // ── state checking ────────────────────────────────────

  private checkState(state: State): boolean {
    if (!state || Object.keys(state).length === 0) return true;
    const url = this.driver.getUrl() ?? "";

    if (state.url && !url.includes(state.url)) return false;
    if (state.url_pattern && !url.includes(state.url_pattern)) return false;

    if (state.selector_exists && !this.driver.exists(state.selector_exists)) return false;

    if (state.text_in_page) {
      const found = this.driver.evalJson<boolean>(`
        (() => document.body.innerText.includes('${escapeJs(state.text_in_page)}'))()
      `);
      if (!found) return false;
    }

    if (state.table_headers) {
      const headers = state.table_headers;
      const found = this.driver.evalJson<boolean>(`
        (() => {
          const ths = [...document.querySelectorAll('th')].map(h => h.textContent.trim());
          const need = ${JSON.stringify(headers)};
          return need.every(h => ths.includes(h));
        })()
      `);
      if (!found) return false;
    }

    return true;
  }

  // ── action execution ──────────────────────────────────

  private executeAction(
    action: Action,
    records: ExtractedRecord[],
    indent: string,
    consumedData?: Record<string, unknown> | null,
  ): void {
    if ("click" in action) {
      console.log(`${indent}  [action] click`);
      this.driver.click(action.click, { type: action.type });
      if (action.delay_ms) this.driver.wait({ ms: action.delay_ms });

    } else if ("select" in action) {
      console.log(`${indent}  [action] select → ${action.value}`);
      this.driver.select(action.select, action.value);
      if (action.delay_ms) this.driver.wait({ ms: action.delay_ms });

    } else if ("scroll" in action) {
      if (action.scroll === "to" && action.target) {
        console.log(`${indent}  [action] scroll to target`);
        this.scrollToTarget(action.target, action.ready, action.delay_ms);
      } else {
        console.log(`${indent}  [action] scroll ${action.scroll}`);
        this.driver.scroll(action.scroll as "down" | "up", action.px);
        if (action.delay_ms) this.driver.wait({ ms: action.delay_ms });
      }

    } else if ("wait" in action) {
      console.log(`${indent}  [action] wait`);
      this.driver.wait(action.wait as DriverWait);

    } else if ("reveal" in action) {
      console.log(`${indent}  [action] reveal`);
      if (action.mode === "hover") {
        this.driver.hover(action.reveal);
      } else {
        this.driver.click(action.reveal);
      }
      if (action.delay_ms) this.driver.wait({ ms: action.delay_ms });

    } else if ("navigate" in action) {
      const url = this.resolveUrl(action.navigate.to, records, consumedData ?? undefined);
      console.log(`${indent}  [action] navigate → ${url}`);
      this.driver.open(url, { wait: { idle: true } });

    } else if ("input" in action) {
      console.log(`${indent}  [action] input`);
      this.driver.type(action.input.target, action.input.value);
      if (action.delay_ms) this.driver.wait({ ms: action.delay_ms });
    }
  }

  /**
   * Scroll incrementally until target element is in the viewport,
   * then optionally wait for a readiness condition (e.g. lazy content loaded).
   */
  private scrollToTarget(
    target: Locator,
    ready?: { idle: true } | { selector: string } | { ms: number },
    delay_ms?: number,
  ): void {
    const css = locatorToSelector(target);
    const maxScrolls = 50;
    for (let i = 0; i < maxScrolls; i++) {
      const visible = this.driver.evalJson<boolean>(`
        (() => {
          const el = document.querySelector('${escapeJs(css)}');
          if (!el) return false;
          const rect = el.getBoundingClientRect();
          return rect.top >= 0 && rect.top <= window.innerHeight;
        })()
      `);
      if (visible) {
        // Target in viewport — now wait for content readiness if specified
        if (ready) this.driver.wait(ready as DriverWait);
        if (delay_ms) this.driver.wait({ ms: delay_ms });
        return;
      }
      this.driver.scroll("down", 500);
      this.driver.wait({ ms: 300 });
    }
    console.log(`    [scroll-to] Target not visible after ${maxScrolls} scrolls`);
  }

  /** Resolve {field_ref} from accumulated context, then fall back to record history. */
  private resolveUrl(
    template: string,
    records: ExtractedRecord[],
    context?: Record<string, unknown>,
  ): string {
    return template.replace(/\{(\w+)\}/g, (_match, field: string) => {
      // 1. Accumulated context (ancestors + consumed data)
      if (context) {
        const val = context[field];
        if (val !== undefined && val !== null) return String(val);
      }
      // 2. Fall back to most recent record
      for (let i = records.length - 1; i >= 0; i--) {
        const val = records[i].data[field];
        if (val !== undefined && val !== null) return String(val);
      }
      return `{${field}}`;
    });
  }

  // ── extraction ────────────────────────────────────────

  private extract(node: NER, indent: string): Record<string, unknown> | null {
    const rules = node.extract;
    if (!rules || rules.length === 0) return null;

    const result: Record<string, unknown> = {};
    for (const rule of rules) {
      if ("text" in rule) {
        const { name, css, regex } = rule.text;
        let val = this.domText(css);
        if (regex && val) {
          const m = val.match(new RegExp(regex));
          val = m ? m[0] : val;
        }
        result[name] = val ?? "";

      } else if ("attr" in rule) {
        result[rule.attr.name] = this.domAttr(rule.attr.css, rule.attr.attr) ?? "";

      } else if ("html" in rule) {
        result[rule.html.name] = this.domHtml(rule.html.css) ?? "";

      } else if ("link" in rule) {
        result[rule.link.name] = this.domAttr(rule.link.css, rule.link.attr) ?? "";

      } else if ("image" in rule) {
        result[rule.image.name] = this.domAttr(rule.image.css, "src") ?? "";

      } else if ("table" in rule) {
        result[rule.table.name] = this.domTable(rule.table);

      } else if ("grouped" in rule) {
        const { name, css, attr } = rule.grouped;
        result[name] = this.domGrouped(css, attr);

      } else if ("ai" in rule) {
        const { name, prompt, input, schema, categories } = rule.ai;
        const context = input ? String(result[input] ?? "") : "";
        if (categories && categories.length > 0) {
          result[name] = this.ai.classify(prompt, context, categories);
        } else {
          const aiResult = this.ai.extract(prompt, context, schema);
          result[name] = aiResult;
        }
      }
    }

    if (Object.keys(result).length > 0) {
      console.log(`${indent}  Extracted ${Object.keys(result).length} fields`);
    }
    return Object.keys(result).length > 0 ? result : null;
  }

  // ── DOM extraction helpers ────────────────────────────

  private domText(css: string): string | null {
    return this.driver.evalJson<string>(`
      (() => {
        const el = document.querySelector('${escapeJs(css)}');
        return el ? el.textContent.trim() : null;
      })()
    `);
  }

  private domAttr(css: string, attr: string): string | null {
    return this.driver.evalJson<string>(`
      (() => {
        const el = document.querySelector('${escapeJs(css)}');
        return el ? el.getAttribute('${escapeJs(attr)}') : null;
      })()
    `);
  }

  private domHtml(css: string): string | null {
    return this.driver.evalJson<string>(`
      (() => {
        const el = document.querySelector('${escapeJs(css)}');
        return el ? el.innerHTML : null;
      })()
    `);
  }

  private domGrouped(css: string, attr?: string): string[] {
    return this.driver.evalJson<string[]>(`
      (() => {
        const els = [...document.querySelectorAll('${escapeJs(css)}')];
        return els.map(el => ${attr ? `el.getAttribute('${escapeJs(attr)}')` : "el.textContent.trim()"});
      })()
    `) ?? [];
  }

  private domTable(cfg: {
    css: string;
    header_row: number;
    columns?: Array<{ name: string; header?: string; index?: number }>;
  }): Record<string, string>[] {
    const columns = cfg.columns ?? [];
    if (columns.length > 0) {
      // Header-based mapping (preferred)
      return this.driver.evalJson<Record<string, string>[]>(`
        (() => {
          const tbl = document.querySelector('${escapeJs(cfg.css)}');
          if (!tbl) return [];
          const hdr = tbl.querySelectorAll('tr')[${cfg.header_row}];
          const headers = [...(hdr?.querySelectorAll('th, td') || [])].map(c => c.textContent.trim());
          const colDefs = ${JSON.stringify(columns)};
          const colMap = colDefs.map(cd => {
            if (cd.header) return headers.indexOf(cd.header);
            if (cd.index !== undefined) return cd.index;
            return -1;
          });
          const dataRows = [...tbl.querySelectorAll('tr')].slice(${cfg.header_row + 1});
          return dataRows.map(row => {
            const cells = [...row.querySelectorAll('td, th')];
            const obj = {};
            colDefs.forEach((cd, i) => {
              const idx = colMap[i];
              obj[cd.name] = idx >= 0 && cells[idx] ? cells[idx].textContent.trim() : '';
            });
            return obj;
          });
        })()
      `) ?? [];
    }

    // No columns defined — return all cells as arrays
    return this.driver.evalJson<Record<string, string>[]>(`
      (() => {
        const tbl = document.querySelector('${escapeJs(cfg.css)}');
        if (!tbl) return [];
        const rows = [...tbl.querySelectorAll('tr')].slice(${cfg.header_row + 1});
        return rows.map(row =>
          [...row.querySelectorAll('td, th')].map(c => c.textContent.trim())
        );
      })()
    `) ?? [];
  }

  // ── expansion ─────────────────────────────────────────

  private expandAndDescend(
    node: NER,
    allNodes: Record<string, NER>,
    records: ExtractedRecord[],
    depth: number,
    context: Record<string, unknown>,
  ): void {
    const expand = node.expand!;
    const indent = "  ".repeat(depth);

    if (expand.over === "elements") {
      this.expandElements(node, expand, allNodes, records, depth, indent, context);
    } else if (expand.over === "pages") {
      this.expandPages(node, expand, allNodes, records, depth, indent, context);
    } else if (expand.over === "combinations") {
      this.expandCombinations(node, expand, allNodes, records, depth, indent, context);
    }
  }

  // ── expand: elements ──────────────────────────────────

  private expandElements(
    node: NER,
    expand: { over: "elements"; scope: string; limit?: number; order: "dfs" | "bfs" },
    allNodes: Record<string, NER>,
    records: ExtractedRecord[],
    depth: number,
    indent: string,
    context: Record<string, unknown>,
  ): void {
    const extractRules = node.extract ?? [];
    const rows = this.extractMultiple(expand.scope, extractRules, expand.limit);
    console.log(`${indent}  Expand elements: ${rows.length} matches`);

    if (expand.order === "bfs") {
      // BFS: collect all observations, then walk children
      const batch: Array<{ record: ExtractedRecord; childCtx: Record<string, unknown> }> = [];
      for (const row of rows) {
        const data = { ...context, ...row };
        let record = this.makeRecord(node.name, data);
        record = this.hooks.invoke("post_extract", record);
        batch.push({ record, childCtx: data });
        records.push(record);
        this.yieldToArtifacts(node, record);
      }
      for (const { childCtx } of batch) {
        this.walkChildren(node.name, allNodes, records, depth, childCtx);
      }
    } else {
      // DFS: process each element fully before next
      for (const row of rows) {
        const data = { ...context, ...row };
        let record = this.makeRecord(node.name, data);
        record = this.hooks.invoke("post_extract", record);
        records.push(record);
        this.yieldToArtifacts(node, record);
        this.walkChildren(node.name, allNodes, records, depth, data);
      }
    }
  }

  private extractMultiple(
    scope: string,
    rules: Extraction[],
    limit?: number,
  ): Record<string, unknown>[] {
    if (rules.length === 0) {
      // No extraction rules — just count elements for iteration
      const count = this.driver.evalJson<number>(`
        (() => document.querySelectorAll('${escapeJs(scope)}').length)()
      `) ?? 0;
      return Array.from({ length: Math.min(count, limit ?? count) }, () => ({}));
    }

    const fieldJs = rules
      .map((rule) => this.extractionToJs(rule))
      .join("\n");

    const limitJs = limit ? `.slice(0, ${limit})` : "";

    return this.driver.evalJson<Record<string, unknown>[]>(`
      (() => {
        const rows = [...document.querySelectorAll('${escapeJs(scope)}')]${limitJs};
        return rows.map(container => {
          const result = {};
          ${fieldJs}
          return result;
        });
      })()
    `) ?? [];
  }

  // ── expand: pages ─────────────────────────────────────

  private expandPages(
    node: NER,
    expand: {
      over: "pages";
      strategy: "next" | "numeric" | "infinite";
      control: string;
      limit: number;
      start: number;
      stop?: StopCondition;
      order: "dfs" | "bfs";
    },
    allNodes: Record<string, NER>,
    records: ExtractedRecord[],
    depth: number,
    indent: string,
    context: Record<string, unknown>,
  ): void {
    console.log(`${indent}  Expand pages: strategy=${expand.strategy}, limit=${expand.limit}`);

    if (expand.strategy === "numeric") {
      this.expandNumericPages(node, expand, allNodes, records, depth, indent, context);
    } else if (expand.strategy === "next") {
      this.expandNextPages(node, expand, allNodes, records, depth, indent, context);
    } else if (expand.strategy === "infinite") {
      this.expandInfiniteScroll(node, expand, allNodes, records, depth, indent, context);
    }
  }

  private expandNumericPages(
    node: NER,
    expand: { control: string; limit: number; order: "dfs" | "bfs" },
    allNodes: Record<string, NER>,
    records: ExtractedRecord[],
    depth: number,
    indent: string,
    context: Record<string, unknown>,
  ): void {
    const pageUrls = this.driver.evalJson<string[]>(`
      (() => {
        const links = [...document.querySelectorAll('${escapeJs(expand.control)}')];
        const current = window.location.href;
        const urls = [current, ...links.map(a => a.href)].filter((v,i,s) => s.indexOf(v) === i);
        return urls;
      })()
    `) ?? [];

    const limited = pageUrls.slice(0, expand.limit);
    console.log(`${indent}  Discovered ${limited.length} pages`);

    for (let i = 0; i < limited.length; i++) {
      console.log(`${indent}  Page ${i + 1}/${limited.length}`);
      if (i > 0) this.driver.open(limited[i], { wait: { idle: true } });
      this.walkChildren(node.name, allNodes, records, depth, context);
    }
  }

  private expandNextPages(
    node: NER,
    expand: { control: string; limit: number; stop?: StopCondition },
    allNodes: Record<string, NER>,
    records: ExtractedRecord[],
    depth: number,
    indent: string,
    context: Record<string, unknown>,
  ): void {
    for (let page = 0; page < expand.limit; page++) {
      console.log(`${indent}  Page ${page + 1}/${expand.limit}`);
      this.walkChildren(node.name, allNodes, records, depth, context);

      if (!this.driver.exists(expand.control)) {
        console.log(`${indent}  No more pages (control not found)`);
        break;
      }
      if (expand.stop?.sentinel && this.driver.exists(expand.stop.sentinel)) {
        console.log(`${indent}  Sentinel found`);
        break;
      }
      if (expand.stop?.sentinel_gone && !this.driver.exists(expand.stop.sentinel_gone)) {
        console.log(`${indent}  Sentinel gone`);
        break;
      }

      this.driver.click({ css: expand.control });
      this.driver.wait({ idle: true });
    }
  }

  private expandInfiniteScroll(
    node: NER,
    expand: { limit: number; stop?: StopCondition },
    allNodes: Record<string, NER>,
    records: ExtractedRecord[],
    depth: number,
    indent: string,
    context: Record<string, unknown>,
  ): void {
    const maxIter = expand.stop?.limit ?? expand.limit;
    let stableCount = 0;
    let lastCount = -1;

    for (let page = 0; page < maxIter; page++) {
      console.log(`${indent}  Scroll ${page + 1}/${maxIter}`);
      this.walkChildren(node.name, allNodes, records, depth, context);
      this.driver.scroll("down", 2000);
      this.driver.wait({ ms: 1500 });

      if (expand.stop?.sentinel && this.driver.exists(expand.stop.sentinel)) {
        console.log(`${indent}  Sentinel found: ${expand.stop.sentinel}`);
        break;
      }
      if (expand.stop?.sentinel_gone && !this.driver.exists(expand.stop.sentinel_gone)) {
        console.log(`${indent}  Sentinel gone: ${expand.stop.sentinel_gone}`);
        break;
      }
      if (expand.stop?.stable) {
        const currentCount = this.driver.evalJson<number>(`
          document.querySelectorAll('${escapeJs(expand.stop.stable.css)}').length
        `) ?? 0;
        if (currentCount === lastCount) {
          stableCount++;
          if (stableCount >= (expand.stop.stable.after ?? 2)) {
            console.log(`${indent}  Stable: ${currentCount} elements unchanged for ${stableCount} scrolls`);
            break;
          }
        } else {
          stableCount = 0;
        }
        lastCount = currentCount;
      }
    }
  }

  // ── expand: combinations ──────────────────────────────

  private expandCombinations(
    node: NER,
    expand: {
      over: "combinations";
      axes: Array<{ action: "select" | "type" | "checkbox" | "click"; control: string; values: string[] | "auto" }>;
      order: "dfs" | "bfs";
    },
    allNodes: Record<string, NER>,
    records: ExtractedRecord[],
    depth: number,
    indent: string,
    context: Record<string, unknown>,
  ): void {
    const resolvedAxes = expand.axes.map((axis) => {
      if (axis.values === "auto") {
        const values = this.discoverAxisValues(axis.control, axis.action);
        return { ...axis, values };
      }
      return { ...axis, values: axis.values as string[] };
    });

    const combos = cartesian(resolvedAxes.map((a) => a.values));
    console.log(`${indent}  Expand combinations: ${combos.length} combos across ${resolvedAxes.length} axes`);

    for (const combo of combos) {
      console.log(`${indent}  Combo: [${combo.join(", ")}]`);
      for (let i = 0; i < combo.length; i++) {
        const axis = resolvedAxes[i];
        const val = combo[i];
        if (axis.action === "select") {
          this.driver.select({ css: axis.control }, val);
        } else if (axis.action === "type") {
          this.driver.type({ css: axis.control }, val);
        } else if (axis.action === "checkbox") {
          this.driver.click({ css: axis.control });
        } else if (axis.action === "click") {
          // Click the Nth button/swatch matching the control selector
          // val is the button text or value to match
          this.driver.eval(`
            (() => {
              const btns = [...document.querySelectorAll('${escapeJs(axis.control)}')];
              const target = btns.find(b => b.textContent.trim() === '${escapeJs(val)}' || b.value === '${escapeJs(val)}');
              if (target) target.click();
            })()
          `);
        }
      }
      this.driver.wait({ idle: true });
      this.walkChildren(node.name, allNodes, records, depth, context);
    }
  }

  private discoverAxisValues(control: string, action: string): string[] {
    if (action === "select") {
      return this.driver.evalJson<string[]>(`
        (() => {
          const opts = [...document.querySelectorAll('${escapeJs(control)} option')];
          return opts.map(o => o.value).filter(v => v !== '');
        })()
      `) ?? [];
    }
    if (action === "click") {
      // Discover button text values from matching elements
      return this.driver.evalJson<string[]>(`
        (() => {
          const btns = [...document.querySelectorAll('${escapeJs(control)}')];
          return btns.filter(b => !b.disabled).map(b => b.textContent.trim()).filter(v => v !== '');
        })()
      `) ?? [];
    }
    return [];
  }

  // ── children ──────────────────────────────────────────

  private walkChildren(
    parentName: string,
    allNodes: Record<string, NER>,
    records: ExtractedRecord[],
    depth: number,
    context: Record<string, unknown>,
  ): void {
    const children = Object.values(allNodes).filter(
      (n) => (n.parents ?? []).includes(parentName),
    );
    if (children.length === 0) return;

    // Topological sort: respect artifact yields/consumes dependencies
    const sorted = ArtifactStore.resolveNodeOrder(children);
    for (const name of sorted) {
      this.walkNode(allNodes[name], allNodes, records, depth + 1, context);
    }
  }

  // ── helpers ───────────────────────────────────────────

  private makeRecord(nodeName: string, data: Record<string, unknown>): ExtractedRecord {
    return {
      node: nodeName,
      url: this.driver.getUrl() ?? "",
      data,
      extracted_at: new Date().toISOString(),
    };
  }

  /**
   * Compile an extraction rule to inline JS for use inside evalJson.
   * Operates relative to a `container` variable (the scoped element).
   */
  private extractionToJs(rule: Extraction): string {
    if ("text" in rule) {
      const { name, css, regex } = rule.text;
      const base = `container.querySelector('${escapeJs(css)}')?.textContent?.trim() || ''`;
      if (regex) {
        return `result['${escapeJs(name)}'] = (() => { const v = ${base}; const m = v.match(${regex}); return m ? m[0] : v; })();`;
      }
      return `result['${escapeJs(name)}'] = ${base};`;

    } else if ("attr" in rule) {
      return `result['${escapeJs(rule.attr.name)}'] = container.querySelector('${escapeJs(rule.attr.css)}')?.getAttribute('${escapeJs(rule.attr.attr)}') || '';`;

    } else if ("html" in rule) {
      return `result['${escapeJs(rule.html.name)}'] = container.querySelector('${escapeJs(rule.html.css)}')?.innerHTML || '';`;

    } else if ("link" in rule) {
      return `result['${escapeJs(rule.link.name)}'] = container.querySelector('${escapeJs(rule.link.css)}')?.getAttribute('${escapeJs(rule.link.attr)}') || '';`;

    } else if ("image" in rule) {
      return `result['${escapeJs(rule.image.name)}'] = container.querySelector('${escapeJs(rule.image.css)}')?.getAttribute('src') || '';`;

    } else if ("grouped" in rule) {
      const { name, css, attr } = rule.grouped;
      const read = attr
        ? `el.getAttribute('${escapeJs(attr)}')`
        : "el.textContent.trim()";
      return `result['${escapeJs(name)}'] = [...container.querySelectorAll('${escapeJs(css)}')].map(el => ${read});`;

    } else if ("table" in rule) {
      // Table extraction in multi-element context — simplified
      return `result['${escapeJs(rule.table.name)}'] = '[table in multi-scope unsupported]';`;

    } else if ("ai" in rule) {
      // AI extraction deferred to post-processing
      return `result['${escapeJs(rule.ai.name)}'] = '[ai:deferred]';`;
    }

    return "";
  }
}

// ── utilities ───────────────────────────────────────────

function cartesian(arrays: string[][]): string[][] {
  if (arrays.length === 0) return [[]];
  return arrays.reduce<string[][]>(
    (acc, arr) => acc.flatMap((combo) => arr.map((val) => [...combo, val])),
    [[]],
  );
}
