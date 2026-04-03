/**
 * WISE Scraper Test Harness — Agent SDK-based test runner.
 *
 * Spawns Claude subagents to explore sites, produce profiles, validate them,
 * and optionally run them live. Each test profile contains an @agent-prompt
 * in its YAML header that drives the exploration.
 *
 * Usage:
 *   npx tsx run-tests.ts                              # validate all profiles
 *   npx tsx run-tests.ts --mode explore               # explore + validate all
 *   npx tsx run-tests.ts --mode run quotes-test.yaml   # run specific profile live
 *   npx tsx run-tests.ts --mode explore --filter splunk # explore matching profiles
 */

import { query } from "@anthropic-ai/claude-agent-sdk";
import { readFileSync, readdirSync, existsSync, writeFileSync } from "fs";
import { resolve, basename, dirname } from "path";
import { execSync } from "child_process";

// ── paths ──────────────────────────────────────────────

const HARNESS_DIR = dirname(new URL(import.meta.url).pathname);
const TESTS_DIR = resolve(HARNESS_DIR, "..");
const SKILL_DIR = resolve(TESTS_DIR, "..");
const RUNNER_DIR = resolve(SKILL_DIR, "references/runner");
const PROFILES_DIR = resolve(TESTS_DIR, "profiles");
const OUTPUT_DIR = resolve(TESTS_DIR, "output");
const AGENT_OUTPUT_DIR = resolve(OUTPUT_DIR, "agent-explore");

// ── types ──────────────────────────────────────────────

interface TestMeta {
  file: string;
  name: string;
  prompt: string;
  expectedFields: string;
  minRecords: number;
  category: "practice" | "production";
}

type Mode = "validate" | "explore" | "run";

// ── parse test metadata from YAML header ───────────────

