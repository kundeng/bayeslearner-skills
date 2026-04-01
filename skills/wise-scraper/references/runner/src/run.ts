#!/usr/bin/env node
/**
 * WISE NER Runner — CLI entry point.
 *
 * Reads a YAML profile, validates against the Zod schema, wires up
 * driver + AI adapter, executes via the NER engine, writes JSONL + final output.
 *
 * Usage:
 *   node dist/run.js <profile.yaml> [options]
 *
 * Options:
 *   --output-dir, -o    Output directory (default: ./output)
 *   --output-format     jsonl | csv | json | markdown | md
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

import { Deployment as DeploymentSchema, type Deployment, type ExtractedRecord } from "./schema.js";
import { AgentBrowserDriver } from "./agent-browser-driver.js";
import { NullAIAdapter } from "./ai.js";
import { AIChatAdapter } from "./aichat-adapter.js";
import { Engine } from "./engine.js";
import { HookRegistry } from "./hooks.js";
import { ArtifactStore } from "./store.js";
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

    // produces must reference a declared artifact
    if (resource.produces) {
      if (artifactNames.size > 0 && !artifactNames.has(resource.produces)) {
        throw new Error(
          `Resource '${resource.name}': produces '${resource.produces}' not declared in artifacts`,
        );
      }
      producerNames.add(resource.produces);
    }

    // consumes must reference a declared artifact that some resource produces
    if (resource.consumes && artifactNames.size > 0 && !artifactNames.has(resource.consumes)) {
      throw new Error(
        `Resource '${resource.name}': consumes '${resource.consumes}' not declared in artifacts`,
      );
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
function checkQuality(records: ExtractedRecord[], profile: Deployment): boolean {
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
  if (profile.hooks) hookRegistry.loadFromConfig(profile.hooks);
  if (runner.hooks) await hookRegistry.loadFromModule(resolve(runner.hooks));

  // Wire up driver
  const driver = new AgentBrowserDriver({
    timeoutMs: runner.timeout,
    retries: runner.retries,
  });

  // Wire up AI adapter
  const aiModel = (config.inputs as Record<string, unknown>)?.ai_model;
  const ai = aiModel
    ? new AIChatAdapter({ model: String(aiModel) })
    : new NullAIAdapter();

  try {
    // Set up artifact store with declared schemas
    const store = new ArtifactStore(profile.artifacts);

    // Resolve execution order (topological sort on produces/consumes)
    const executionOrder = ArtifactStore.resolveOrder(profile);
    const resourceMap = new Map(profile.resources.map((r) => [r.name, r]));

    if (executionOrder.length > 1) {
      console.log(`[main] Execution order: ${executionOrder.join(" → ")}`);
    }

    const allRecords: ExtractedRecord[] = [];

    for (const resourceName of executionOrder) {
      const resource = resourceMap.get(resourceName)!;
      console.log(`\n=== Resource: ${resource.name} ===`);

      // Resource-level hooks
      if (resource.hooks) hookRegistry.loadFromConfig(resource.hooks);

      const engine = new Engine(driver, ai, hookRegistry, store);
      const records = engine.runResource(resource);

      // Store records in artifact if resource declares produces
      if (resource.produces) {
        store.put(resource.produces, records);
      }

      allRecords.push(...records);
      console.log(`[engine] '${resource.name}' → ${records.length} records`);
    }

    // pre_assemble hook
    let ctx = { records: allRecords, profile };
    ctx = hookRegistry.invoke("pre_assemble", ctx);
    const finalRecords = ctx.records;

    // Always write JSONL
    const baseName = profile.name.replace(/\s+/g, "_").toLowerCase();
    const jsonlPath = resolve(outDir, `${baseName}.jsonl`);
    writeJsonl(finalRecords, jsonlPath);

    // Write in requested format if different
    const fmt = runner.outputFormat ?? "jsonl";
    if (fmt !== "jsonl" && WRITERS[fmt]) {
      const ext = fmt === "markdown" ? "md" : fmt;
      const outPath = resolve(outDir, `${baseName}.${ext}`);
      WRITERS[fmt](finalRecords, outPath);
    }

    // post_assemble hook
    hookRegistry.invoke("post_assemble", {
      records: finalRecords,
      outputDir: outDir,
      profile,
    });

    // Quality gate
    const qualityOk = checkQuality(finalRecords, profile);

    console.log(`\n=== Done: ${finalRecords.length} records ===`);
    if (!qualityOk) {
      console.error("[main] Quality gate failed");
      process.exitCode = 1;
    }
  } finally {
    driver.close();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
