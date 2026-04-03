/**
 * ArtifactStore — in-memory store for inter-resource data flow.
 *
 * Each resource produces records into a named artifact and can consume
 * records from an upstream artifact. The store validates records against
 * declared artifact schemas and manages the dependency DAG.
 *
 * No external dependencies — just a Map<string, Record[]>.
 */

import type { ArtifactSchema, FieldDef, ExtractedRecord, TreeRecord, Deployment } from "./schema.js";

/** Normalize string | string[] | undefined → string[] */
export function toArray(val: string | string[] | undefined): string[] {
  if (!val) return [];
  return Array.isArray(val) ? val : [val];
}

/** Extract artifact names from an emit declaration. */
export function emitTargetNames(emit: string | Array<{ to: string }> | undefined): string[] {
  if (!emit) return [];
  if (typeof emit === "string") return [emit];
  return emit.map((e) => e.to);
}

/** Deduplicate records by a named field. Records with missing/empty values are always kept. */
export function dedupeByField(records: ExtractedRecord[], fieldName: string): ExtractedRecord[] {
  const seen = new Set<string>();
  const deduped: ExtractedRecord[] = [];

  for (const record of records) {
    const value = record.data[fieldName];
    if (value === undefined || value === null || value === "") {
      deduped.push(record);
      continue;
    }

    const key = `${typeof value}:${JSON.stringify(value) ?? String(value)}`;
    if (seen.has(key)) continue;
    seen.add(key);
    deduped.push(record);
  }

  return deduped;
}

export interface ValidationError {
  artifact: string;
  record_index: number;
  field: string;
  message: string;
}

export interface ValidationSummary {
  total_records: number;
  failed_records: number;
}

export class ArtifactStore {
  private store = new Map<string, ExtractedRecord[]>();
  private treeStore = new Map<string, TreeRecord[]>();
  private validationSummary = new Map<string, ValidationSummary>();
  private schemas: Record<string, ArtifactSchema>;

  constructor(schemas?: Record<string, ArtifactSchema>) {
    this.schemas = schemas ?? {};
  }

  // ── write ─────────────────────────────────────────────

  /** Store tree records for an artifact (nested structure). */
  putTree(artifactName: string, trees: TreeRecord[]): void {
    const existing = this.treeStore.get(artifactName) ?? [];
    this.treeStore.set(artifactName, [...existing, ...trees]);
    console.log(`[store] ${artifactName}: ${trees.length} tree records stored (${existing.length + trees.length} total)`);
  }

  /** Get tree records for an artifact. */
  getTree(artifactName: string): TreeRecord[] {
    return this.treeStore.get(artifactName) ?? [];
  }

  /** Get a resource's raw trees (keyed by resource name for {from:} resolution). */
  getResourceTree(resourceName: string): TreeRecord[] {
    return this.treeStore.get(`__res:${resourceName}`) ?? [];
  }

  /** Store a resource's raw trees (keyed by resource name for {from:} resolution). */
  putResourceTree(resourceName: string, trees: TreeRecord[]): void {
    this.treeStore.set(`__res:${resourceName}`, trees);
  }

  /**
   * Resolve a {from: "resource.node.field"} reference.
   * Returns an array of field values extracted from matching tree nodes.
   */
  resolveFrom(ref: string): string[] {
    const parts = ref.split(".");
    if (parts.length !== 3) {
      console.warn(`[store] Invalid {from:} reference '${ref}' — expected resource.node.field`);
      return [];
    }
    const [resourceName, nodeName, fieldName] = parts;
    const trees = this.treeStore.get(`__res:${resourceName}`) ?? [];
    const values: string[] = [];
    const collect = (tree: TreeRecord): void => {
      if (tree.node === nodeName) {
        const val = tree.data[fieldName];
        if (val !== undefined && val !== null) values.push(String(val));
      }
      for (const children of Object.values(tree.children)) {
        for (const child of children) collect(child);
      }
    };
    for (const tree of trees) collect(tree);
    return values;
  }

