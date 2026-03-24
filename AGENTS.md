# bayeslearner-skills

This repository is a multi-skill container for `skills.sh`.

Rules:

- Do not add a root `SKILL.md`.
- Each installable skill must live in `skills/<skill-name>/`.
- Each skill directory must contain its own `SKILL.md` with valid `name` and `description` frontmatter.
- Prefer keeping each skill self-contained with its own `references/`, `scripts/`, `evals/`, `templates/`, and examples as needed.
- When mirroring to legacy standalone repos, treat this umbrella repo as canonical and push outward from `skills/<name>`.
