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
  TreeRecord,
  SetupAction,
  StopCondition,
} from "./schema.js";

interface VisitTarget {
  url: string;
  consumedData: Record<string, unknown> | null;
}

export class Engine {
  private driver: BrowserDriver;
  private ai: AIAdapter;
  private hooks: HookRegistry;
  private interrupts: InterruptHandler;
  private store: ArtifactStore | null;
  private config: Record<string, unknown>;
  private visited = new Set<string>();   // URL dedup

  constructor(driver: BrowserDriver, ai: AIAdapter, hooks: HookRegistry, store?: ArtifactStore, config?: Record<string, unknown>) {
    this.driver = driver;
    this.ai = ai;
    this.hooks = hooks;
    this.interrupts = new InterruptHandler(driver);
    this.store = store ?? null;
    this.config = config ?? {};
  }

  // ── public API ────────────────────────────────────────

  /**
   * Run a resource and return tree-structured records.
   * Each root-level tree record contains nested children.
   * Emit declarations snapshot subtrees into artifact buckets.
   */
  runResourceTree(resource: Resource): TreeRecord[] {
    const nodeMap: Record<string, NER> = {};
    for (const n of resource.nodes) nodeMap[n.name] = n;

    const globals = resource.globals;
    if (globals?.timeout_ms) this.driver.timeoutMs = globals.timeout_ms;
    if (globals?.retries !== undefined) this.driver.retries = globals.retries;

    if (resource.setup) this.runSetup(resource.setup);

    const rootNode = nodeMap[resource.entry.root];
    if (!rootNode) throw new Error(`Root node '${resource.entry.root}' not found`);

    this.hooks.beginResource(resource.name);
    try {
      const consumeNames = this.toArray(resource.consumes);
      const targets: VisitTarget[] = [];
      const entryUrl = resource.entry.url;

      // { from: "resource.node.field" } — cross-resource tree reference
      if (typeof entryUrl === "object" && "from" in entryUrl && this.store) {
        const urls = this.store.resolveFrom(entryUrl.from);
        if (urls.length === 0) {
          console.warn(`[engine] {from: "${entryUrl.from}"} resolved to 0 URLs`);
          return [];
        }
        console.log(`[engine] {from: "${entryUrl.from}"} → ${urls.length} URLs`);
        for (const url of urls) {
          targets.push({ url: this.resolveRelativeUrl(url), consumedData: null });
        }
      } else if (consumeNames.length > 0 && this.store) {
        const urlTemplate = typeof entryUrl === "string" ? entryUrl : String(entryUrl);
        const consumed = this.mergeConsumed(consumeNames);
        if (consumed.length === 0) {
          console.warn(`[engine] Consumed artifacts empty: ${consumeNames.join(", ")}`);
          return [];
        }
        console.log(`[engine] Consuming ${consumed.length} records from [${consumeNames.join(", ")}]`);
        for (const rec of consumed) {
          targets.push({
            url: this.resolveTemplate(urlTemplate, rec.data),
            consumedData: rec.data,
          });
        }
      } else {
        const url = typeof entryUrl === "string" ? entryUrl : String(entryUrl);
        targets.push({ url, consumedData: null });
      }

      const discoverCtx = this.hooks.invoke("post_discover", {
        driver: this.driver,
        resource: resource.name,
        targets,
      }) as { targets?: VisitTarget[] };
      const finalTargets = Array.isArray(discoverCtx?.targets) ? discoverCtx.targets : targets;
      return this.runResourceTreeOverTargets(resource, rootNode, nodeMap, finalTargets);
    } finally {
      this.hooks.endResource();
    }
  }

  private runResourceTreeOverTargets(
    resource: Resource,
    rootNode: NER,
    nodeMap: Record<string, NER>,
    targets: VisitTarget[],
  ): TreeRecord[] {
    const globals = resource.globals;
    const all: TreeRecord[] = [];
    for (let i = 0; i < targets.length; i++) {
      const target = targets[i];
      console.log(`[engine] [${i + 1}/${targets.length}] ${target.url}`);
      all.push(...this.runResourceTreeOnce(resource, rootNode, nodeMap, target.url, target.consumedData));
      if (globals?.request_interval_ms && i < targets.length - 1) {
        this.driver.wait({ ms: globals.request_interval_ms });
      }
    }
    return all;
  }