  /** Store flat records for an artifact. Validates against schema if declared. */
  put(artifactName: string, records: ExtractedRecord[]): ValidationError[] {
    const existing = this.store.get(artifactName) ?? [];
    const schema = this.schemas[artifactName];
    const merged = schema?.dedupe
      ? this.dedupeRecords([...existing, ...records], schema.dedupe)
      : [...existing, ...records];
    const appended = merged.slice(existing.length);
    const errors: ValidationError[] = [];
    const failedRecords = new Set<number>();

    if (schema) {
      for (let i = 0; i < appended.length; i++) {
        const errs = this.validateRecord(artifactName, appended[i], schema, existing.length + i);
        if (errs.length > 0) {
          failedRecords.add(existing.length + i);
          errors.push(...errs);
        }
      }
    }

    this.store.set(artifactName, merged);
    const previousSummary = this.validationSummary.get(artifactName) ?? { total_records: 0, failed_records: 0 };
    this.validationSummary.set(artifactName, {
      total_records: previousSummary.total_records + appended.length,
      failed_records: previousSummary.failed_records + failedRecords.size,
    });

    if (errors.length > 0) {
      console.warn(`[store] ${artifactName}: ${errors.length} validation errors in ${appended.length} records`);
      for (const e of errors.slice(0, 5)) {
        console.warn(`  [${e.record_index}] ${e.field}: ${e.message}`);
      }
      if (errors.length > 5) console.warn(`  ... and ${errors.length - 5} more`);
    } else if (appended.length > 0) {
      console.log(`[store] ${artifactName}: ${appended.length} records stored (${merged.length} total)`);
    }

    return errors;
  }

  // ── read ──────────────────────────────────────────────

  /** Get all records for an artifact. */
  get(artifactName: string): ExtractedRecord[] {
    return this.store.get(artifactName) ?? [];
  }

  /** Check if an artifact has any records. */
  has(artifactName: string): boolean {
    return (this.store.get(artifactName)?.length ?? 0) > 0;
  }

  /** Summarize validation results for an artifact. */
  getValidationSummary(artifactName: string): ValidationSummary {
    return this.validationSummary.get(artifactName) ?? { total_records: 0, failed_records: 0 };
  }

  // ── dependency resolution ─────────────────────────────

  /**
   * Topological sort of resources based on produces/consumes + artifact.consumes.
   * Returns resource names in execution order.
   */
  static resolveOrder(profile: Deployment): string[] {
    const resources = profile.resources;
    const artifacts = profile.artifacts ?? {};
    const nameToIdx = new Map<string, number>();
    resources.forEach((r, i) => nameToIdx.set(r.name, i));

    // Build artifact → producer resource mapping
    const artifactProducer = new Map<string, string>();
    for (const r of resources) {
      for (const name of toArray(r.produces)) {
        artifactProducer.set(name, r.name);
      }
    }

    // Build adjacency: resource A must run before resource B
    const adj = new Map<string, string[]>();
    const inDeg = new Map<string, number>();
    for (const r of resources) {
      if (!adj.has(r.name)) adj.set(r.name, []);
      if (!inDeg.has(r.name)) inDeg.set(r.name, 0);
    }

    const addEdge = (from: string, to: string) => {
      if (from === to) return;
      const existing = adj.get(from) ?? [];
      if (!existing.includes(to)) {
        existing.push(to);
        adj.set(from, existing);
        inDeg.set(to, (inDeg.get(to) ?? 0) + 1);
      }
    };

    for (const r of resources) {
      // Direct consumes on resource → must run after producer
      for (const consumed of toArray(r.consumes)) {
        const producer = artifactProducer.get(consumed);
        if (producer) addEdge(producer, r.name);
      }
      // Artifact-level consumes
      for (const produced of toArray(r.produces)) {
        for (const upstream of toArray(artifacts[produced]?.consumes)) {
          const producer = artifactProducer.get(upstream);
          if (producer) addEdge(producer, r.name);
        }
      }
    }

    // Kahn's algorithm
    const queue: string[] = [];
    for (const [name, deg] of inDeg) {
      if (deg === 0) queue.push(name);
    }

    const order: string[] = [];
    while (queue.length > 0) {
      const name = queue.shift()!;
      order.push(name);
      for (const next of adj.get(name) ?? []) {
        const newDeg = (inDeg.get(next) ?? 1) - 1;
        inDeg.set(next, newDeg);
        if (newDeg === 0) queue.push(next);
      }
    }

    if (order.length !== resources.length) {
      const missing = resources.map((r) => r.name).filter((n) => !order.includes(n));
      throw new Error(`Cycle detected in resource dependencies: ${missing.join(", ")}`);
    }

    return order;
  }

