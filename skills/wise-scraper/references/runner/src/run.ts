#!/usr/bin/env node
/**
 * WISE NER Runner — CLI entry point.
 *
 * Reads a YAML profile, validates against the Zod schema, wires up
 * driver + AI adapter, executes via the NER engine, writes JSON + final output.
 *
 * Usage:
 *   node dist/run.js <profile.yaml> [options]
 *
 * Options:
 *   --output-dir, -o    Output directory (default: ./output)
 *   --output-format     json | jsonl | csv | markdown | md  (default: json)
 *   --hooks             Path to hooks module (.js)
 *   --ai-model          Model for aichat adapter (optional)
 *   --driver            agent-browser (default) — extensible for future drivers
 *   --set, -s           Override: --set key=value
 *   --config, -c        Extra config to merge
 *   --verbose, -v       Verbose logging
 *   --dry-run           Validate without executing
 *   --timeout           Browser timeout in ms (default: 60000)
 *   --retries           Retry count (default: 2)
 */

import { readFileSync, writeFileSync, mkdirSync, existsSync } from "fs";
import { resolve } from "path";
import yaml from "js-yaml";

import { Deployment as DeploymentSchema, type ArtifactSchema, type Deployment, type ExtractedRecord, type TreeRecord } from "./schema.js";
import { AgentBrowserDriver } from "./agent-browser-driver.js";
import { NullAIAdapter } from "./ai.js";
import { AIChatAdapter } from "./aichat-adapter.js";
import { Engine } from "./engine.js";
import { HookRegistry } from "./hooks.js";
import { ArtifactStore, dedupeByField, toArray } from "./store.js";
import { loadConfig } from "./config.js";
import { assembleMarkdown, assembleCsv } from "./processing.js";

// Re-export ExtractedRecord for processing.ts compatibility
export type { ExtractedRecord } from "./schema.js";

// ── output writers ──────────────────────────────────────

function writeJsonl(records: ExtractedRecord[], path: string): void {
  const lines = records.map((r) => JSON.stringify(r));
  writeFileSync(path, lines.join("\n") + "\n", "utf-8");
  console.log(`[output] ${records.length} records → ${path}`);
}

function writeCsv(records: ExtractedRecord[], path: string): void {
  writeFileSync(path, assembleCsv(records), "utf-8");
  console.log(`[output] ${records.length} rows → ${path}`);
}

function writeJson(records: ExtractedRecord[], path: string): void {
  writeFileSync(path, JSON.stringify(records, null, 2), "utf-8");
  console.log(`[output] ${records.length} records → ${path}`);
}

function writeMarkdown(records: ExtractedRecord[], path: string, title?: string): void {
  const md = assembleMarkdown(records, { title });
  writeFileSync(path, md, "utf-8");
  console.log(`[output] ${(md.length / 1024).toFixed(1)} KB → ${path}`);
}

type Writer = (records: ExtractedRecord[], path: string) => void;

const WRITERS: Record<string, Writer> = {
  jsonl: writeJsonl,
  csv: writeCsv,
  json: writeJson,
  markdown: writeMarkdown,
  md: writeMarkdown,
};

function countValidationFailures(records: ExtractedRecord[], schema?: ArtifactSchema): { total_records: number; failed_records: number } {
  if (!schema) {
    return { total_records: records.length, failed_records: 0 };
  }

  let failedRecords = 0;
  for (const record of records) {
    let recordFailed = false;
    for (const [fieldName, fieldDef] of Object.entries(schema.fields)) {
      const value = record.data[fieldName];
      if (fieldDef.required && (value === undefined || value === null || value === "")) {
        recordFailed = true;
        continue;
      }
      if (value !== undefined && value !== null && value !== "" && !matchesFieldType(value, fieldDef.type)) {
        recordFailed = true;
      }
    }
    if (recordFailed) failedRecords += 1;
  }

  return { total_records: records.length, failed_records: failedRecords };
}

function matchesFieldType(value: unknown, type: ArtifactSchema["fields"][string]["type"]): boolean {
  switch (type) {
    case "string":
      return typeof value === "string";
    case "number":
      return typeof value === "number" || (typeof value === "string" && !isNaN(Number(value)));
    case "boolean":
      return typeof value === "boolean";
    case "array":
      return Array.isArray(value);
    case "object":
      return typeof value === "object" && value !== null && !Array.isArray(value);
    default:
      return true;
  }
}