  private runResourceTreeOnce(
    resource: Resource,
    rootNode: NER,
    nodeMap: Record<string, NER>,
    url: string,
    consumedData: Record<string, unknown> | null,
  ): TreeRecord[] {
    const globals = resource.globals;
    const preExtractCtx = this.hooks.invoke("pre_extract", {
      driver: this.driver,
      resource: resource.name,
      url,
      data: consumedData ?? {},
    }) as { url?: string; data?: Record<string, unknown> };
    const nextUrl = typeof preExtractCtx?.url === "string" && preExtractCtx.url.length > 0 ? preExtractCtx.url : url;
    const nextData = preExtractCtx?.data && typeof preExtractCtx.data === "object" && !Array.isArray(preExtractCtx.data)
      ? preExtractCtx.data
      : (consumedData ?? {});

    if (!nextUrl.startsWith("http")) { console.error(`[engine] Invalid URL: ${nextUrl}`); return []; }
    if (this.visited.has(nextUrl)) { console.log(`[engine] Skipping visited: ${nextUrl}`); return []; }
    this.visited.add(nextUrl);
    if (!this.driver.open(nextUrl, { wait: { idle: true } })) { console.error(`[engine] Failed to open: ${nextUrl}`); return []; }
    if (globals?.page_load_delay_ms) this.driver.wait({ ms: globals.page_load_delay_ms });
    this.interrupts.check();
    return this.walkNodeTree(rootNode, nodeMap, 0, nextData);
  }

  // ── tree walker ──────────────────────────────────────

  /**
   * Walk a node and return TreeRecord(s). Children nest inside parent.
   * If the node has consumes, it runs once per consumed record.
   */
  private walkNodeTree(
    node: NER, allNodes: Record<string, NER>,
    depth: number, context: Record<string, unknown>,
  ): TreeRecord[] {
    const consumeNames = this.toArray(node.consumes);
    if (consumeNames.length > 0 && this.store) {
      const consumed = this.mergeConsumed(consumeNames);
      if (consumed.length === 0) return [];
      const results: TreeRecord[] = [];
      for (const rec of consumed) {
        const merged = { ...context, ...rec.data };
        results.push(...this.walkNodeTreeOnce(node, allNodes, depth, merged));
      }
      return results;
    }
    return this.walkNodeTreeOnce(node, allNodes, depth, context);
  }

  /**
   * Execute a single pass of a node and return tree records.
   * The core NER loop: state → action → extract → expand → children.
   * Children are collected into the parent's `children` field unless they have their own emit.
   */
  private walkNodeTreeOnce(
    node: NER, allNodes: Record<string, NER>,
    depth: number, context: Record<string, unknown>,
  ): TreeRecord[] {
    const indent = "  ".repeat(depth);
    console.log(`${indent}[node] ${node.name}`);

    // 1. State check
    if (node.state && !this.checkState(node.state)) {
      if (node.retry) {
        if (!this.retryNode(node, allNodes, indent)) return [];
      } else {
        console.log(`${indent}  State check failed, skipping`);
        return [];
      }
    }

    // 2. Actions
    for (const action of node.action ?? []) {
      this.executeAction(action, [], indent, context);
    }
    this.interrupts.check();

    const preExtractContext = this.runNodePreExtract(node, context);

    // 3 & 4. Extract + Expand → build tree records
    if (!node.expand) {
      // No expansion: extract once, collect children
      const extracted = this.extract(node, indent);
      if (!extracted && !this.hasChildren(node.name, allNodes)) return [];

      const nodeData = extracted ?? {};
      const childrenMap = this.collectChildrenTree(node.name, allNodes, depth, { ...preExtractContext, ...nodeData });

      const tree: TreeRecord = {
        node: node.name,
        url: this.driver.getUrl() ?? "",
        data: nodeData,
        children: childrenMap,
        extracted_at: new Date().toISOString(),
      };

      let record: TreeRecord = this.hooks.invoke("post_extract", tree) as TreeRecord;
      record = this.runNodePostExtract(node, record) as TreeRecord;
      this.emitTreeToArtifacts(node, record as TreeRecord, preExtractContext);

      if (node.delay_ms) this.driver.wait({ ms: node.delay_ms });
      return [record as TreeRecord];
    } else {
      // Expansion: per-element/page/combo tree records
      if (node.delay_ms) this.driver.wait({ ms: node.delay_ms });
      return this.expandTree(node, allNodes, depth, indent, preExtractContext);
    }
  }

  /** Check if a node has any children in the graph. */
  private hasChildren(parentName: string, allNodes: Record<string, NER>): boolean {
    return Object.values(allNodes).some(n => (n.parents ?? []).includes(parentName));
  }

