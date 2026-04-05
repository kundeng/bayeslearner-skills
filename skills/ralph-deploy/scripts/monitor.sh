#!/bin/bash
# Ralph Loop Monitor — ships with ralph-deploy skill
# Designed for wide horizontal pane (full terminal width)

# Detect LLM for one-line summaries
detect_llm() {
  command -v claude &>/dev/null && echo "claude" && return
  command -v codex &>/dev/null && echo "codex" && return
  command -v aichat &>/dev/null && echo "aichat" && return
  echo ""
}
LLM=$(detect_llm)

oneliner() {
  local text="$1"
  if [ -z "$text" ]; then return; fi
  case "$LLM" in
    claude) claude -p "In exactly one short sentence (under 15 words), say what is happening: $text" --model haiku 2>/dev/null | head -1 ;;
    *) echo "${text:0:80}" ;;
  esac
}

while true; do
  clear
  COLS=$(tput cols 2>/dev/null || echo 80)
  LINE=$(printf '%*s' "$COLS" '' | tr ' ' '─')

  # Header
  printf "\033[1m═══ RALPH MONITOR\033[0m"
  [ -n "$LLM" ] && printf "  \033[2m(AI: %s)\033[0m" "$LLM"
  printf "\n%s\n" "$LINE"

  # Status line: iteration + hat
  ITER_LINE=$(grep "ITERATION" .ralph/run.log 2>/dev/null | tail -1 | sed 's/^ *//')
  if [ -n "$ITER_LINE" ]; then
    printf "\033[1;33m▶ %s\033[0m\n" "$ITER_LINE"
  else
    printf "\033[2m▶ (waiting for first iteration)\033[0m\n"
  fi

  # Active task from scratchpad
  printf "\n\033[1mACTIVE TASK\033[0m\n"
  if [ -f .ralph/agent/scratchpad.md ]; then
    # Try to find current task
    TASK=$(grep -E "^##+ .*(Task|Current|Working|verify|fix|adapt|teardown|Infra)" .ralph/agent/scratchpad.md 2>/dev/null | tail -1 | sed 's/^#* *//')
    if [ -n "$TASK" ]; then
      printf "  %s\n" "$TASK"
    else
      # Fallback: last heading
      TASK=$(grep "^## " .ralph/agent/scratchpad.md 2>/dev/null | tail -1 | sed 's/^## //')
      printf "  %s\n" "${TASK:-(reading scratchpad...)}"
    fi
    # Show first acceptance criterion
    CRIT=$(grep -A1 "Accept when\|Acceptance\|Done when\|Verify:" .ralph/agent/scratchpad.md 2>/dev/null | grep -v "^--$" | head -2 | sed 's/^/  /')
    [ -n "$CRIT" ] && echo "$CRIT"
  else
    printf "  \033[2m(no scratchpad yet)\033[0m\n"
  fi

  # Last event — AI summarized if possible
  printf "\n\033[1mLAST EVENT\033[0m\n"
  LAST_RAW=$(ralph events --last 1 2>/dev/null | tail -2 | head -1)
  if [ -n "$LAST_RAW" ]; then
    TOPIC=$(echo "$LAST_RAW" | awk -F'|' '{print $5}' | sed 's/^ *//;s/ *$//')
    PAYLOAD=$(echo "$LAST_RAW" | awk -F'|' '{print $NF}' | sed 's/^ *//;s/ *$//')
    printf "  \033[1;36m%s\033[0m  " "$TOPIC"
    if [ -n "$LLM" ] && [ ${#PAYLOAD} -gt 60 ]; then
      oneliner "$PAYLOAD"
    else
      echo "${PAYLOAD:0:$((COLS-4))}"
    fi
  else
    printf "  \033[2m(no events yet)\033[0m\n"
  fi

  # Uncommitted changes
  printf "\n\033[1mWORKING ON\033[0m\n"
  CHANGED=$(git diff --name-only HEAD 2>/dev/null | grep -v "^\.coverage$")
  UNTRACKED=$(git ls-files --others --exclude-standard 2>/dev/null | grep -v "^\.claude/" | grep -v "^\.coverage$")
  ALL_CHANGES=$(printf "%s\n%s" "$CHANGED" "$UNTRACKED" | grep -v "^$" | sort -u)
  if [ -n "$ALL_CHANGES" ]; then
    echo "$ALL_CHANGES" | head -6 | while read f; do
      printf "  \033[32m+ %s\033[0m\n" "$f"
    done
    COUNT=$(echo "$ALL_CHANGES" | wc -l | tr -d ' ')
    [ "$COUNT" -gt 6 ] && printf "  \033[2m... and %d more\033[0m\n" "$((COUNT-6))"
  else
    printf "  \033[2m(clean)\033[0m\n"
  fi

  # Recent commits
  printf "\n\033[1mCOMMITS\033[0m\n"
  git log --oneline -3 2>/dev/null | while read line; do
    printf "  %s\n" "$line"
  done

  # Memories
  if [ -f .ralph/agent/memories.md ]; then
    MEM=$(grep -c "^## " .ralph/agent/memories.md 2>/dev/null)
    printf "\n\033[2mMemories: %s sections\033[0m\n" "$MEM"
  fi

  printf "\n%s\n\033[2m%s  refreshing in 15s\033[0m\n" "$LINE" "$(date +%H:%M:%S)"
  sleep 15
done
