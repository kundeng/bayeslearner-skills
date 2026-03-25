# bayeslearner-skills

Umbrella repository for BayesLearner agent skills.

This repo is organized as a multi-skill package for `skills.sh` / `npx skills`.
Each installable skill lives under `skills/<skill-name>/SKILL.md`.

## Install

List available skills:

```bash
npx skills add kundeng/bayeslearner-skills --list
```

Install one skill from the umbrella repo:

```bash
npx skills add kundeng/bayeslearner-skills --skill spec-driven-dev
```

Preferred for installing or upgrading one specific skill from upstream:

```bash
npx skills add https://github.com/kundeng/bayeslearner-skills/tree/main/skills/analytic-workbench -g --agent '*' -y
```

Install all skills:

```bash
npx skills add kundeng/bayeslearner-skills --all
```

Install from a direct upstream subdirectory path:

```bash
npx skills add https://github.com/kundeng/bayeslearner-skills/tree/main/skills/spec-driven-dev
```

Install from a local checkout only when intentionally testing local, unpushed changes:

```bash
npx skills add ./skills/analytic-workbench -g --agent '*' -y
```

## Which Command To Use

- To install or upgrade one published skill in your agent environment, use the upstream subdirectory URL under `skills/<skill-name>`.
- To test local edits before pushing, use `./skills/<skill-name>`.
- To install several skills from this repo, use the umbrella repo with `--skill` or `--all`.
- To update a legacy standalone mirror repo, use `scripts/publish-legacy.sh`. That is a publishing step, not a local install step.

## Layout

```text
skills/
  analytic-workbench/
  design2spec/
  resume-claude-here/
  spec-driven-dev/
  splunk-platform/
  vibe-frontend-design/
  wise-scraper/
  workflow-guardrails/
```

Important:

- Do not add a root-level `SKILL.md` to this repository.
- The umbrella repo is a multi-skill container, not itself a skill.
- Skill folder names should stay aligned with the `name:` field in each skill's frontmatter.

## Current Skills

- `analytic-workbench`
- `design2spec`
- `resume-claude-here`
- `spec-driven-dev`
- `splunk-platform`
- `vibe-frontend-design`
- `wise-scraper`
- `workflow-guardrails`

## Source Model

This repository is intended to be the canonical maintenance location for the
skills included here.

Older standalone repositories can remain published as downstream mirrors. Use
`git subtree split` from `skills/<name>` to push updates back out to those
legacy repositories.

See `scripts/publish-legacy.sh`.