  /** Collect children that DON'T have their own emit — they nest into parent.
   *  Children WITH emit are processed but their results go to the store, not parent. */
  private collectChildrenTree(
    parentName: string, allNodes: Record<string, NER>,
    depth: number, context: Record<string, unknown>,
  ): Record<string, TreeRecord[]> {
    const children = Object.values(allNodes).filter(
      (n) => (n.parents ?? []).includes(parentName),
    );
    if (children.length === 0) return {};

    const sorted = ArtifactStore.resolveNodeOrder(children);
    const result: Record<string, TreeRecord[]> = {};

    for (const name of sorted) {
      const childNode = allNodes[name];
      const childTrees = this.walkNodeTree(childNode, allNodes, depth + 1, context);

      // Always nest children into the parent tree, even if they have their own
      // emit. Emit already copies subtrees to the artifact store independently
      // (via emitTreeToArtifacts in walkNodeTreeOnce). Keeping emit children in
      // the parent preserves the full tree hierarchy for JMESPath queries and
      // {from:} cross-resource references. The double-write prevention in run.ts
      // ensures resource-level produces skips artifacts that nodes already emit to.
      if (childTrees.length > 0) {
        result[name] = childTrees;
      }
    }
    return result;
  }

  /** Expand node via elements/pages/combinations and return tree records. */
  private expandTree(
    node: NER, allNodes: Record<string, NER>,
    depth: number, indent: string, context: Record<string, unknown>,
  ): TreeRecord[] {
    const expand = node.expand!;

    if (expand.over === "elements") {
      return this.expandElementsTree(node, expand, allNodes, depth, indent, context);
    } else if (expand.over === "pages") {
      return this.expandPagesTree(node, expand, allNodes, depth, indent, context);
    } else if (expand.over === "combinations") {
      return this.expandCombinationsTree(node, expand, allNodes, depth, indent, context);
    }
    return [];
  }

  private expandElementsTree(
    node: NER,
    expand: { over: "elements"; scope: string; limit?: number; order: "dfs" | "bfs" },
    allNodes: Record<string, NER>,
    depth: number, indent: string, context: Record<string, unknown>,
  ): TreeRecord[] {
    const extractRules = node.extract ?? [];
    const rows = this.extractMultiple(expand.scope, extractRules, expand.limit);
    console.log(`${indent}  Expand elements: ${rows.length} matches`);

    const trees: TreeRecord[] = [];

    if (expand.order === "bfs") {
      // BFS: collect all, then walk children
      const batch: Array<{ data: Record<string, unknown>; nodeData: Record<string, unknown> }> = [];
      for (const row of rows) {
        batch.push({ data: { ...context, ...row }, nodeData: row });
      }
      for (const { data, nodeData } of batch) {
        const childrenMap = this.collectChildrenTree(node.name, allNodes, depth, data);
        const tree: TreeRecord = {
          node: node.name, url: this.driver.getUrl() ?? "",
          data: nodeData, children: childrenMap,
          extracted_at: new Date().toISOString(),
        };
        let record: TreeRecord = this.hooks.invoke("post_extract", tree) as TreeRecord;
        record = this.runNodePostExtract(node, record) as TreeRecord;
        this.emitTreeToArtifacts(node, record, context);
        trees.push(record);
      }
    } else {
      // DFS: process each fully
      for (const row of rows) {
        const data = { ...context, ...row };
        const childrenMap = this.collectChildrenTree(node.name, allNodes, depth, data);
        const tree: TreeRecord = {
          node: node.name, url: this.driver.getUrl() ?? "",
          data: row, children: childrenMap,
          extracted_at: new Date().toISOString(),
        };
        let record: TreeRecord = this.hooks.invoke("post_extract", tree) as TreeRecord;
        record = this.runNodePostExtract(node, record) as TreeRecord;
        this.emitTreeToArtifacts(node, record, context);
        trees.push(record);
      }
    }
    return trees;
  }