function dedupeFlatRecords(records: ExtractedRecord[], schema?: ArtifactSchema): ExtractedRecord[] {
  if (!schema?.dedupe) return records;
  return dedupeByField(records, schema.dedupe);
}

function getArtifactOutputRecords(
  artifactName: string,
  schema: ArtifactSchema | undefined,
  store: ArtifactStore,
): ExtractedRecord[] {
  const flatRecords = store.get(artifactName);
  if (flatRecords.length > 0) {
    return dedupeFlatRecords(flatRecords, schema);
  }

  const treeRecords = store.getTree(artifactName);
  if (treeRecords.length > 0) {
    return dedupeFlatRecords(Engine.flattenTree(treeRecords), schema);
  }

  return [];
}

function getArtifactQualitySummary(
  artifactName: string,
  schema: ArtifactSchema | undefined,
  store: ArtifactStore,
): { total_records: number; failed_records: number } {
  const storedSummary = store.getValidationSummary(artifactName);
  if (storedSummary.total_records > 0) {
    return storedSummary;
  }

  const outputRecords = getArtifactOutputRecords(artifactName, schema, store);
  if (outputRecords.length > 0) {
    return countValidationFailures(outputRecords, schema);
  }

  return { total_records: 0, failed_records: 0 };
}

function writeOutputArtifact(
  outDir: string,
  baseName: string,
  name: string,
  schema: ArtifactSchema,
  store: ArtifactStore,
  defaultFormat: string,
): void {
  const trees = store.getTree(name);
  const fmt = schema.format ?? defaultFormat;
  const ext = fmt === "markdown" ? "md" : fmt;
  const outPath = resolve(outDir, `${baseName}_${name}.${ext}`);
  const outputAsFlat = schema.structure === "flat" || fmt === "csv" || fmt === "markdown" || fmt === "jsonl";
  const records = getArtifactOutputRecords(name, schema, store);

  if (outputAsFlat) {
    if (WRITERS[fmt]) {
      WRITERS[fmt](records, outPath);
    } else {
      writeJson(records, outPath);
    }
    return;
  }

  if (trees.length > 0) {
    writeFileSync(outPath, JSON.stringify(trees, null, 2), "utf-8");
    console.log(`[output] ${trees.length} tree records → ${outPath}`);
  } else if (records.length > 0) {
    writeJson(records, outPath);
  }
}

// ── profile loading + validation ────────────────────────

function loadProfile(profilePath: string): Deployment {
  const text = readFileSync(profilePath, "utf-8");
  const raw = yaml.load(text);
  if (!raw || typeof raw !== "object") throw new Error(`Empty or invalid profile: ${profilePath}`);

  // Validate with Zod
  const result = DeploymentSchema.safeParse(raw);
  if (!result.success) {
    console.error("[validate] Profile validation failed:");
    for (const issue of result.error.issues) {
      console.error(`  ${issue.path.join(".")} — ${String(issue.message)}`);
    }
    throw new Error("Profile validation failed");
  }

  return result.data;
}

// ── semantic validation ─────────────────────────────────

function validateSemantics(profile: Deployment): void {
  const artifactNames = new Set(Object.keys(profile.artifacts ?? {}));
  const producerNames = new Set<string>();

  for (const resource of profile.resources) {
    const nodeNames = new Set(resource.nodes.map((n: { name: string }) => n.name));

    // entry.root must reference an existing node
    if (!nodeNames.has(resource.entry.root)) {
      throw new Error(
        `Resource '${resource.name}': entry.root '${resource.entry.root}' references unknown node. ` +
        `Available: ${[...nodeNames].join(", ")}`,
      );
    }

    // produces must reference declared artifacts
    for (const name of toArray(resource.produces)) {
      if (artifactNames.size > 0 && !artifactNames.has(name)) {
        throw new Error(
          `Resource '${resource.name}': produces '${name}' not declared in artifacts`,
        );
      }
      producerNames.add(name);
    }

    // consumes must reference declared artifacts
    for (const name of toArray(resource.consumes)) {
      if (artifactNames.size > 0 && !artifactNames.has(name)) {
        throw new Error(
          `Resource '${resource.name}': consumes '${name}' not declared in artifacts`,
        );
      }
    }

    for (const node of resource.nodes) {
      // parents must reference existing nodes
      for (const parent of node.parents) {
        if (!nodeNames.has(parent)) {
          throw new Error(
            `Resource '${resource.name}', node '${node.name}': ` +
            `parent '${parent}' references unknown node`,
          );
        }
      }
    }

    // Check for cycles (DFS)
    const adj: Record<string, string[]> = {};
    for (const node of resource.nodes) {
      for (const parent of node.parents) {
        if (!adj[parent]) adj[parent] = [];
        adj[parent].push(node.name);
      }
    }
    const visited = new Set<string>();
    const stack = new Set<string>();
    function dfs(name: string): void {
      if (stack.has(name)) throw new Error(`Resource '${resource.name}': cycle detected at node '${name}'`);
      if (visited.has(name)) return;
      stack.add(name);
      for (const child of adj[name] ?? []) dfs(child);
      stack.delete(name);
      visited.add(name);
    }
    for (const name of nodeNames) dfs(name);
  }
}

