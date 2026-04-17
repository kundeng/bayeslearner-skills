# bayeslearner-skills

This repository is a multi-skill container for `skills.sh`.

Rules:

- Do not add a root `SKILL.md`.
- Each installable skill must live in `skills/<skill-name>/`.
- Each skill directory must contain its own `SKILL.md` with valid `name` and `description` frontmatter.
- Prefer keeping each skill self-contained with its own `references/`, `scripts/`, `evals/`, `templates/`, and examples as needed.
- When mirroring to legacy standalone repos, treat this umbrella repo as canonical and push outward from `skills/<name>`.
- When asked to install or upgrade one skill "from upstream", prefer the shorthand form:
  `npx skills add kundeng/bayeslearner-skills@<skill-name> -g --agent '*' -y`
- After pushing, prefer the shorthand form above for normal installs.
- The direct subdirectory URL remains a fallback if shorthand behavior ever changes:
  `npx skills add https://github.com/kundeng/bayeslearner-skills/tree/main/skills/<skill-name> -g --agent '*' -y`
- Use local path installs only when explicitly testing local unpushed changes:
  `npx skills add ./skills/<skill-name> -g --agent '*' -y`
- If a branch-specific upstream install is blocked by a `skills` CLI branch parsing issue, use the local path only as a temporary testing fallback, then return to the shorthand upstream install once the change is on a stable branch.
- Do not confuse install/upgrade with legacy mirror publishing.
  Installing a skill updates the local agent environment.
  Publishing a legacy mirror updates the standalone downstream repository.
- If the user says "sync this repo", clarify by action in your own execution:
  push this umbrella repo, publish a legacy mirror, or install/upgrade a skill are separate steps.