  private expandPagesTree(
    node: NER,
    expand: { over: "pages"; strategy: string; control: string; limit: number; stop?: StopCondition; order: "dfs" | "bfs" },
    allNodes: Record<string, NER>,
    depth: number, indent: string, context: Record<string, unknown>,
  ): TreeRecord[] {
    // Pages expansion: walk children on each page, collecting tree results.
    // Reuses existing page navigation logic but returns trees.
    const trees: TreeRecord[] = [];

    if (expand.strategy === "next") {
      for (let page = 0; page < expand.limit; page++) {
        console.log(`${indent}  Page ${page + 1}/${expand.limit}`);
        trees.push(...this.collectPageTree(node, allNodes, depth, context));

        if (!this.driver.exists(expand.control)) {
          console.log(`${indent}  No more pages (control not found)`);
          break;
        }
        if (expand.stop?.sentinel && this.driver.exists(expand.stop.sentinel)) break;
        if (expand.stop?.sentinel_gone && !this.driver.exists(expand.stop.sentinel_gone)) break;

        this.navigateNextPage(expand.control);
      }
    } else if (expand.strategy === "numeric") {
      const current = this.driver.getUrl() ?? "";
      const links = this.driver.evalJson<string[]>(`
        (() => [...document.querySelectorAll('${escapeJs(expand.control)}')].map(a => a.href))()
      `) ?? [];
      const urls = [current, ...links].filter((v, i, s) => s.indexOf(v) === i);
      const limited = urls.slice(0, expand.limit);
      for (let i = 0; i < limited.length; i++) {
        if (i > 0) {
          this.driver.open(limited[i], { wait: { idle: true } });
          this.interrupts.check();
        }
        console.log(`${indent}  Page ${i + 1}/${limited.length}`);
        trees.push(...this.collectPageTree(node, allNodes, depth, context));
      }
    } else if (expand.strategy === "infinite") {
      const maxIter = expand.stop?.limit ?? expand.limit;
      let stableCount = 0;
      let lastCount = -1;
      for (let page = 0; page < maxIter; page++) {
        console.log(`${indent}  Scroll ${page + 1}/${maxIter}`);
        trees.push(...this.collectPageTree(node, allNodes, depth, context));
        this.driver.scroll("down", 2000);
        this.driver.wait({ ms: 1500 });
        if (expand.stop?.sentinel && this.driver.exists(expand.stop.sentinel)) break;
        if (expand.stop?.sentinel_gone && !this.driver.exists(expand.stop.sentinel_gone)) break;
        if (expand.stop?.stable) {
          const cc = this.driver.evalJson<number>(`
            document.querySelectorAll('${escapeJs(expand.stop.stable.css)}').length
          `) ?? 0;
          if (cc === lastCount) { stableCount++; if (stableCount >= (expand.stop.stable.after ?? 2)) break; }
          else stableCount = 0;
          lastCount = cc;
        }
      }
    }
    return trees;
  }

  /** Collect tree records from children on the current page. */
  private collectPageTree(
    node: NER, allNodes: Record<string, NER>,
    depth: number, context: Record<string, unknown>,
  ): TreeRecord[] {
    // For page expansion, the node itself may have extract rules
    // but children handle element expansion. Collect children as trees.
    const childrenMap = this.collectChildrenTree(node.name, allNodes, depth, context);
    // If the page node itself extracts, make a tree record for the page
    const extracted = this.extract(node, "  ".repeat(depth));
    if (extracted || Object.keys(childrenMap).length > 0) {
      const tree: TreeRecord = {
        node: node.name, url: this.driver.getUrl() ?? "",
        data: extracted ?? {}, children: childrenMap,
        extracted_at: new Date().toISOString(),
      };
      this.emitTreeToArtifacts(node, tree, context);
      return [tree];
    }
    // No extraction, just return children's trees flattened
    return Object.values(childrenMap).flat();
  }

  private expandCombinationsTree(
    node: NER,
    expand: { over: "combinations"; axes: Array<{ action: string; control: string; values: string[] | "auto" }>; order: "dfs" | "bfs" },
    allNodes: Record<string, NER>,
    depth: number, indent: string, context: Record<string, unknown>,
  ): TreeRecord[] {
    const resolvedAxes = expand.axes.map((axis) => {
      if (axis.values === "auto") return { ...axis, values: this.discoverAxisValues(axis.control, axis.action) };
      return { ...axis, values: axis.values as string[] };
    });
    const combos = cartesian(resolvedAxes.map((a) => a.values));
    console.log(`${indent}  Expand combinations: ${combos.length} combos`);

    const trees: TreeRecord[] = [];
    for (const combo of combos) {
      const comboContext: Record<string, unknown> = {};
      for (let i = 0; i < combo.length; i++) {
        const axis = resolvedAxes[i];
        const val = combo[i];
        comboContext[axis.control] = val;
        if (axis.action === "select") this.driver.select({ css: axis.control }, val);
        else if (axis.action === "type") this.driver.type({ css: axis.control }, val);
        else if (axis.action === "checkbox") this.driver.click({ css: axis.control });
        else if (axis.action === "click") {
          this.driver.eval(`(() => { const btns=[...document.querySelectorAll('${escapeJs(axis.control)}')]; const t=btns.find(b=>b.textContent.trim()==='${escapeJs(val)}'||b.value==='${escapeJs(val)}'); if(t)t.click(); })()`);
        }
      }
      this.driver.wait({ idle: true });
      const childrenMap = this.collectChildrenTree(node.name, allNodes, depth, { ...context, ...comboContext });
      const tree: TreeRecord = {
        node: node.name, url: this.driver.getUrl() ?? "",
        data: comboContext, children: childrenMap,
        extracted_at: new Date().toISOString(),
      };
      this.emitTreeToArtifacts(node, tree, context);
      trees.push(tree);
    }
    return trees;
  }

  // ── tree emit ────────────────────────────────────────

