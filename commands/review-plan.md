---
name: review-plan
description: Run 10-agent parallel review on a GSD PLAN.md
argument-hint: "[path/to/PLAN.md]"
allowed-tools:
  - Bash
  - Read
---

Run the 10-agent review on the specified PLAN.md (or the most recently modified one if no path given).

Steps:
1. If $ARGUMENTS is provided and is a valid file path, use it as the plan file.
2. Otherwise, find the most recently modified PLAN.md under .planning/ with:
   `find ~/.planning -name "*-PLAN.md" -type f | xargs ls -t 2>/dev/null | head -1`
   Also check `$(pwd)/.planning/` if the above is empty.
3. If no plan found, report: "No PLAN.md found. Pass a path as argument: /review-plan path/to/PLAN.md"
4. Run: `~/.infowest/cron/review-plan.sh "<plan_file>"`
5. Show the full terminal output including the synthesis.
6. Report the verdict (PASS / WARN / BLOCK) and path to the saved report.