  /**
   * Topological sort of nodes within a resource based on emit/consumes.
   * Nodes without artifact dependencies keep their YAML order relative to
   * each other but come before any node that consumes an artifact they don't emit.
   *
   * Returns node names in execution order.
   */
  static resolveNodeOrder(nodes: Array<{ name: string; emit?: string | Array<{ to: string }>; consumes?: string | string[]; parents: string[] }>): string[] {
    // Build emit target → node name edges
    const emitter = new Map<string, string>(); // artifact → node name
    for (const n of nodes) {
      const targets = emitTargetNames(n.emit);
      for (const t of targets) emitter.set(t, n.name);
    }

    const adj = new Map<string, string[]>();
    const inDeg = new Map<string, number>();
    for (const n of nodes) {
      if (!adj.has(n.name)) adj.set(n.name, []);
      if (!inDeg.has(n.name)) inDeg.set(n.name, 0);
    }

    // parent edges (existing DAG)
    for (const n of nodes) {
      for (const parent of n.parents) {
        if (adj.has(parent)) {
          adj.get(parent)!.push(n.name);
          inDeg.set(n.name, (inDeg.get(n.name) ?? 0) + 1);
        }
      }
    }

    // artifact edges: emitter must run before consumer
    for (const n of nodes) {
      for (const consumed of toArray(n.consumes)) {
        const producer = emitter.get(consumed);
        if (producer && producer !== n.name) {
          const existing = adj.get(producer) ?? [];
          if (!existing.includes(n.name)) {
            existing.push(n.name);
            adj.set(producer, existing);
            inDeg.set(n.name, (inDeg.get(n.name) ?? 0) + 1);
          }
        }
      }
    }

    // Kahn's — stable: preserve YAML order for ties
    const queue: string[] = [];
    for (const n of nodes) {
      if ((inDeg.get(n.name) ?? 0) === 0) queue.push(n.name);
    }

    const order: string[] = [];
    while (queue.length > 0) {
      const name = queue.shift()!;
      order.push(name);
      for (const next of adj.get(name) ?? []) {
        const newDeg = (inDeg.get(next) ?? 1) - 1;
        inDeg.set(next, newDeg);
        if (newDeg === 0) queue.push(next);
      }
    }

    if (order.length !== nodes.length) {
      const missing = nodes.map((n) => n.name).filter((n) => !order.includes(n));
      throw new Error(`Cycle detected in node dependencies: ${missing.join(", ")}`);
    }

    return order;
  }

  // ── validation ────────────────────────────────────────

  private validateRecord(
    artifactName: string,
    record: ExtractedRecord,
    schema: ArtifactSchema,
    index: number,
  ): ValidationError[] {
    const errors: ValidationError[] = [];
    const data = record.data;

    for (const [fieldName, fieldDef] of Object.entries(schema.fields)) {
      const val = data[fieldName];

      // Required check
      if (fieldDef.required && (val === undefined || val === null || val === "")) {
        errors.push({
          artifact: artifactName,
          record_index: index,
          field: fieldName,
          message: "required but missing or empty",
        });
        continue;
      }

      // Type check (if value present)
      if (val !== undefined && val !== null && val !== "") {
        if (!this.typeMatches(val, fieldDef)) {
          errors.push({
            artifact: artifactName,
            record_index: index,
            field: fieldName,
            message: `expected ${fieldDef.type}, got ${typeof val}`,
          });
        }
      }
    }

    return errors;
  }

  private dedupeRecords(records: ExtractedRecord[], fieldName: string): ExtractedRecord[] {
    return dedupeByField(records, fieldName);
  }

  private typeMatches(val: unknown, def: FieldDef): boolean {
    switch (def.type) {
      case "string": return typeof val === "string";
      case "number": return typeof val === "number" || (typeof val === "string" && !isNaN(Number(val)));
      case "boolean": return typeof val === "boolean";
      case "array": return Array.isArray(val);
      case "object": return typeof val === "object" && val !== null && !Array.isArray(val);
      default: return true;
    }
  }
}
