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
import type { ArtifactStore } from "./store.js";
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

    // Resolve entry URLs
    const entryUrls = this.resolveEntryUrls(resource);
    if (entryUrls.length === 0) {
      console.error("[engine] No entry URLs resolved");
      return [];
    }

    const rootNode = nodeMap[resource.entry.root];
    if (!rootNode) throw new Error(`Root node '${resource.entry.root}' not found`);

    const allRecords: ExtractedRecord[] = [];

    for (let i = 0; i < entryUrls.length; i++) {
      const url = entryUrls[i];
      if (entryUrls.length > 1) {
        console.log(`[engine] Page ${i + 1}/${entryUrls.length}: ${url}`);
      } else {
        console.log(`[engine] Opening: ${url}`);
      }

      if (!this.driver.open(url, { wait: { idle: true } })) {
        console.error(`[engine] Failed to open: ${url}`);
        continue;
      }

      if (globals?.page_load_delay_ms) {
        this.driver.wait({ ms: globals.page_load_delay_ms });
      }

      // Dismiss interrupts on first page (cookie banners etc.)
      if (i === 0) this.interrupts.check();

      const records: ExtractedRecord[] = [];
      this.walkNode(rootNode, nodeMap, records, 0);
      allRecords.push(...records);

      // Request interval between pages
      if (globals?.request_interval_ms && i < entryUrls.length - 1) {
        this.driver.wait({ ms: globals.request_interval_ms });
      }
    }

    return allRecords;
  }

  // ── entry URL resolution ──────────────────────────────

  private resolveEntryUrls(resource: Resource): string[] {
    const entry = resource.entry.url;

    // Direct URL string
    if (typeof entry === "string") return [entry];

    // Artifact reference: { from: "artifact_name" } or { from: "resource.node.field" }
    if ("from" in entry && this.store) {
      const ref = entry.from;
      // Try as artifact name first
      const urls = this.store.getUrls(ref);
      if (urls.length > 0) {
        console.log(`[engine] Resolved ${urls.length} URLs from artifact '${ref}'`);
        return urls;
      }
      // Try as dotted path: "resource_name.node_name.field_name" → look up artifact by resource.consumes
      if (resource.consumes) {
        const fromUrls = this.store.getUrls(resource.consumes);
        if (fromUrls.length > 0) {
          console.log(`[engine] Resolved ${fromUrls.length} URLs from consumed artifact '${resource.consumes}'`);
          return fromUrls;
        }
      }
      console.warn(`[engine] No URLs found for reference '${ref}'`);
      return [];
    }

    console.error("[engine] Cannot resolve entry URL — no store configured for artifact references");
    return [];
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
  ): void {
    const indent = "  ".repeat(depth);

    // If this node consumes an artifact, iterate over its records
    if (node.consumes && this.store) {
      const consumed = this.store.get(node.consumes);
      if (consumed.length === 0) {
        console.log(`${indent}[node] ${node.name} — consumed artifact '${node.consumes}' is empty, skipping`);
        return;
      }
      console.log(`${indent}[node] ${node.name} — consuming ${consumed.length} records from '${node.consumes}'`);
      for (let i = 0; i < consumed.length; i++) {
        const rec = consumed[i];
        console.log(`${indent}  [consume ${i + 1}/${consumed.length}]`);
        // Make consumed record's fields available for {field_ref} and navigate actions
        this.walkNodeOnce(node, allNodes, records, depth, rec.data);
      }
      return;
    }

    this.walkNodeOnce(node, allNodes, records, depth, null);
  }

  /** Execute a single pass of a node (state check → actions → extract → expand → children). */
  private walkNodeOnce(
    node: NER,
    allNodes: Record<string, NER>,
    records: ExtractedRecord[],
    depth: number,
    consumedData: Record<string, unknown> | null,
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

    // 2. Execute actions (with consumed data available for {field_ref})
    for (const action of node.action ?? []) {
      this.executeAction(action, records, indent, consumedData);
    }

    // Check for interrupts after actions
    this.interrupts.check();

    // 3. Observe (extract data)
    const extracted = this.extract(node, indent);
    if (extracted) {
      // Merge consumed data fields into extracted record if present
      const data = consumedData ? { ...consumedData, ...extracted } : extracted;
      let record = this.makeRecord(node.name, data);
      record = this.hooks.invoke("post_extract", record);
      records.push(record);

      // Yield into artifact stream if declared
      if (node.yields && this.store) {
        this.store.put(node.yields, [record]);
      }
    }

    // Node delay
    if (node.delay_ms) this.driver.wait({ ms: node.delay_ms });

    // 4. Expand + 5. Walk children
    if (node.expand) {
      this.expandAndDescend(node, allNodes, records, depth);
    } else {
      this.walkChildren(node.name, allNodes, records, depth);
    }
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
      const url = this.resolveUrl(action.navigate.to, records, consumedData);
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

  private resolveUrl(
    template: string,
    records: ExtractedRecord[],
    consumedData?: Record<string, unknown> | null,
  ): string {
    return template.replace(/\{(\w+)\}/g, (_match, field: string) => {
      // 1. Check consumed data first (from node-level consumes)
      if (consumedData) {
        const val = consumedData[field];
        if (val !== undefined && val !== null) return String(val);
      }
      // 2. Fall back to most recent record in extraction history
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
  ): void {
    const expand = node.expand!;
    const indent = "  ".repeat(depth);

    if (expand.over === "elements") {
      this.expandElements(node, expand, allNodes, records, depth, indent);
    } else if (expand.over === "pages") {
      this.expandPages(node, expand, allNodes, records, depth, indent);
    } else if (expand.over === "combinations") {
      this.expandCombinations(node, expand, allNodes, records, depth, indent);
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
  ): void {
    // Extract data from all matching elements
    const extractRules = node.extract ?? [];
    const rows = this.extractMultiple(expand.scope, extractRules, expand.limit);
    console.log(`${indent}  Expand elements: ${rows.length} matches`);

    if (expand.order === "bfs") {
      // BFS: collect all observations first, then walk children for each
      const batchRecords: ExtractedRecord[] = [];
      for (const row of rows) {
        let record = this.makeRecord(node.name, row);
        record = this.hooks.invoke("post_extract", record);
        batchRecords.push(record);
        records.push(record);
        if (node.yields && this.store) this.store.put(node.yields, [record]);
      }
      for (const _rec of batchRecords) {
        this.walkChildren(node.name, allNodes, records, depth);
      }
    } else {
      // DFS: process each element fully before moving to next
      for (const row of rows) {
        let record = this.makeRecord(node.name, row);
        record = this.hooks.invoke("post_extract", record);
        records.push(record);
        if (node.yields && this.store) this.store.put(node.yields, [record]);
        this.walkChildren(node.name, allNodes, records, depth);
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
  ): void {
    console.log(`${indent}  Expand pages: strategy=${expand.strategy}, limit=${expand.limit}`);

    if (expand.strategy === "numeric") {
      this.expandNumericPages(node, expand, allNodes, records, depth, indent);
    } else if (expand.strategy === "next") {
      this.expandNextPages(node, expand, allNodes, records, depth, indent);
    } else if (expand.strategy === "infinite") {
      this.expandInfiniteScroll(node, expand, allNodes, records, depth, indent);
    }
  }

  private expandNumericPages(
    node: NER,
    expand: { control: string; limit: number; order: "dfs" | "bfs" },
    allNodes: Record<string, NER>,
    records: ExtractedRecord[],
    depth: number,
    indent: string,
  ): void {
    // Discover all page URLs from pagination links
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

    if (expand.order === "bfs") {
      // BFS: discover all pages, then walk children on each
      const urls = [...limited];
      for (let i = 0; i < urls.length; i++) {
        console.log(`${indent}  Page ${i + 1}/${urls.length}`);
        if (i > 0) {
          this.driver.open(urls[i], { wait: { idle: true } });
        }
        this.walkChildren(node.name, allNodes, records, depth);
      }
    } else {
      // DFS: process each page fully
      for (let i = 0; i < limited.length; i++) {
        console.log(`${indent}  Page ${i + 1}/${limited.length}`);
        if (i > 0) {
          this.driver.open(limited[i], { wait: { idle: true } });
        }
        this.walkChildren(node.name, allNodes, records, depth);
      }
    }
  }

  private expandNextPages(
    node: NER,
    expand: { control: string; limit: number; stop?: StopCondition },
    allNodes: Record<string, NER>,
    records: ExtractedRecord[],
    depth: number,
    indent: string,
  ): void {
    for (let page = 0; page < expand.limit; page++) {
      console.log(`${indent}  Page ${page + 1}/${expand.limit}`);
      this.walkChildren(node.name, allNodes, records, depth);

      // Check if next button exists
      if (!this.driver.exists(expand.control)) {
        console.log(`${indent}  No more pages (control not found)`);
        break;
      }

      // Check stop conditions
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
  ): void {
    const maxIter = expand.stop?.limit ?? expand.limit;
    let stableCount = 0;
    let lastCount = -1;

    for (let page = 0; page < maxIter; page++) {
      console.log(`${indent}  Scroll ${page + 1}/${maxIter}`);
      this.walkChildren(node.name, allNodes, records, depth);
      this.driver.scroll("down", 2000);
      this.driver.wait({ ms: 1500 });

      // Check sentinel: a specific element appeared
      if (expand.stop?.sentinel && this.driver.exists(expand.stop.sentinel)) {
        console.log(`${indent}  Sentinel found: ${expand.stop.sentinel}`);
        break;
      }

      // Check sentinel_gone: a specific element disappeared
      if (expand.stop?.sentinel_gone && !this.driver.exists(expand.stop.sentinel_gone)) {
        console.log(`${indent}  Sentinel gone: ${expand.stop.sentinel_gone}`);
        break;
      }

      // Check stability: element count stopped changing
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
      axes: Array<{ action: "select" | "type" | "checkbox"; control: string; values: string[] | "auto" }>;
      order: "dfs" | "bfs";
    },
    allNodes: Record<string, NER>,
    records: ExtractedRecord[],
    depth: number,
    indent: string,
  ): void {
    // Resolve "auto" values from DOM
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

      // Apply each axis value
      for (let i = 0; i < combo.length; i++) {
        const axis = resolvedAxes[i];
        const val = combo[i];
        if (axis.action === "select") {
          this.driver.select({ css: axis.control }, val);
        } else if (axis.action === "type") {
          this.driver.type({ css: axis.control }, val);
        } else if (axis.action === "checkbox") {
          this.driver.click({ css: axis.control });
        }
      }

      this.driver.wait({ idle: true });
      this.walkChildren(node.name, allNodes, records, depth);
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
    return [];
  }

  // ── children ──────────────────────────────────────────

  private walkChildren(
    parentName: string,
    allNodes: Record<string, NER>,
    records: ExtractedRecord[],
    depth: number,
  ): void {
    for (const node of Object.values(allNodes)) {
      if ((node.parents ?? []).includes(parentName)) {
        this.walkNode(node, allNodes, records, depth + 1);
      }
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