  /** Emit a tree record into artifact(s) per the node's emit declaration. */
  private emitTreeToArtifacts(node: NER, tree: TreeRecord, _context: Record<string, unknown>): void {
    if (!node.emit || !this.store) return;
    const emit = node.emit;

    if (typeof emit === "string") {
      this.store.putTree(emit, [tree]);
      return;
    }

    for (const target of emit) {
      if (target.flatten === true) {
        // Flatten entire subtree into flat records
        const flat = Engine.flattenTree([tree]);
        this.store.put(target.to, flat);
        console.log(`    [emit] Flattened ${flat.length} records → ${target.to}`);
      } else if (typeof target.flatten === "string") {
        // Check if flatten names a child node or a data field
        const childTrees = tree.children[target.flatten];
        if (childTrees && childTrees.length > 0) {
          // Flatten named child's subtrees
          const flat = Engine.flattenTree(childTrees, tree.data);
          this.store.put(target.to, flat);
          console.log(`    [emit] Flattened ${flat.length} records from child '${target.flatten}' → ${target.to}`);
        } else {
          // Fall back: flatten a data field containing an array (table extraction pattern)
          const arrayVal = tree.data[target.flatten];
          if (Array.isArray(arrayVal)) {
            const rows = arrayVal.map((row: unknown) => {
              const rowData = typeof row === "object" && row !== null
                ? { ...(row as Record<string, unknown>) }
                : { [target.flatten as string]: row };
              return { node: tree.node, url: tree.url, data: rowData, extracted_at: tree.extracted_at };
            });
            this.store.put(target.to, rows);
            console.log(`    [emit] Flattened ${rows.length} rows from field '${target.flatten}' → ${target.to}`);
          } else {
            // Neither child nor array field — emit as nested
            this.store.putTree(target.to, [tree]);
          }
        }
      } else {
        this.store.putTree(target.to, [tree]);
      }
    }
  }

  // ── tree utilities ───────────────────────────────────

  /**
   * Flatten a tree into denormalized flat records.
   * Ancestor data is spread into each leaf record.
   * If a tree has no children, it becomes one flat record.
   * If it has children, only leaves produce records (ancestors provide context).
   */
  static flattenTree(trees: TreeRecord[], parentData?: Record<string, unknown>): ExtractedRecord[] {
    const results: ExtractedRecord[] = [];
    for (const tree of trees) {
      const mergedData = parentData ? { ...parentData, ...tree.data } : { ...tree.data };
      const childKeys = Object.keys(tree.children);

      if (childKeys.length === 0) {
        // Leaf node — produce a flat record
        results.push({
          node: tree.node,
          url: tree.url,
          data: mergedData,
          extracted_at: tree.extracted_at,
        });
      } else {
        // Interior node — recurse into children, spreading this node's data as context
        for (const childTrees of Object.values(tree.children)) {
          results.push(...Engine.flattenTree(childTrees, mergedData));
        }
      }
    }
    return results;
  }

  // ── legacy flat API (backward compat) ────────────────

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
    const entryUrl = typeof resource.entry.url === "string" ? resource.entry.url : String(resource.entry.url);
    return this.runResourceOnce(resource, rootNode, nodeMap, entryUrl, null);
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
    const urlTemplate = typeof resource.entry.url === "string" ? resource.entry.url : String(resource.entry.url);

    for (let i = 0; i < records.length; i++) {
      const rec = records[i];
      const url = this.resolveTemplate(urlTemplate, rec.data);
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
    this.walkNode(rootNode, nodeMap, records, 0, consumedData ?? {});
    return records;
  }

