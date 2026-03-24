# UCC Framework

Use this for:
- building Splunk technical add-ons
- setup/config pages
- modular inputs
- alert actions
- REST handlers and add-on packaging

## Dig Deeper

- Use DeepWiki for `splunk/addonfactory-ucc-generator` when you need internal implementation detail beyond the public quickstart, especially `globalConfig` schema, REST handler generation, OAuth support, inputs/spec generation, and test/build internals.
- Use Context7 or official docs/repo pages for the supported command surface and public workflow; use DeepWiki to understand how UCC is wired internally.

## What UCC Is

UCC (Universal Configuration Console) is Splunk’s supported toolkit for
generating and maintaining technical add-ons with common UI and backend pieces.

UCC-generated add-ons are backed by:
- `splunktaucclib`
- `solnlib`
- generated UI assets under `appserver`
- generated REST handlers under `bin`

The center of gravity is `globalConfig.{json|yaml}`. That schema acts as the
single source of truth that drives UI generation, REST handler generation,
config/spec generation, and a large part of the add-on structure.

## When To Use It

Use UCC when the deliverable is a Splunk add-on, not just an external script.

Good fits:
- a Splunk app/add-on with configuration pages
- modular inputs that ingest data into Splunk
- packaged alert actions or credentialed connectors

Avoid UCC when:
- you only need an external Python CLI
- you are not shipping a Splunk app

## Strong Default

For a new Splunk technical add-on, start with UCC unless you have a specific
constraint that UCC cannot satisfy. Hand-built add-ons are harder to keep
consistent, harder to package, and harder to validate.

If you need an account page, inputs page, proxy/logging/settings tabs, modular
inputs, or OAuth-backed credentials, that is squarely UCC territory.

## What UCC Generates

- setup/configuration UI
- Python REST handlers for CRUD operations
- modular input scaffolding
- alert action templates
- OpenAPI description artifacts
- package/build/publish workflow support
- optional custom UI extension points

## The Important Mental Model

Author the add-on declaratively first:

- metadata and naming
- configuration pages/tabs
- account entities and validators
- input services and fields
- OAuth/basic auth model
- dashboard/monitoring hooks when needed

Then let UCC generate the repetitive plumbing.

## `globalConfig` Matters

`globalConfig` defines:

- metadata such as add-on name, display name, and REST root
- pages such as configuration, inputs, and dashboard
- entity field definitions, labels, help, validation, and requirements
- handler types such as single-model, multiple-model, data-input, and OAuth-enabled handlers

Good UCC work is mostly good `globalConfig` design.

## Useful Workflow Notes

- `ucc-gen init --addon-name ... --addon-display-name ...` bootstraps add-on structure
- `ucc-gen build --source <package-dir>` generates handlers, UI, and build artifacts from the package source
- `ucc-gen package --path <output-dir>` packages the built add-on for distribution
- newer versions include `ucc-gen publish` for Splunkbase upload flows
- dashboard sections can be configured through UCC metadata and custom dashboard JSON

## Typical Workflow

1. initialize the add-on structure
2. define `globalConfig` and app metadata
3. implement the actual input/alert/backend logic in `bin`
4. build generated assets
5. inspect generated handlers/spec files/output layout
6. package and run AppInspect-style validation
7. publish or ship the package

## What UCC Is Good At

- repeatable add-on structure
- config UI generation
- REST handler scaffolding
- modular input patterns
- alert action packaging
- reducing hand-written Splunk app boilerplate
- generating `inputs.conf` and `*.conf.spec` artifacts from declarative input definitions
- OAuth-capable account/config handlers

## What UCC Is Not For

- generic external automation
- one-off export scripts
- dashboards unrelated to add-on configuration or monitoring
- agent tooling that does not need to live inside Splunk

## Customization Guidance

- Prefer configuration-driven UCC features first.
- Use custom UI extensions only when the stock controls are insufficient.
- Keep generated and hand-maintained code boundaries obvious.

## Handler Types To Know

- **Single model handlers**: one configuration model, common for account/config tabs
- **Multiple model handlers**: multiple stanza/settings-style pages such as logging or proxy
- **Data input handlers**: modular input definitions and their UI/backend contract
- **OAuth-enhanced handlers**: single-model handlers extended for token acquisition and OAuth workflows

This is the reason UCC is worth using: these handler families are repetitive,
error-prone, and not worth hand-authoring unless you have no alternative.

## Inputs.conf Generation

For input services, UCC can generate:

- `default/inputs.conf`
- `README/inputs.conf.spec`
- additional `*.conf.spec` files when custom `conf` mapping is used

Key practical implications:

- the stanza name is derived from the input definition rather than being a normal field
- default values and help text propagate into the generated spec files
- `python.version = python3` is part of the generated inputs defaults

Design inputs carefully in `globalConfig`; the generated conf/spec output is one
of the main deliverables.

## OAuth Guidance

UCC has first-class support for:

- basic auth
- OAuth authorization code flow
- OAuth client credentials flow

Use UCC for OAuth-backed add-ons rather than bolting OAuth logic onto a
hand-written setup page. Mark secrets as encrypted, validate endpoints and IDs,
and keep auth flow selection explicit in the config model.

## Testing / Quality

The public DeepWiki indexing of the UCC repo shows a fairly complete test and
CI framework, including smoke tests and AppInspect-oriented validation. That is
a strong signal that UCC is not just scaffolding but the expected maintenance path.

## Notes

- Official docs describe UCC as simplifying add-on creation with UI, REST handlers, modular inputs, OAuth, and alert action templates.
- The official GitHub repo describes auto-generation of UI, REST handlers, modular inputs, and monitoring dashboards.
- DeepWiki’s repo indexing is useful here because it makes the internal model visible: `globalConfig` schema, REST handler families, inputs/spec generation, OAuth support, and the build/package/test flow.

## Sources

- https://docs.splunk.com/Documentation/AddonBuilder/latest/UserGuide/Aframeworkforadd-ondevelopment
- https://github.com/splunk/addonfactory-ucc-generator
- https://splunk.github.io/addonfactory-ucc-generator/
- https://deepwiki.com/splunk/addonfactory-ucc-generator/2.3-globalconfig-schema
- https://deepwiki.com/splunk/addonfactory-ucc-generator/5-rest-handler-generation
- https://deepwiki.com/splunk/addonfactory-ucc-generator/5.2-oauth-support
- https://deepwiki.com/splunk/addonfactory-ucc-generator/6.1-inputs.conf-generation
- https://deepwiki.com/splunk/addonfactory-ucc-generator/3.2-cli-commands
- https://deepwiki.com/splunk/addonfactory-ucc-generator/7.2-testing-framework
