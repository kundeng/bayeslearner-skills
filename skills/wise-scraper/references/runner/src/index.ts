/**
 * WISE NER Runner — public API.
 *
 * Exports all components for use by skill consumers:
 *   - Schema: Zod validators + inferred TypeScript types
 *   - Driver: abstract BrowserDriver + AgentBrowserDriver
 *   - AI: abstract AIAdapter + AIChatAdapter + NullAIAdapter
 *   - Engine: NER graph walker
 *   - Hooks: extensible hook system
 *   - Processing: HTML→MD, table conversion, assembly
 *   - Config: Hydra-like config composition
 */

// Schema (source of truth)
export {
  Deployment,
  Resource,
  NER,
  State,
  Action,
  Extraction,
  Expand,
  Locator,
  WaitCondition,
  HookDef,
  QualityGate,
  StateSetup,
} from "./schema.js";
export type {
  Deployment as DeploymentType,
  Resource as ResourceType,
  NER as NERType,
  State as StateType,
  Action as ActionType,
  Extraction as ExtractionType,
  Expand as ExpandType,
  Locator as LocatorType,
  ExtractedRecord,
} from "./schema.js";

// Driver
export type { BrowserDriver, DriverWait } from "./driver.js";
export { locatorToSelector, escapeJs } from "./driver.js";
export { AgentBrowserDriver } from "./agent-browser-driver.js";

// AI
export type { AIAdapter } from "./ai.js";
export { NullAIAdapter } from "./ai.js";
export { AIChatAdapter } from "./aichat-adapter.js";

// Engine
export { Engine } from "./engine.js";

// Interrupts
export { InterruptHandler, COMMON_RULES } from "./interrupts.js";
export type { InterruptRule } from "./interrupts.js";

// Hooks
export { HookRegistry } from "./hooks.js";
export type { HookFn, HookPoint } from "./hooks.js";

// Config
export { loadConfig } from "./config.js";
export type { RunnerConfig, InputConfig, ResolvedConfig } from "./config.js";

// Processing
export {
  htmlToMarkdown,
  htmlTableToMarkdown,
  extractRefs,
  cleanHtml,
  assembleMarkdown,
  assembleCsv,
} from "./processing.js";
export type { Reference } from "./processing.js";
