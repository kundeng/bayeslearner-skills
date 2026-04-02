/**
 * WISE NER Schema — single source of truth.
 *
 * Defines the Navigation/Extraction Rule (NER) graph model where each node
 * is a (state, action) → observation triple with deterministic transitions.
 *
 * Uses Zod for: runtime validation, TypeScript type inference, JSON Schema export.
 * No CUE, no AJV, no generation pipeline.
 */

import { z } from "zod";

// ── primitives ──────────────────────────────────────────

export const Locator = z
  .object({
    css: z.string().optional(),
    text: z.string().optional(),
    role: z.string().optional(),
    name: z.string().optional(),
  })
  .refine((l) => l.css || l.text || l.role, "locator needs at least css, text, or role");

export const WaitCondition = z.union([
  z.object({ idle: z.literal(true) }),
  z.object({ selector: z.string() }),
  z.object({ ms: z.number().int().positive() }),
]);

// ── stop condition (observable completion strategies) ────
// Used by: scroll-to (ready), infinite pagination (done), any
// action that needs to wait for the page to reach a state.
//
// Three strategies, composable — first one that triggers wins:
//   sentinel:  a CSS selector appears (or disappears)
//   stable:    a measured quantity stops changing
//   limit:     hard cap (safety net, always present)

export const StopCondition = z.object({
  sentinel: z.string().optional(),                     // CSS — stop when this appears
  sentinel_gone: z.string().optional(),                // CSS — stop when this disappears
  stable: z                                            // stop when element count stops changing
    .object({
      css: z.string(),                                 // count elements matching this
      after: z.number().int().positive().default(2),   // N consecutive unchanged checks
    })
    .optional(),
  limit: z.number().int().positive().default(50),      // hard max iterations (safety net)
});

// ── actions (browser primitives) ────────────────────────

export const ClickAction = z.object({
  click: Locator,
  type: z.enum(["real", "scripted"]).default("real"),
  uniqueness: z.enum(["text", "html", "css", "dom"]).optional(),
  discard: z.enum(["never", "when-control-exists", "always"]).default("never"),
  delay_ms: z.number().int().nonnegative().optional(),
});

export const SelectAction = z.object({
  select: Locator,
  value: z.string(),
  delay_ms: z.number().int().nonnegative().optional(),
});

export const ScrollAction = z.object({
  scroll: z.enum(["down", "up", "to"]),
  px: z.number().int().positive().default(500),        // for down/up: step size
  target: Locator.optional(),                           // for "to": scroll until visible
  ready: WaitCondition.optional(),                      // for "to": wait after target visible
  delay_ms: z.number().int().nonnegative().optional(),
});

export const WaitAction = z.object({ wait: WaitCondition });

export const RevealAction = z.object({
  reveal: Locator,
  mode: z.enum(["click", "hover"]).default("click"),
  delay_ms: z.number().int().nonnegative().optional(),
});

export const NavigateAction = z.object({
  navigate: z.object({ to: z.string() }), // literal URL or "{field_ref}"
});

export const InputAction = z.object({
  input: z.object({
    target: Locator,
    value: z.string(),
  }),
  delay_ms: z.number().int().nonnegative().optional(),
});

export const Action = z.union([
  ClickAction,
  SelectAction,
  ScrollAction,
  WaitAction,
  RevealAction,
  NavigateAction,
  InputAction,
]);

// ── state (preconditions — "am I where I expect?") ──────

export const State = z
  .object({
    url: z.string().optional(),
    url_pattern: z.string().optional().describe("Substring match against current URL (not regex)"),
    selector_exists: z.string().optional(),
    text_in_page: z.string().optional(),
    table_headers: z.array(z.string()).optional(),
  })
  .describe("All conditions AND'd. Empty = always true.");

// ── extraction (observation — "what do I read?") ────────

export const TextExtract = z.object({
  text: z.object({
    name: z.string(),
    css: z.string(),
    regex: z.string().optional(),
  }),
});

export const AttrExtract = z.object({
  attr: z.object({
    name: z.string(),
    css: z.string(),
    attr: z.string(),
  }),
});

export const HtmlExtract = z.object({
  html: z.object({
    name: z.string(),
    css: z.string(),
  }),
});

export const LinkExtract = z.object({
  link: z.object({
    name: z.string(),
    css: z.string(),
    attr: z.string().default("href"),
  }),
});

export const ImageExtract = z.object({
  image: z.object({
    name: z.string(),
    css: z.string(),
  }),
});

export const TableColumn = z.object({
  name: z.string(),
  header: z.string().optional(),
  index: z.number().int().optional(),
});

export const TableExtract = z.object({
  table: z.object({
    name: z.string(),
    css: z.string(),
    header_row: z.number().int().nonnegative().default(0),
    columns: z.array(TableColumn).optional(),
  }),
});

