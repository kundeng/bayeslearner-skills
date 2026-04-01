/**
 * ArtifactStore — in-memory store for inter-resource data flow.
 *
 * Each resource produces records into a named artifact and can consume
 * records from an upstream artifact. The store validates records against
 * declared artifact schemas and manages the dependency DAG.
 *
 * No external dependencies — just a Map<string, Record[]>.
 */

import type { ArtifactSchema, FieldDef, ExtractedRecord, Deployment } from "./schema.js";

export interface ValidationError {
  artifact: string;
  record_index: number;
  field: string;
  message: string;
}

export class ArtifactStore {
  private store = new Map<string, ExtractedRecord[]>();
  private schemas: Record<string, ArtifactSchema>;

  constructor(schemas?: Record<string, ArtifactSchema>) {
    this.schemas = schemas ?? {};
  }

  // ── write ─────────────────────────────────────────────

  /** Store records for an artifact. Validates against schema if declared. */
  put(artifactName: string, records: ExtractedRecord[]): ValidationError[] {
    const existing = this.store.get(artifactName) ?? [];
    const errors: ValidationError[] = [];

    const schema = this.schemas[artifactName];
    if (schema) {
      for (let i = 0; i < records.length; i++) {
        const errs = this.validateRecord(artifactName, records[i], schema, existing.length + i);
        errors.push(...errs);
      }
    }

    this.store.set(artifactName, [...existing, ...records]);

    if (errors.length > 0) {
      console.warn(`[store] ${artifactName}: ${errors.length} validation errors in ${records.length} records`);
      for (const e of errors.slice(0, 5)) {
        console.warn(`  [${e.record_index}] ${e.field}: ${e.message}`);
      }
      if (errors.length > 5) console.warn(`  ... and ${errors.length - 5} more`);
    } else if (records.length > 0) {
      console.log(`[store] ${artifactName}: ${records.length} records stored (${existing.length + records.length} total)`);
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
      if (r.produces) artifactProducer.set(r.produces, r.name);
    }

    // Build adjacency: resource A must run before resource B
    const adj = new Map<string, string[]>();
    const inDeg = new Map<string, number>();
    for (const r of resources) {
      if (!adj.has(r.name)) adj.set(r.name, []);
      if (!inDeg.has(r.name)) inDeg.set(r.name, 0);
    }

    for (const r of resources) {
      // Direct consumes on resource
      if (r.consumes) {
        const producer = artifactProducer.get(r.consumes);
        if (producer && producer !== r.name) {
          adj.get(producer)!.push(r.name);
          inDeg.set(r.name, (inDeg.get(r.name) ?? 0) + 1);
        }
      }
      // Artifact-level consumes
      if (r.produces && artifacts[r.produces]?.consumes) {
        const upstreamArtifact = artifacts[r.produces].consumes!;
        const producer = artifactProducer.get(upstreamArtifact);
        if (producer && producer !== r.name) {
          adj.get(producer)!.push(r.name);
          inDeg.set(r.name, (inDeg.get(r.name) ?? 0) + 1);
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
   * Topological sort of nodes within a resource based on yields/consumes.
   * Nodes without artifact dependencies keep their YAML order relative to
   * each other but come before any node that consumes an artifact they don't yield.
   *
   * Returns node names in execution order.
   */
  static resolveNodeOrder(nodes: Array<{ name: string; yields?: string; consumes?: string; parents: string[] }>): string[] {
    // Build yields → consumes edges
    const yielder = new Map<string, string>(); // artifact → node name
    for (const n of nodes) {
      if (n.yields) yielder.set(n.yields, n.name);
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

    // artifact edges: yielder must run before consumer
    for (const n of nodes) {
      if (n.consumes) {
        const producer = yielder.get(n.consumes);
        if (producer && producer !== n.name) {
          // Only add if not already an edge (e.g. already a parent)
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

  private typeMatches(val: unknown, def: FieldDef): boolean {
    switch (def.type) {
      case "string": return typeof val === "string";
      case "number": return typeof val === "number" || (typeof val === "string" && !isNaN(Number(val)));
      case "boolean": return typeof val === "boolean";
      case "array": return Array.isArray(val);
      case "object": return typeof val === "object" && !Array.isArray(val);
      default: return true;
    }
  }
}
