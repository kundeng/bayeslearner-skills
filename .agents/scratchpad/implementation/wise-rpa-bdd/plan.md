# Plan

1. Step 1 — Polish and validate the existing skill
   - Demo: harness passes 15/15, examples are consistent with generator output, no stale artifacts
   - Wave:
     - Regenerate checked-in examples from source profiles to ensure consistency
     - Clean up __pycache__ and verify .gitignore coverage
     - Run full harness + individual dryrun on all 3 checked-in examples
     - Fix any issues found (missing emit steps, stale output, etc.)

2. Step 2 — Commit the skill
   - Demo: clean atomic commit of `skills/wise-rpa-bdd/` on main branch
   - Wave:
     - Stage all files under skills/wise-rpa-bdd/ (excluding __pycache__)
     - Create commit with descriptive message