function parseMeta(filePath: string, category: "practice" | "production"): TestMeta | null {
  const content = readFileSync(filePath, "utf-8");
  const promptMatch = content.match(/^# @agent-prompt:\s*(.+)/m);
  if (!promptMatch) return null;

  const fieldsMatch = content.match(/^# @expected-fields:\s*(.+)/m);
  const minMatch = content.match(/^# @min-records:\s*(\d+)/m);

  return {
    file: filePath,
    name: basename(filePath, ".yaml"),
    prompt: promptMatch[1].trim(),
    expectedFields: fieldsMatch?.[1]?.trim() ?? "",
    minRecords: parseInt(minMatch?.[1] ?? "10", 10),
    category,
  };
}

// ── discover all test profiles ─────────────────────────

function discoverTests(filter?: string): TestMeta[] {
  const tests: TestMeta[] = [];

  for (const category of ["practice", "production"] as const) {
    const dir = resolve(PROFILES_DIR, category);
    if (!existsSync(dir)) continue;
    for (const file of readdirSync(dir).filter((f) => f.endsWith(".yaml"))) {
      const meta = parseMeta(resolve(dir, file), category);
      if (meta && (!filter || meta.name.includes(filter) || meta.prompt.includes(filter))) {
        tests.push(meta);
      }
    }
  }

  return tests;
}

// ── validate profile with Zod dry-run ──────────────────

function validateProfile(profilePath: string): { ok: boolean; output: string } {
  try {
    const output = execSync(
      `node dist/run.js "${profilePath}" --dry-run`,
      { cwd: RUNNER_DIR, encoding: "utf-8", timeout: 30000, stdio: ["pipe", "pipe", "pipe"] },
    );
    return { ok: output.includes("validation passed"), output };
  } catch (e) {
    const err = e as { stderr?: string; stdout?: string };
    return { ok: false, output: (err.stderr ?? err.stdout ?? String(e)).trim() };
  }
}

// ── run profile live ───────────────────────────────────

function runProfile(profilePath: string): { ok: boolean; output: string } {
  try {
    const output = execSync(
      `node dist/run.js "${profilePath}" --output-dir "${OUTPUT_DIR}"`,
      { cwd: RUNNER_DIR, encoding: "utf-8", timeout: 600000, stdio: ["pipe", "pipe", "pipe"] },
    );
    const hasOutput = output.includes("[output]");
    return { ok: hasOutput, output: output.split("\n").slice(-15).join("\n") };
  } catch (e) {
    const err = e as { stderr?: string; stdout?: string };
    return { ok: false, output: (err.stderr ?? err.stdout ?? String(e)).trim().split("\n").slice(-10).join("\n") };
  }
}

// ── spawn exploration subagent ─────────────────────────

async function exploreAndProduce(meta: TestMeta): Promise<{ ok: boolean; profilePath: string; log: string }> {
  const profilePath = resolve(AGENT_OUTPUT_DIR, `${meta.name}-agent-profile.yaml`);
  const logParts: string[] = [];

  const prompt = `You are a web scraping agent using the WISE Scraper skill.

Your task: ${meta.prompt}

Instructions:
1. Read ${SKILL_DIR}/SKILL.md to understand the WISE profile format
2. Read ${SKILL_DIR}/references/field-guide.md for extraction types and expand patterns
3. Use agent-browser to explore the target site — test selectors, verify DOM structure
4. Produce a complete YAML profile that the WISE runner can execute

Output requirements:
- Write ONLY the YAML profile content to: ${profilePath}
- The profile must include: name, artifacts (with output: true), resources, quality gates
- Use artifact fields matching: ${meta.expectedFields}
- Set quality.min_records to at least ${meta.minRecords}
- Include both nested and flat output artifacts (dual output)
- The root node must have parents: []

Do NOT explain your work. Explore, then write the profile.`;

  try {
    for await (const message of query({
      prompt,
      options: {
        allowedTools: ["Bash", "Read", "Write", "Glob", "Grep"],
        permissionMode: "bypassPermissions",
        maxBudgetUsd: 2.0,
        cwd: SKILL_DIR,
      },
    })) {
      if (message.type === "assistant" && message.message?.content) {
        for (const block of message.message.content) {
          if ("text" in block) logParts.push(block.text);
        }
      }
    }
  } catch (e) {
    logParts.push(`Agent error: ${String(e)}`);
  }

  const log = logParts.join("\n");
  writeFileSync(resolve(AGENT_OUTPUT_DIR, `${meta.name}-agent-log.txt`), log, "utf-8");

  return { ok: existsSync(profilePath), profilePath, log };
}

// ── main ───────────────────────────────────────────────

async function main() {
  const args = process.argv.slice(2);
  let mode: Mode = "validate";
  let filter: string | undefined;
  const specific: string[] = [];

  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--mode" && args[i + 1]) {
      mode = args[++i] as Mode;
    } else if (args[i] === "--filter" && args[i + 1]) {
      filter = args[++i];
    } else if (args[i].endsWith(".yaml")) {
      specific.push(args[i]);
    }
  }

  const tests = specific.length > 0
    ? specific.map((f) => {
        // Try to find the file in profiles/
        for (const cat of ["practice", "production"] as const) {
          const path = resolve(PROFILES_DIR, cat, f);
          if (existsSync(path)) return parseMeta(path, cat);
        }
        // Try as absolute or relative path
        if (existsSync(f)) return parseMeta(resolve(f), "practice");
        return null;
      }).filter((t): t is TestMeta => t !== null)
    : discoverTests(filter);

  if (tests.length === 0) {
    console.log("No tests found. Check profiles/ directory or --filter.");
    process.exit(1);
  }

  console.log(`\n=== WISE Scraper Test Harness ===`);
  console.log(`Mode: ${mode} | Tests: ${tests.length}\n`);

  const results: Array<{ name: string; validate: boolean; explore?: boolean; run?: boolean; notes: string }> = [];

  for (const test of tests) {
    console.log(`── ${test.name} (${test.category}) ──`);

    let profilePath = test.file;
    let exploreOk: boolean | undefined;

    // Step 1: Explore (if requested)
    if (mode === "explore") {
      console.log(`  [explore] Spawning agent...`);
      const result = await exploreAndProduce(test);
      exploreOk = result.ok;
      if (result.ok) {
        profilePath = result.profilePath;
        console.log(`  [explore] Profile produced: ${basename(result.profilePath)}`);
      } else {
        console.log(`  [explore] FAILED — agent did not produce a profile`);
        results.push({ name: test.name, validate: false, explore: false, notes: "Agent failed" });
        continue;
      }
    }

    // Step 2: Validate
    console.log(`  [validate] ${basename(profilePath)}...`);
    const v = validateProfile(profilePath);
    console.log(`  [validate] ${v.ok ? "PASS" : "FAIL"}`);
    if (!v.ok) {
      console.log(`    ${v.output.split("\n").slice(-3).join("\n    ")}`);
      results.push({ name: test.name, validate: false, explore: exploreOk, notes: v.output.split("\n").pop() ?? "" });
      continue;
    }

    // Step 3: Run (if requested)
    let runOk: boolean | undefined;
    if (mode === "run") {
      console.log(`  [run] Executing live...`);
      const r = runProfile(profilePath);
      runOk = r.ok;
      console.log(`  [run] ${r.ok ? "PASS" : "FAIL"}`);
      if (!r.ok) console.log(`    ${r.output.split("\n").slice(-3).join("\n    ")}`);
    }

    results.push({
      name: test.name,
      validate: v.ok,
      explore: exploreOk,
      run: runOk,
      notes: runOk === false ? "Live run failed" : "",
    });
  }

  // Summary table
  console.log(`\n=== Results ===\n`);
  console.log(`${"Test".padEnd(35)} ${"Validate".padEnd(10)} ${"Explore".padEnd(10)} ${"Run".padEnd(10)} Notes`);
  console.log("-".repeat(80));
  for (const r of results) {
    const v = r.validate ? "PASS" : "FAIL";
    const e = r.explore === undefined ? "—" : r.explore ? "PASS" : "FAIL";
    const run = r.run === undefined ? "—" : r.run ? "PASS" : "FAIL";
    console.log(`${r.name.padEnd(35)} ${v.padEnd(10)} ${e.padEnd(10)} ${run.padEnd(10)} ${r.notes}`);
  }

  const failed = results.filter((r) => !r.validate || r.run === false);
  if (failed.length > 0) {
    console.log(`\n${failed.length} test(s) failed.`);
    process.exit(1);
  }
  console.log(`\nAll ${results.length} tests passed.`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
