#!/bin/bash
# Ralph Loop Monitor — refreshes every 15s
# Ships with the ralph-deploy skill. Copy to .ralph/monitor.sh in your project.

# Detect available LLM for summarization (optional, saves tokens by using smallest)
detect_llm() {
  if command -v claude &>/dev/null; then echo "claude"; return; fi
  if command -v codex &>/dev/null; then echo "codex"; return; fi
  if command -v aichat &>/dev/null; then echo "aichat"; return; fi
  echo ""
}
LLM=$(detect_llm)

# Summarize text with detected LLM (one-shot, no conversation)
summarize() {
  local text="$1"
  local prompt="Summarize in one sentence what is being worked on: $text"
  case "$LLM" in
    claude) echo "$text" | claude -p "$prompt" --model haiku 2>/dev/null | head -1 ;;
    codex) echo "$prompt" | codex -q 2>/dev/null | head -1 ;;
    aichat) echo "$prompt" | aichat 2>/dev/null | head -1 ;;
    *) echo "$text" | head -1 ;;
  esac
}

while true; do
  clear
  printf "═══ RALPH MONITOR ═══"
  [ -n "$LLM" ] && printf "  (AI: %s)" "$LLM"
  printf "\n\n"

  # Loop status
  ralph loops list 2>/dev/null | grep -E "primary|running|done" | head -1

  # Current hat + iteration
  printf "\n── Current ──\n"
  LATEST_ITER=$(grep "ITERATION" .ralph/run.log 2>/dev/null | tail -1)
  if [ -n "$LATEST_ITER" ]; then
    echo "  $LATEST_ITER"
  fi

  # What's being worked on — extract from scratchpad
  printf "\n── Active Task ──\n"
  if [ -f .ralph/agent/scratchpad.md ]; then
    TASK_LINE=$(grep -E "^##+ (Task|Current|Working|verify|fix)" .ralph/agent/scratchpad.md 2>/dev/null | tail -1)
    CRITERIA=$(grep -A3 "Accept when\|Acceptance Criteria\|Done when" .ralph/agent/scratchpad.md 2>/dev/null | head -4)
    if [ -n "$TASK_LINE" ]; then
      echo "  $TASK_LINE"
      echo "$CRITERIA" | sed 's/^/  /'
    else
      # Fallback: summarize last section of scratchpad
      TAIL=$(tail -10 .ralph/agent/scratchpad.md 2>/dev/null)
      if [ -n "$LLM" ] && [ -n "$TAIL" ]; then
        printf "  "
        summarize "$TAIL"
      else
        echo "  (check scratchpad for details)"
      fi
    fi
  else
    echo "  (no scratchpad yet)"
  fi

  # Recent events (last 3, compact)
  printf "\n── Events ──\n"
  ralph events --last 3 2>/dev/null | grep -E "^\s+[0-9]" | while read line; do
    echo "  $line"
  done

  # Last event payload — summarize if LLM available
  LAST_PAYLOAD=$(ralph events --last 1 2>/dev/null | tail -1 | awk -F'|' '{print $NF}' | sed 's/^ *//')
  if [ -n "$LAST_PAYLOAD" ]; then
    printf "\n── Last Event ──\n"
    if [ -n "$LLM" ] && [ ${#LAST_PAYLOAD} -gt 100 ]; then
      printf "  "
      summarize "$LAST_PAYLOAD"
    else
      echo "  ${LAST_PAYLOAD:0:120}"
    fi
  fi

  # Files changed since last commit
  printf "\n── Uncommitted Changes ──\n"
  CHANGES=$(git diff --name-only HEAD 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null | grep -v "^\.claude/" | grep -v "^\.coverage")
  if [ -n "$CHANGES" ]; then
    echo "$CHANGES" | head -8 | sed 's/^/  + /'
    COUNT=$(echo "$CHANGES" | wc -l | tr -d ' ')
    if [ "$COUNT" -gt 8 ]; then
      echo "  ... and $((COUNT - 8)) more"
    fi
  else
    echo "  (clean)"
  fi

  # Git log (last 3 commits)
  printf "\n── Recent Commits ──\n"
  git log --oneline -3 2>/dev/null | sed 's/^/  /'

  # Memories
  if [ -f .ralph/agent/memories.md ]; then
    MEM_COUNT=$(grep -c "^### mem-" .ralph/agent/memories.md 2>/dev/null)
    printf "\n── Memories: %s ──\n" "$MEM_COUNT"
  fi

  printf "\n[%s] refreshing in 15s\n" "$(date +%H:%M:%S)"
  sleep 15
done
