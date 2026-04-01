// DEPRECATED — The canonical schema is now Zod-based.
//
// Source of truth: references/runner/src/schema.ts
//
// This CUE file is kept as a human-readable reference only.
// It is NOT used for validation or code generation.
// For runtime validation, import from schema.ts.
// For JSON Schema export, use zod-to-json-schema.

package wise

// ── NER Node ────────────────────────────────────────────
// Each node is a (state, action) → observation triple.

Deployment: {
	name:       string
	artifacts?: [string]: ArtifactSchema    // declared output schemas
	resources:  [...Resource]
	quality?:   QualityGate
	schedule?: {
		cron?:       string
		interval_s?: int & >0
	}
	hooks?: {
		post_discover?: [...Hook]
		pre_assemble?:  [...Hook]
		post_assemble?: [...Hook]
	}
}

// ── Artifact Schema ─────────────────────────────────────
// Exploration agent declares these — typed record streams.
// Can be internal (plumbing) or output (deliverables).

FieldDef: {
	type?:        "string" | "number" | "boolean" | "array" | "object" | *"string"
	required?:    bool | *true
	description?: string
}

ArtifactSchema: {
	fields:       [string]: FieldDef       // field name → type + constraints
	consumes?:    string                    // upstream artifact (DAG edge)
	output?:      bool | *false            // true = final deliverable
	format?:      "jsonl" | "csv" | "json" | "markdown"  // output format hint
	description?: string
}

Resource: {
	name:  string
	entry: {
		url:  string | {from: string}
		root: string
	}
	nodes:     [...NER] & [_, ...]
	produces?: string                       // artifact this resource writes to
	consumes?: string                       // artifact this resource reads from
	globals?: {
		timeout_ms?:          int & >0 | *60000
		retries?:             int & >=0 | *2
		user_agent?:          string
		request_interval_ms?: int & >=0
		page_load_delay_ms?:  int & >=0
	}
	setup?: StateSetup
	hooks?: ResourceHooks
}

NER: {
	name:      string
	parents:   [...string] | *[]
	state?:    State
	action?:   [...Action]
	extract?:  [...Extraction]
	expand?:   Expand
	yields?:   string                       // write records into this artifact stream
	consumes?: string                       // iterate over records from this artifact
	retry?:    Retry
	hooks?: {
		pre_extract?:  [...Hook]
		post_extract?: [...Hook]
	}
	delay_ms?: int & >=0
}

// ── State (preconditions) ───────────────────────────────

State: {
	url?:              string
	url_pattern?:      string
	selector_exists?:  string
	text_in_page?:     string
	table_headers?:    [...string]
}

// ── Actions ─────────────────────────────────────────────

Action: ClickAction | SelectAction | ScrollAction | WaitAction | RevealAction | NavigateAction | InputAction

Locator: {
	css?:  string
	text?: string
	role?: string
	name?: string
}

ClickAction: {
	click:       Locator
	type?:       "real" | "scripted" | *"real"
	uniqueness?: "text" | "html" | "css" | "dom"
	discard?:    "never" | "when-control-exists" | "always" | *"never"
	delay_ms?:   int & >=0
}

SelectAction: {
	select:    Locator
	value:     string
	delay_ms?: int & >=0
}

ScrollAction: {
	scroll:    "down" | "up"
	px?:       int & >0 | *500
	delay_ms?: int & >=0
}

WaitAction: {
	wait: {idle: true} | {selector: string} | {ms: int & >0}
}

RevealAction: {
	reveal:    Locator
	mode?:     "click" | "hover" | *"click"
	delay_ms?: int & >=0
}

NavigateAction: {
	navigate: {to: string}
}

InputAction: {
	input: {
		target: Locator
		value:  string
	}
	delay_ms?: int & >=0
}

// ── Extraction ──────────────────────────────────────────

Extraction: TextExtract | AttrExtract | HtmlExtract | LinkExtract | ImageExtract | TableExtract | GroupedExtract | AIExtract

TextExtract: {
	text: {
		name:   string
		css:    string
		regex?: string
	}
}

AttrExtract: {
	attr: {
		name: string
		css:  string
		attr: string
	}
}

HtmlExtract: {
	html: {
		name: string
		css:  string
	}
}

LinkExtract: {
	link: {
		name: string
		css:  string
		attr?: string | *"href"
	}
}

ImageExtract: {
	image: {
		name: string
		css:  string
	}
}

TableExtract: {
	table: {
		name:        string
		css:         string
		header_row?: int & >=0 | *0
		columns?: [...{
			name:    string
			header?: string
			index?:  int
		}]
	}
}

GroupedExtract: {
	grouped: {
		name:  string
		css:   string
		attr?: string
	}
}

AIExtract: {
	ai: {
		name:        string
		prompt:      string
		input?:      string
		schema?:     _
		categories?: [...string]
	}
}

// ── Retry ───────────────────────────────────────────────

Retry: {
	max?:      int & >0 | *3
	delay_ms?: int & >=0 | *1000
}

// ── Stop Condition ──────────────────────────────────────

StopCondition: {
	sentinel?:      string                  // CSS — stop when this appears
	sentinel_gone?: string                  // CSS — stop when this disappears
	stable?: {
		css:    string                        // count elements matching this
		after?: int & >0 | *2                // N consecutive unchanged checks
	}
	limit?: int & >0 | *50                 // hard max iterations (safety net)
}

// ── Expansion ───────────────────────────────────────────

Expand: ElementExpand | PageExpand | CombinationExpand

ElementExpand: {
	over:   "elements"
	scope:  string
	limit?: int & >0
	order?: "dfs" | "bfs" | *"dfs"
}

PageExpand: {
	over:      "pages"
	strategy:  "next" | "numeric" | "infinite"
	control:   string
	limit?:    int & >0 | *10
	start?:    int & >=1 | *1
	stop?:     StopCondition
	order?:    "dfs" | "bfs" | *"dfs"
}

CombinationExpand: {
	over: "combinations"
	axes: [...Axis] & [_, ...]
	order?: "dfs" | "bfs" | *"dfs"
}

Axis: {
	action:  "select" | "type" | "checkbox"
	control: string
	values:  [...string] | "auto"
}

// ── Hooks ───────────────────────────────────────────────

Hook: {
	name:    string
	config?: _
}

ResourceHooks: {
	post_discover?: [...Hook]
	pre_extract?:   [...Hook]
	post_extract?:  [...Hook]
	pre_assemble?:  [...Hook]
	post_assemble?: [...Hook]
}

// ── State Setup ─────────────────────────────────────────

StateSetup: {
	skip_when: string
	actions:   [...SetupAction] & [_, ...]
}

SetupAction: {open: string} | {click: Locator} | {input: {target: Locator, value: string}} | {password: {target: Locator, env: string}}

// ── Quality Gate ────────────────────────────────────────

QualityGate: {
	min_records?:   int & >0
	max_empty_pct?: number & >=0 & <=100
	max_failed_pct?: number & >=0 & <=100
	min_filled_pct?: [string]: number & >=0 & <=100
}