export const GroupedExtract = z.object({
  grouped: z.object({
    name: z.string(),
    css: z.string(),
    attr: z.string().optional(),
  }),
});

export const AIExtract = z.object({
  ai: z.object({
    name: z.string(),
    prompt: z.string(),
    input: z.string().optional(), // reference to sibling extracted field
    schema: z.record(z.unknown()).optional(),
    categories: z.array(z.string()).optional(),
  }),
});

export const Extraction = z.union([
  TextExtract,
  AttrExtract,
  HtmlExtract,
  LinkExtract,
  ImageExtract,
  TableExtract,
  GroupedExtract,
  AIExtract,
]);

// ── expansion (successor state generation) ──────────────

export const ElementExpand = z.object({
  over: z.literal("elements"),
  scope: z.string(), // CSS — each match = one successor state
  limit: z.number().int().positive().optional(),
  order: z.enum(["dfs", "bfs"]).default("dfs"),
});

export const PageExpand = z.object({
  over: z.literal("pages"),
  strategy: z.enum(["next", "numeric", "infinite"]),
  control: z.string(),                                  // CSS for the pagination control
  limit: z.number().int().positive().default(10),       // max pages (safety net)
  start: z.number().int().positive().default(1),
  stop: StopCondition.optional(),                       // when to stop (for next/infinite)
  order: z.enum(["dfs", "bfs"]).default("dfs"),
});

export const Axis = z.object({
  action: z.enum(["select", "type", "checkbox", "click"]),
  control: z.string(), // CSS for the form control or button group
  values: z.union([z.array(z.string()), z.literal("auto")]),
});

export const CombinationExpand = z.object({
  over: z.literal("combinations"),
  axes: z.array(Axis).min(1),
  order: z.enum(["dfs", "bfs"]).default("dfs"),
});

export const Expand = z.union([ElementExpand, PageExpand, CombinationExpand]);

// ── hooks ───────────────────────────────────────────────

export const HookDef = z.object({
  name: z.string(),
  config: z.record(z.unknown()).optional(),
});

export const NodeHooks = z
  .object({
    pre_extract: z.array(HookDef).optional(),
    post_extract: z.array(HookDef).optional(),
  })
  .optional();

export const ResourceHooks = z
  .object({
    post_discover: z.array(HookDef).optional(),
    pre_extract: z.array(HookDef).optional(),
    post_extract: z.array(HookDef).optional(),
    pre_assemble: z.array(HookDef).optional(),
    post_assemble: z.array(HookDef).optional(),
  })
  .optional();

// ── retry (closed-loop verify-and-retry) ────────────────

export const Retry = z.object({
  max: z.number().int().positive().default(3),
  delay_ms: z.number().int().nonnegative().default(1000),
});

// ── emit (subtree snapshot into artifact bucket) ────────
// emit = copy this node's subtree (data + nested children) into named artifact(s).
// Descendants without their own emit nest inside. Descendants WITH emit snip off.
// Without emit, extracted data is available to children via context
// but is NOT written to any artifact.

export const EmitTarget = z.object({
  to: z.string(),                                  // artifact name
  flatten: z.union([                               // flatten subtree into flat records
    z.literal(true),                               // true = denormalize entire subtree
    z.string(),                                    // string = flatten only this child node's records
  ]).optional(),
});

export const Emit = z.union([
  z.string(),                                       // shorthand: emit nested subtree to this artifact
  z.array(EmitTarget),                              // full form: multiple targets with per-target shaping
]);

// ── NER node (the core abstraction) ─────────────────────

export const NER = z.object({
  name: z.string(),
  parents: z.array(z.string()).default([]),

  // state — precondition check ("am I where I expect?")
  state: State.optional(),

  // action — deterministic browser actions, executed in order
  action: z.array(Action).optional(),

  // extract — node-local observation. Data is available to children
  // via accumulated context but is NOT automatically written to artifacts.
  extract: z.array(Extraction).optional(),

  // expand — how many successor states does this node produce?
  expand: Expand.optional(),

  // emit — snapshot this node's subtree into artifact bucket(s).
  // String shorthand: emit: "artifact_name" (nested subtree, no flatten)
  // Full form: emit: [{ to: "artifact", flatten: true | "child_name" }]
  //   flatten: true = denormalize entire subtree; string = flatten only named child
  emit: Emit.optional(),

  // consumes — iterate over records from artifact stream(s).
  consumes: z.union([z.string(), z.array(z.string())]).optional(),

  // retry — if state check fails, re-execute parent's actions and retry
  retry: Retry.optional(),

  // hooks — per-node extension points
  hooks: NodeHooks,

  // timing
  delay_ms: z.number().int().nonnegative().optional(),
});

// ── website state setup (auth, locale, etc.) ────────────