// ── quality gate ────────────────────────────────────────

/** Returns true if all quality checks pass, false if any fail. */
function checkQuality(
  records: ExtractedRecord[],
  profile: Deployment,
  store: ArtifactStore,
  outputArtifacts: Array<[string, ArtifactSchema]>,
): boolean {
  const q = profile.quality;
  if (!q) return true;

  let passed = true;
  const total = records.length;

  if (q.min_records && total < q.min_records) {
    console.warn(`[quality] FAIL: ${total} records < min_records ${q.min_records}`);
    passed = false;
  }

  if (q.max_empty_pct !== undefined) {
    const empty = records.filter((r) => Object.keys(r.data).length === 0).length;
    const pct = total > 0 ? (empty / total) * 100 : 0;
    if (pct > q.max_empty_pct) {
      console.warn(`[quality] FAIL: ${pct.toFixed(1)}% empty > max_empty_pct ${q.max_empty_pct}%`);
      passed = false;
    }
  }

  if (q.min_filled_pct) {
    for (const [col, threshold] of Object.entries(q.min_filled_pct)) {
      const filled = records.filter((r) => {
        const v = r.data[col];
        return v !== undefined && v !== null && v !== "";
      }).length;
      const pct = total > 0 ? (filled / total) * 100 : 0;
      if (pct < (threshold as number)) {
        console.warn(`[quality] FAIL: column '${col}' ${pct.toFixed(1)}% filled < ${threshold}%`);
        passed = false;
      }
    }
  }

  if (q.max_failed_pct !== undefined) {
    // Use stored validation telemetry when available; otherwise validate the
    // flattened output on the fly. This keeps nested tree outputs and flat
    // outputs comparable without forcing extra profile wiring.
    let failedRecords = 0;
    let validatedRecords = 0;

    if (outputArtifacts.length > 0) {
      for (const [name, schema] of outputArtifacts) {
        const summary = getArtifactQualitySummary(name, schema, store);
        failedRecords += summary.failed_records;
        validatedRecords += summary.total_records;
      }
    } else {
      validatedRecords = total;
    }

    const pct = validatedRecords > 0 ? (failedRecords / validatedRecords) * 100 : 0;
    if (pct > q.max_failed_pct) {
      console.warn(`[quality] FAIL: ${pct.toFixed(1)}% failed > max_failed_pct ${q.max_failed_pct}%`);
      passed = false;
    }
  }

  return passed;
}

// ── main ────────────────────────────────────────────────

