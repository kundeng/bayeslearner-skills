# bayeslearner-skills

Umbrella repository for BayesLearner agent skills.

This repo is organized as a multi-skill package for `skills.sh` / `npx skills`.
Each installable skill lives under `skills/<skill-name>/SKILL.md`.

## Install

List available skills:

```bash
npx skills add kundeng/bayeslearner-skills --list
```

Install one skill:

```bash
npx skills add kundeng/bayeslearner-skills --skill spec-driven-dev
```

Install all skills:

```bash
npx skills add kundeng/bayeslearner-skills --all
```

Install from a direct subdirectory path:

```bash
npx skills add https://github.com/kundeng/bayeslearner-skills/tree/main/skills/spec-driven-dev
```

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

## Source Model

This repository is intended to be the canonical maintenance location for the
skills included here.

Older standalone repositories can remain published as downstream mirrors. Use
`git subtree split` from `skills/<name>` to push updates back out to those
legacy repositories.

See `scripts/publish-legacy.sh`.
