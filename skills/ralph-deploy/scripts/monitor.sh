#!/bin/bash
# Ralph Loop Monitor — refreshes every 15s
while true; do
  clear
  printf "═══ RALPH MONITOR ═══\n\n"

  # Loop status
  ralph loops list 2>/dev/null | grep -E "primary|running|done" | head -1

  # Current hat + iteration
  printf "\n── Current ──\n"
  LATEST_ITER=$(grep "ITERATION" .ralph/run.log 2>/dev/null | tail -1)
  if [ -n "$LATEST_ITER" ]; then
    echo "  $LATEST_ITER"
  fi

  # What's being worked on — extract current task from scratchpad
  printf "\n── Active Task ──\n"
  if [ -f .ralph/agent/scratchpad.md ]; then
    # Look for the most recent task heading or "current" marker
    grep -E "^##+ (Task|Current|Working|verify|fix)" .ralph/agent/scratchpad.md 2>/dev/null | tail -1 | sed 's/^/  /'
    # Show acceptance criteria for current task (first 3 lines after "Accept when")
    grep -A3 "Accept when\|Acceptance Criteria\|Done when" .ralph/agent/scratchpad.md 2>/dev/null | head -4 | sed 's/^/  /'
  else
    echo "  (no scratchpad yet)"
  fi

  # Recent events (last 3, compact)
  printf "\n── Events ──\n"
  ralph events --last 3 2>/dev/null | grep -E "^\s+[0-9]" | while read line; do
    echo "  $line"
  done

  # Last event payload (truncated)
  LAST_PAYLOAD=$(ralph events --last 1 2>/dev/null | grep -oP 'Payload.*' | head -1)
  if [ -n "$LAST_PAYLOAD" ]; then
    printf "\n── Last Event Detail ──\n"
    echo "  ${LAST_PAYLOAD:0:120}"
  fi

  # Files changed since last commit
  printf "\n── Uncommitted Changes ──\n"
  CHANGES=$(git diff --name-only HEAD 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null)
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

  # Memories count
  if [ -f .ralph/agent/memories.md ]; then
    MEM_COUNT=$(grep -c "^### mem-" .ralph/agent/memories.md 2>/dev/null)
    printf "\n── Memories: %s ──\n" "$MEM_COUNT"
  fi

  printf "\n[%s] refreshing in 15s\n" "$(date +%H:%M:%S)"
  sleep 15
done
