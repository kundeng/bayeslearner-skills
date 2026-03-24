# Splunk App Packaging And Validation

Use this for:

- packaging apps and add-ons
- AppInspect-minded release checks
- deciding whether an artifact is ready for Splunk Cloud or distribution
- release hygiene around knowledge objects and generated assets

## Default Rule

If the deliverable is a Splunk app or add-on archive, packaging and validation
are part of the implementation. Do not treat them as an optional final polish.

## Minimum Release Checklist

- package builds reproducibly
- generated assets are current
- app metadata is intentional
- Python version/runtime assumptions are explicit
- knowledge objects have correct app/owner sharing assumptions
- no stray credentials, dev files, or local state artifacts are included
- AppInspect or equivalent validation is run before handoff

## When This Matters Most

- UCC-generated add-ons
- modular inputs
- alert actions
- Splunk Cloud-targeted apps
- anything intended for Splunkbase or broad distribution

## Common Failure Modes

- generated UI/backend artifacts not rebuilt before packaging
- app contains environment-specific files
- unsupported dependencies or Python assumptions
- dashboards/saved searches/macros shipped with wrong ownership or sharing intent
- package passes local smoke tests but fails Cloud/AppInspect constraints

## Relationship To Other References

- Use `ucc-framework.md` to build the add-on.
- Use this file to decide whether the output is actually shippable.
- Use `admin-searches.md` when you need to inventory knowledge objects before packaging or migration.

## Practical Guidance

- Keep package generation scripted.
- Keep release output separate from source directories.
- Validate after each meaningful packaging change, not only at the end.
- For Cloud-bound apps, bias toward conservative, documented platform features.

## Sources

- https://splunk.github.io/addonfactory-ucc-generator/
- https://github.com/splunk/addonfactory-ucc-generator