async function main(): Promise<void> {
  const config = loadConfig(process.argv.slice(2));
  const { runner } = config;

  if (!runner.profile) {
    console.error("Usage: node dist/run.js <profile.yaml> [options]");
    process.exit(1);
  }

  const profilePath = resolve(runner.profile);
  console.log(`[main] Loading: ${profilePath}`);
  const profile = loadProfile(profilePath);
  console.log(`[main] Profile '${profile.name}' — ${profile.resources.length} resources`);

  // Semantic validation
  validateSemantics(profile);
  console.log("[main] Semantic validation passed");

  if (runner.dryRun) {
    console.log("[main] Dry run — validation passed, exiting");
    return;
  }

  // Setup output directory
  const outDir = resolve(runner.outputDir);
  if (!existsSync(outDir)) mkdirSync(outDir, { recursive: true });

  // Wire up hooks
  const hookRegistry = new HookRegistry();
  if (profile.hooks) hookRegistry.loadFromConfig(profile.hooks, "global");
  if (runner.hooks) await hookRegistry.loadFromModule(resolve(runner.hooks));

  // Wire up AI adapter
  const aiModel = (config.inputs as Record<string, unknown>)?.ai_model;
  const ai = aiModel
    ? new AIChatAdapter({ model: String(aiModel) })
    : new NullAIAdapter();

  const drivers: AgentBrowserDriver[] = [];

  try {
    // Set up artifact store with declared schemas
    const store = new ArtifactStore(profile.artifacts);

    // Resolve execution order (topological sort on produces/consumes)
    const executionOrder = ArtifactStore.resolveOrder(profile);
    const resourceMap = new Map(profile.resources.map((r) => [r.name, r]));

    if (executionOrder.length > 1) {
      console.log(`[main] Execution order: ${executionOrder.join(" → ")}`);
    }

    const allTrees: TreeRecord[] = [];

    for (const resourceName of executionOrder) {
      const resource = resourceMap.get(resourceName)!;
      console.log(`\n=== Resource: ${resource.name} ===`);

      // One driver (session) per resource
      const driver = new AgentBrowserDriver({
        session: `${profile.name}-${resource.name}`.replace(/\s+/g, "-"),
        timeoutMs: runner.timeout,
        retries: runner.retries,
      });
      drivers.push(driver);

      // Resource-level hooks
      if (resource.hooks) hookRegistry.loadFromConfig(resource.hooks, "resource");

      const engine = new Engine(driver, ai, hookRegistry, store);
      const trees = engine.runResourceTree(resource);

      // Store trees in artifact(s) if resource declares produces.
      // Skip artifacts that nodes already emit to (prevent double-write).
      const nodeEmits = new Set(resource.nodes.flatMap((n) => {
        if (!n.emit) return [];
        if (typeof n.emit === "string") return [n.emit];
        return n.emit.map((e) => e.to);
      }));
      for (const name of toArray(resource.produces)) {
        if (nodeEmits.has(name)) {
          console.log(`[main] Skipping resource-level store for '${name}' (nodes already emit)`);
        } else {
          store.putTree(name, trees);
        }
      }

      allTrees.push(...trees);
      console.log(`[engine] '${resource.name}' → ${trees.length} tree records`);
    }

    const baseName = profile.name.replace(/\s+/g, "_").toLowerCase();

    // Write output artifacts (those marked output: true)
    const artifacts = profile.artifacts ?? {};
    const outputArtifacts = Object.entries(artifacts).filter(([, a]) => a.output);

    if (outputArtifacts.length > 0) {
      for (const [name, schema] of outputArtifacts) {
        writeOutputArtifact(outDir, baseName, name, schema, store, runner.outputFormat ?? "json");
      }
    }

    // Always write all trees as JSON (the complete intermediate truth)
    const allFlat = Engine.flattenTree(allTrees);

    // pre_assemble hook (operates on flat records for backward compat)
    let ctx = { records: allFlat, profile };
    ctx = hookRegistry.invoke("pre_assemble", ctx);
    const finalRecords = ctx.records;

    const fmt = runner.outputFormat ?? "json";
    const ext = fmt === "markdown" ? "md" : fmt;
    const allPath = resolve(outDir, `${baseName}.${ext}`);
    const writer = WRITERS[fmt] ?? writeJson;
    writer(finalRecords, allPath);

    // post_assemble hook
    hookRegistry.invoke("post_assemble", {
      records: finalRecords,
      outputDir: outDir,
      profile,
    });

    // Quality gate — check flat records from output artifacts
    let qualityRecords = finalRecords;
    if (outputArtifacts.length > 0) {
      qualityRecords = outputArtifacts.flatMap(([name, schema]) => getArtifactOutputRecords(name, schema, store));
    }
    const qualityOk = checkQuality(qualityRecords, profile, store, outputArtifacts);

    console.log(`\n=== Done: ${allTrees.length} tree records (${qualityRecords.length} flat in output artifacts) ===`);
    if (!qualityOk) {
      console.error("[main] Quality gate failed");
      process.exitCode = 1;
    }
  } finally {
    for (const d of drivers) d.close();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
