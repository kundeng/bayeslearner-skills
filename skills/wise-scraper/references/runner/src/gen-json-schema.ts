#!/usr/bin/env npx tsx
/**
 * Generate JSON Schema from the Zod source of truth.
 * Usage: npx tsx src/gen-json-schema.ts > ../schema.generated.json
 */

import { zodToJsonSchema } from "zod-to-json-schema";
import { Deployment } from "./schema.js";

const jsonSchema = zodToJsonSchema(Deployment, {
  name: "WISEDeployment",
  $refStrategy: "root",
});

console.log(JSON.stringify(jsonSchema, null, 2));