  /**
   * Resolve template placeholders in a string. Three reference types:
   *   {field}              — from context data (consumed record, parent extraction)
   *   {artifacts.name.field} — latest record from named artifact in the store
   *   {config.key}         — from runner input config
   */
  private resolveTemplate(template: string, data: Record<string, unknown>): string {
    return template.replace(/\{([^}]+)\}/g, (_match, ref: string) => {
      // {artifacts.name.field} — cross-artifact reference
      const artMatch = ref.match(/^artifacts\.(\w+)\.(\w+)$/);
      if (artMatch && this.store) {
        const [, artName, fieldName] = artMatch;
        const records = this.store.get(artName);
        if (records.length > 0) {
          const val = records[records.length - 1].data[fieldName];
          if (val !== undefined && val !== null) return String(val);
        }
        // Fall back to tree store
        const trees = this.store.getTree(artName);
        if (trees.length > 0) {
          const val = trees[trees.length - 1].data[fieldName];
          if (val !== undefined && val !== null) return String(val);
        }
        return `{${ref}}`;
      }

      // {config.key} — input config reference
      const cfgMatch = ref.match(/^config\.(\w+)$/);
      if (cfgMatch) {
        const val = this.config[cfgMatch[1]];
        if (val !== undefined && val !== null) return String(val);
        return `{${ref}}`;
      }

      // {field} — context data reference (simple word characters only)
      if (/^\w+$/.test(ref)) {
        const val = data[ref];
        return (val !== undefined && val !== null) ? String(val) : `{${ref}}`;
      }

      return `{${ref}}`;
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

    const preExtractContext = this.runNodePreExtract(node, context);

    // 3. Observe (extract data) — merge with ancestor context
    // Skip node-level extraction if this node has expand — expansion handles
    // per-element extraction. Node-level extract + expand would double-count.
    if (!node.expand) {
      const extracted = this.extract(node, indent);

      if (extracted) {
        const data = { ...preExtractContext, ...extracted };
        let record: ExtractedRecord = this.makeRecord(node.name, data);
        record = this.hooks.invoke("post_extract", record) as ExtractedRecord;
        record = this.runNodePostExtract(node, record) as ExtractedRecord;
        records.push(record);
        this.emitToArtifacts(node, record, preExtractContext);
      }

      if (node.delay_ms) this.driver.wait({ ms: node.delay_ms });
      this.walkChildren(node.name, allNodes, records, depth, { ...preExtractContext, ...(extracted ?? {}) });
    } else {
      // 4. Expand handles extraction per-element, passing context down
      if (node.delay_ms) this.driver.wait({ ms: node.delay_ms });
      this.expandAndDescend(node, allNodes, records, depth, preExtractContext);
    }
  }

  /**
   * Emit a record into artifact(s) per the node's emit declaration.
   * Handles flatten: if a field contains an array of objects,
   * unpack each element into a separate record (merged with context).
   */
  private emitToArtifacts(node: NER, record: ExtractedRecord, context: Record<string, unknown>): void {
    if (!node.emit || !this.store) return;
    const emit = node.emit;

    // String shorthand: emit: "artifact_name"
    if (typeof emit === "string") {
      this.store.put(emit, [record]);
      return;
    }

    // Full form: emit: [{ to, flatten? }]
    for (const target of emit) {
      if (target.flatten && typeof target.flatten === "string") {
        // Flatten: unpack a named array field into per-row records (legacy flat path)
        const flattenField = target.flatten;
        const arrayVal = record.data[flattenField];
        if (Array.isArray(arrayVal)) {
          const rows = arrayVal.map((row: unknown) => {
            const rowData = typeof row === "object" && row !== null
              ? { ...context, ...(row as Record<string, unknown>) }
              : { ...context, [flattenField]: row };
            return this.makeRecord(node.name, rowData);
          });
          this.store.put(target.to, rows);
          console.log(`    [emit] Flattened ${rows.length} rows → ${target.to}`);
        } else {
          // Field isn't an array — emit as-is
          this.store.put(target.to, [record]);
        }
      } else {
        this.store.put(target.to, [record]);
      }
    }
  }

  /** Normalize string | string[] | undefined to string[]. */
  private toArray(val: string | string[] | undefined): string[] {
    if (!val) return [];
    return Array.isArray(val) ? val : [val];
  }

  /** Merge records from multiple consumed artifacts.
   *  Checks flat store first, then falls back to flattening tree store. */
  private mergeConsumed(artifactNames: string[]): ExtractedRecord[] {
    if (!this.store) return [];
    const all: ExtractedRecord[] = [];
    for (const name of artifactNames) {
      const flat = this.store.get(name);
      if (flat.length > 0) {
        all.push(...flat);
      } else {
        // Flatten tree records for consumption
        const trees = this.store.getTree(name);
        all.push(...Engine.flattenTree(trees));
      }
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
    // Intentional substring match (not regex) — simpler and sufficient for URL preconditions
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
        result[rule.link.name] = this.domAttr(rule.link.css, rule.link.attr ?? "href") ?? "";

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

    // No columns defined — auto-generate column names from header row (col_0, col_1, ...)
    return this.driver.evalJson<Record<string, string>[]>(`
      (() => {
        const tbl = document.querySelector('${escapeJs(cfg.css)}');
        if (!tbl) return [];
        const hdr = tbl.querySelectorAll('tr')[${cfg.header_row}];
        const headerCells = [...(hdr?.querySelectorAll('th, td') || [])];
        const colNames = headerCells.map((c, i) => {
          const text = c.textContent.trim();
          return text || ('col_' + i);
        });
        const rows = [...tbl.querySelectorAll('tr')].slice(${cfg.header_row + 1});
        return rows.map(row => {
          const cells = [...row.querySelectorAll('td, th')];
          const obj = {};
          const maxCols = Math.max(colNames.length, cells.length);
          for (let i = 0; i < maxCols; i++) {
            const key = i < colNames.length ? colNames[i] : ('col_' + i);
            obj[key] = i < cells.length ? cells[i].textContent.trim() : '';
          }
          return obj;
        });
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
    const offset = typeof context._extractOffset === "number" ? context._extractOffset : 0;
    const rows = this.extractMultiple(expand.scope, extractRules, expand.limit, offset);
    console.log(`${indent}  Expand elements: ${rows.length} matches (offset ${offset})`);

    if (expand.order === "bfs") {
      // BFS: collect all observations, then walk children
      const batch: Array<{ record: ExtractedRecord; childCtx: Record<string, unknown> }> = [];
      for (const row of rows) {
        const data = { ...context, ...row };
        let record: ExtractedRecord = this.makeRecord(node.name, data);
        record = this.hooks.invoke("post_extract", record) as ExtractedRecord;
        record = this.runNodePostExtract(node, record) as ExtractedRecord;
        batch.push({ record, childCtx: data });
        records.push(record);
        this.emitToArtifacts(node, record, context);
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
        record = this.runNodePostExtract(node, record);
        records.push(record);
        this.emitToArtifacts(node, record, context);
        this.walkChildren(node.name, allNodes, records, depth, data);
      }
    }
  }

  private extractMultiple(
    scope: string,
    rules: Extraction[],
    limit?: number,
    offset = 0,
  ): Record<string, unknown>[] {
    if (rules.length === 0) {
      // No extraction rules — just count elements for iteration
      const count = this.driver.evalJson<number>(`
        (() => document.querySelectorAll('${escapeJs(scope)}').length)()
      `) ?? 0;
      const effective = Math.max(0, count - offset);
      return Array.from({ length: Math.min(effective, limit ?? effective) }, () => ({}));
    }

    const fieldJs = rules
      .filter((rule) => !("ai" in rule))
      .map((rule) => this.extractionToJs(rule))
      .join("\n");

    const sliceStart = offset > 0 ? `.slice(${offset})` : "";
    const sliceLimit = limit ? `.slice(0, ${limit})` : "";

    const rows = this.driver.evalJson<Record<string, unknown>[]>(`
      (() => {
        const rows = [...document.querySelectorAll('${escapeJs(scope)}')]${sliceStart}${sliceLimit};
        return rows.map(container => {
          const result = {};
          ${fieldJs}
          return result;
        });
      })()
    `) ?? [];

    return rows.map((row) => this.applyAiRules(row, rules));
  }

  private runNodePreExtract(node: NER, context: Record<string, unknown>): Record<string, unknown> {
    const result = this.hooks.invokeDefs("pre_extract", node.hooks?.pre_extract, {
      driver: this.driver,
      node: node.name,
      url: this.driver.getUrl() ?? "",
      data: context,
    }) as { data?: Record<string, unknown> } | Record<string, unknown>;

    if (result && typeof result === "object") {
      if ("data" in result && result.data && typeof result.data === "object" && !Array.isArray(result.data)) {
        return { ...context, ...(result.data as Record<string, unknown>) };
      }
    }

    return context;
  }

  private runNodePostExtract(node: NER, record: TreeRecord | ExtractedRecord): TreeRecord | ExtractedRecord {
    const result = this.hooks.invokeDefs("post_extract", node.hooks?.post_extract, {
      driver: this.driver,
      node: node.name,
      url: record.url,
      record,
      data: record.data,
    }) as { record?: TreeRecord | ExtractedRecord } | TreeRecord | ExtractedRecord;

    if (result && typeof result === "object" && "record" in result && result.record) {
      return result.record as TreeRecord | ExtractedRecord;
    }

    return record;
  }

  private applyAiRules(
    result: Record<string, unknown>,
    rules: Extraction[],
  ): Record<string, unknown> {
    for (const rule of rules) {
      if (!("ai" in rule)) continue;
      const { name, prompt, input, schema, categories } = rule.ai;
      const context = input ? String(result[input] ?? "") : "";
      if (categories && categories.length > 0) {
        result[name] = this.ai.classify(prompt, context, categories);
      } else {
        result[name] = this.ai.extract(prompt, context, schema);
      }
    }
    return result;
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

      this.navigateNextPage(expand.control);
    }
  }

  /**
   * Navigate to the next page by resolving the control element's href.
   * agent-browser's Playwright "real click" on <a> tags doesn't reliably
   * trigger navigation. We read the href and open() directly, falling back
   * to a scripted DOM click for non-link controls (buttons, AJAX).
   */
  private navigateNextPage(control: string): void {
    const nextHref = this.driver.evalJson<string | null>(`
      (() => { const el = document.querySelector('${escapeJs(control)}'); return el ? el.href || el.getAttribute('href') : null })()
    `);
    if (nextHref) {
      this.driver.open(nextHref, { wait: { idle: true } });
    } else {
      // Non-link control (button, etc.) — use scripted click which triggers
      // the DOM click event and any attached JS handlers
      this.driver.click({ css: control }, { type: "scripted" });
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
    let extractedCount = 0;

    for (let page = 0; page < maxIter; page++) {
      console.log(`${indent}  Scroll ${page + 1}/${maxIter}`);
      // Pass offset so child element-expansions only process newly-appeared elements
      const scrollCtx = { ...context, _extractOffset: extractedCount };
      const recordsBefore = records.length;
      this.walkChildren(node.name, allNodes, records, depth, scrollCtx);
      extractedCount += records.length - recordsBefore;
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
      // Build context with combination values so children know which combo produced them
      const comboContext: Record<string, unknown> = {};
      for (let i = 0; i < combo.length; i++) {
        const axis = resolvedAxes[i];
        const val = combo[i];
        comboContext[axis.control] = val;
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
      this.walkChildren(node.name, allNodes, records, depth, { ...context, ...comboContext });
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

    // Topological sort: respect artifact emit/consumes dependencies
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
      const base = `(container.querySelector('${escapeJs(css)}') || (container.matches && container.matches('${escapeJs(css)}') ? container : null))?.textContent?.trim() || ''`;
      if (regex) {
        return `result['${escapeJs(name)}'] = (() => { const v = ${base}; const m = v.match(new RegExp('${escapeJs(regex)}')); return m ? m[0] : v; })();`;
      }
      return `result['${escapeJs(name)}'] = ${base};`;

    } else if ("attr" in rule) {
      const css = escapeJs(rule.attr.css);
      return `result['${escapeJs(rule.attr.name)}'] = (container.querySelector('${css}') || (container.matches && container.matches('${css}') ? container : null))?.getAttribute('${escapeJs(rule.attr.attr)}') || '';`;

    } else if ("html" in rule) {
      const css = escapeJs(rule.html.css);
      return `result['${escapeJs(rule.html.name)}'] = (container.querySelector('${css}') || (container.matches && container.matches('${css}') ? container : null))?.innerHTML || '';`;

    } else if ("link" in rule) {
      const attr = escapeJs(rule.link.attr ?? "href");
      const css = escapeJs(rule.link.css);
      return `result['${escapeJs(rule.link.name)}'] = (container.querySelector('${css}') || (container.matches && container.matches('${css}') ? container : null))?.getAttribute('${attr}') || '';`;

    } else if ("image" in rule) {
      const css = escapeJs(rule.image.css);
      return `result['${escapeJs(rule.image.name)}'] = (container.querySelector('${css}') || (container.matches && container.matches('${css}') ? container : null))?.getAttribute('src') || '';`;

    } else if ("grouped" in rule) {
      const { name, css, attr } = rule.grouped;
      const read = attr
        ? `el.getAttribute('${escapeJs(attr)}')`
        : "el.textContent.trim()";
      return `result['${escapeJs(name)}'] = [...container.querySelectorAll('${escapeJs(css)}')].map(el => ${read});`;

    } else if ("table" in rule) {
      const cfg = rule.table;
      const columns = cfg.columns ?? [];
      if (columns.length > 0) {
        return `result['${escapeJs(cfg.name)}'] = (() => {
          const tbl = container.querySelector('${escapeJs(cfg.css)}') || container;
          const hdr = tbl.querySelectorAll('tr')[${cfg.header_row ?? 0}];
          const headers = [...(hdr?.querySelectorAll('th, td') || [])].map(c => c.textContent.trim());
          const colDefs = ${JSON.stringify(columns)};
          const colMap = colDefs.map(cd => {
            if (cd.header) return headers.indexOf(cd.header);
            if (cd.index !== undefined) return cd.index;
            return -1;
          });
          const dataRows = [...tbl.querySelectorAll('tr')].slice(${(cfg.header_row ?? 0) + 1});
          return dataRows.map(row => {
            const cells = [...row.querySelectorAll('td, th')];
            const obj = {};
            colDefs.forEach((cd, i) => {
              const idx = colMap[i];
              obj[cd.name] = idx >= 0 && cells[idx] ? cells[idx].textContent.trim() : '';
            });
            return obj;
          });
        })();`;
      }
      return `result['${escapeJs(cfg.name)}'] = (() => {
        const tbl = container.querySelector('${escapeJs(cfg.css)}') || container;
        const rows = [...tbl.querySelectorAll('tr')].slice(${(cfg.header_row ?? 0) + 1});
        return rows.map(row => [...row.querySelectorAll('td, th')].map(c => c.textContent.trim()));
      })();`;

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