export const SetupAction = z.union([
  z.object({ open: z.string() }),
  z.object({ click: Locator }),
  z.object({ input: z.object({ target: Locator, value: z.string() }) }),
  z.object({ password: z.object({ target: Locator, env: z.string() }) }),
]);

export const StateSetup = z.object({
  skip_when: z.string(), // CSS — if found, setup already done
  actions: z.array(SetupAction).min(1),
});

// ── artifact schema (exploration agent's output contract) ─

export const FieldDef = z.object({
  type: z.enum(["string", "number", "boolean", "array", "object", "url", "binary"]).default("string"),
  required: z.boolean().default(true),
  description: z.string().optional(),
});

export const ArtifactSchema = z.object({
  fields: z.record(FieldDef),             // field name → type + constraints
  structure: z.enum(["nested", "flat"]).default("nested"),  // nested = tree, flat = denormalized
  consumes: z.union([z.string(), z.array(z.string())]).optional(), // upstream artifact(s)
  dedupe: z.string().optional(),           // field name to deduplicate by
  output: z.boolean().default(false),      // true = final deliverable
  format: z.enum(["jsonl", "csv", "json", "markdown"]).optional(),
  description: z.string().optional(),
});

// ── resource ────────────────────────────────────────────

export const Resource = z.object({
  name: z.string(),
  entry: z.object({
    url: z.string(),               // literal URL or "{field_ref}" template (resolved from consumes)
    root: z.string(),
  }),
  nodes: z.array(NER).min(1),
  produces: z.union([z.string(), z.array(z.string())]).optional(),
  consumes: z.union([z.string(), z.array(z.string())]).optional(),
  globals: z
    .object({
      timeout_ms: z.number().int().positive().default(60000),
      retries: z.number().int().nonnegative().default(2),
      user_agent: z.string().optional(),
      request_interval_ms: z.number().int().nonnegative().optional(),
      page_load_delay_ms: z.number().int().nonnegative().optional(),
    })
    .optional(),
  setup: StateSetup.optional(),
  hooks: ResourceHooks,
});

// ── quality gate (post-run data validation) ─────────────

export const QualityGate = z.object({
  min_records: z.number().int().positive().optional(),
  max_empty_pct: z.number().min(0).max(100).optional(),
  max_failed_pct: z.number().min(0).max(100).optional(),
  min_filled_pct: z.record(z.number().min(0).max(100)).optional(),
});

// ── deployment (top-level profile) ──────────────────────

export const Deployment = z.object({
  name: z.string(),
  artifacts: z.record(ArtifactSchema).optional(),  // declared output schemas
  resources: z.array(Resource).min(1),
  quality: QualityGate.optional(),
  schedule: z
    .object({
      cron: z.string().optional(),
      interval_s: z.number().int().positive().optional(),
    })
    .optional(),
  hooks: z
    .object({
      post_discover: z.array(HookDef).optional(),
      pre_assemble: z.array(HookDef).optional(),
      post_assemble: z.array(HookDef).optional(),
    })
    .optional(),
});

// ── inferred types ──────────────────────────────────────

export type Locator = z.infer<typeof Locator>;
export type WaitCondition = z.infer<typeof WaitCondition>;
export type Action = z.infer<typeof Action>;
export type State = z.infer<typeof State>;
export type Extraction = z.infer<typeof Extraction>;
export type StopCondition = z.infer<typeof StopCondition>;
export type Expand = z.infer<typeof Expand>;
export type Axis = z.infer<typeof Axis>;
export type HookDef = z.infer<typeof HookDef>;
export type Retry = z.infer<typeof Retry>;
export type EmitTarget = z.infer<typeof EmitTarget>;
export type Emit = z.infer<typeof Emit>;
export type NER = z.infer<typeof NER>;
export type SetupAction = z.infer<typeof SetupAction>;
export type StateSetup = z.infer<typeof StateSetup>;
export type FieldDef = z.infer<typeof FieldDef>;
export type ArtifactSchema = z.infer<typeof ArtifactSchema>;
export type Resource = z.infer<typeof Resource>;
export type QualityGate = z.infer<typeof QualityGate>;
export type Deployment = z.infer<typeof Deployment>;

/** A tree-structured record — the internal representation.
 *  Each node's extraction is in `data`; descendant nodes nest in `children`.
 *  Nodes with their own `emit` snip themselves off — they don't appear in
 *  the parent's children. */
export interface TreeRecord {
  node: string;
  url: string;
  data: Record<string, unknown>;
  children: Record<string, TreeRecord[]>;
  extracted_at: string;
}

/** A flat extracted record — produced by flattening a TreeRecord.
 *  All ancestor fields are denormalized into `data`. */
export interface ExtractedRecord {
  node: string;
  url: string;
  data: Record<string, unknown>;
  extracted_at: string;
}
