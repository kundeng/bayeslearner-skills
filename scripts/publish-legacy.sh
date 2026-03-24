#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: $ROOT_DIR is not a git repository." >&2
  echo "Initialize git first, then rerun this script." >&2
  exit 1
fi

declare -A LEGACY_REPOS=(
  [analytic-workbench]="git@github.com:kundeng/analytic-workbench-skill.git"
  [resume-claude-here]="git@github.com:kundeng/resume-claude-here.git"
  [spec-driven-dev]="git@github.com:kundeng/spec-driven-dev-skill.git"
  [splunk-platform]="git@github.com:kundeng/splunk-platform-skill.git"
  [wise-scraper]="git@github.com:kundeng/wise-scraper-skill.git"
)

usage() {
  cat <<'EOF'
Usage:
  scripts/publish-legacy.sh --list
  scripts/publish-legacy.sh <skill-name> [branch]

Examples:
  scripts/publish-legacy.sh --list
  scripts/publish-legacy.sh spec-driven-dev
  scripts/publish-legacy.sh splunk-platform main

Notes:
  - This repo is the canonical source.
  - The script publishes one skill subtree from skills/<skill-name>.
  - The destination repo is treated as a downstream mirror.
EOF
}

if [[ "${1:-}" == "--list" ]]; then
  printf '%s\n' "${!LEGACY_REPOS[@]}" | sort
  exit 0
fi

SKILL_NAME="${1:-}"
TARGET_BRANCH="${2:-main}"

if [[ -z "$SKILL_NAME" ]]; then
  usage
  exit 1
fi

if [[ -z "${LEGACY_REPOS[$SKILL_NAME]:-}" ]]; then
  echo "Error: unknown skill '$SKILL_NAME'." >&2
  echo "Known skills:" >&2
  printf '  %s\n' "${!LEGACY_REPOS[@]}" | sort >&2
  exit 1
fi

PREFIX="skills/$SKILL_NAME"
REMOTE_URL="${LEGACY_REPOS[$SKILL_NAME]}"
TMP_BRANCH="publish-$SKILL_NAME"

if [[ ! -f "$PREFIX/SKILL.md" ]]; then
  echo "Error: missing $PREFIX/SKILL.md" >&2
  exit 1
fi

echo "Splitting subtree from $PREFIX"
git branch -D "$TMP_BRANCH" >/dev/null 2>&1 || true
git subtree split --prefix="$PREFIX" -b "$TMP_BRANCH"

echo "Pushing $TMP_BRANCH to $REMOTE_URL ($TARGET_BRANCH)"
git push "$REMOTE_URL" "$TMP_BRANCH:$TARGET_BRANCH" --force-with-lease

echo "Cleaning up temporary branch $TMP_BRANCH"
git branch -D "$TMP_BRANCH" >/dev/null

echo "Published $SKILL_NAME to $REMOTE_URL"
