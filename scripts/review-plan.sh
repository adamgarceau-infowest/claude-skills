#!/usr/bin/env zsh
# review-plan.sh — 10-agent parallel GSD plan reviewer
# Usage: review-plan.sh /path/to/PLAN.md
# Exit: 1 = BLOCK verdict, 0 = PASS or WARN

set -euo pipefail

export PATH="/usr/local/opt/ollama/bin:/usr/local/bin:$PATH"

# --- Input validation ---
if [[ -z "${1:-}" || ! -f "$1" ]]; then
  echo "ERROR: Must provide a valid PLAN.md file path." >&2
  echo "Usage: $(basename "$0") /path/to/PLAN.md" >&2
  exit 1
fi

PLAN_FILE="$1"
PLAN_CONTENT=$(cat "$PLAN_FILE")
TIMESTAMP=$(date +%Y-%m-%d-%H)
REPORT_FILE="$HOME/reports/reviews/${TIMESTAMP}-review.md"
TMPDIR_PID="/tmp/review-$$"
mkdir -p "$TMPDIR_PID"
mkdir -p "$HOME/reports/reviews"

echo "Running 10-agent parallel plan review..." >&2
echo "Plan: $PLAN_FILE" >&2

# --- Reviewer 1: Architect-1 (deepseek-r1:32b, ollama) ---
ollama run deepseek-r1:32b "You are a staff software architect. Review this GSD phase plan for: phase structure, state management, context efficiency, hooks architecture. List issues as CRITICAL, WARN, or NOTE. Be concise.

Review this plan:

$PLAN_CONTENT" > /tmp/review-$$-1.txt 2>&1 &
R1_PID=$!

# --- Reviewer 2: Architect-2 (gemini) ---
if command -v /usr/local/bin/gemini &>/dev/null; then
  echo "$PLAN_CONTENT" | /usr/local/bin/gemini -p "You are a staff software architect. Review this GSD phase plan for: implementability, backwards compatibility, complexity budget, edge cases. List issues as CRITICAL, WARN, or NOTE. Be concise." > /tmp/review-$$-2.txt 2>&1 &
else
  echo "WARNING: gemini binary not found at /usr/local/bin/gemini — skipping Architect-2 review" > /tmp/review-$$-2.txt
fi
R2_PID=$!

# --- Reviewer 3: Engineer-1 (qwen2.5-coder:32b, ollama) ---
ollama run qwen2.5-coder:32b "You are a staff engineer. Review this GSD phase plan for: command quality, new commands, tool permissions, self-repair capability. List issues as CRITICAL, WARN, or NOTE. Be concise.

Review this plan:

$PLAN_CONTENT" > /tmp/review-$$-3.txt 2>&1 &
R3_PID=$!

# --- Reviewer 4: Engineer-2 (deepseek-coder-v2:16b, ollama) ---
ollama run deepseek-coder-v2:16b "You are a staff engineer. Review this GSD phase plan for: hook implementation, settings changes, agent effort estimation, LSP usage, pre-compact behavior. List issues as CRITICAL, WARN, or NOTE. Be concise.

Review this plan:

$PLAN_CONTENT" > /tmp/review-$$-4.txt 2>&1 &
R4_PID=$!

# --- Reviewer 5: Security-1 (deepseek-r1:32b, ollama) ---
ollama run deepseek-r1:32b "You are a staff security engineer. Review this GSD phase plan for: secret scanner patterns, SDK v1 blockers, fail-closed behavior, test quality. List issues as CRITICAL, WARN, or NOTE. Be concise.

Review this plan:

$PLAN_CONTENT" > /tmp/review-$$-5.txt 2>&1 &
R5_PID=$!

# --- Reviewer 6: Security-2 (gemini) ---
if command -v /usr/local/bin/gemini &>/dev/null; then
  echo "$PLAN_CONTENT" | /usr/local/bin/gemini -p "You are a staff security engineer. Review this GSD phase plan for: security veto scenarios, sentinel updates, retro prioritization, hook bypass risks. List issues as CRITICAL, WARN, or NOTE. Be concise." > /tmp/review-$$-6.txt 2>&1 &
else
  echo "WARNING: gemini binary not found at /usr/local/bin/gemini — skipping Security-2 review" > /tmp/review-$$-6.txt
fi
R6_PID=$!

# --- Reviewer 7: Product-1 (llama3.3:70b, ollama) ---
ollama run llama3.3:70b "You are a staff product manager. Review this GSD phase plan for: founder UX, workflow completeness, retro practicality, priority ranking. List issues as CRITICAL, WARN, or NOTE. Be concise.

Review this plan:

$PLAN_CONTENT" > /tmp/review-$$-7.txt 2>&1 &
R7_PID=$!

# --- Reviewer 8: Product-2 (gemini) ---
if command -v /usr/local/bin/gemini &>/dev/null; then
  echo "$PLAN_CONTENT" | /usr/local/bin/gemini -p "You are a staff product manager. Review this GSD phase plan for: adoption risk, measurement, scalability, naming clarity, missing capabilities. List issues as CRITICAL, WARN, or NOTE. Be concise." > /tmp/review-$$-8.txt 2>&1 &
else
  echo "WARNING: gemini binary not found at /usr/local/bin/gemini — skipping Product-2 review" > /tmp/review-$$-8.txt
fi
R8_PID=$!

# --- Reviewer 9: QA-1 (deepseek-coder-v2:16b, ollama) ---
ollama run deepseek-coder-v2:16b "You are a staff QA engineer. Review this GSD phase plan for: test quality, practicality, RED validation, self-repair, retro feedback, smoke tests. List issues as CRITICAL, WARN, or NOTE. Be concise.

Review this plan:

$PLAN_CONTENT" > /tmp/review-$$-9.txt 2>&1 &
R9_PID=$!

# --- Reviewer 10: QA-2 (qwen2.5-coder:32b, ollama) ---
ollama run qwen2.5-coder:32b "You are a staff QA engineer. Review this GSD phase plan for: hook testing, resume edge cases, list edge cases, observation enforcement, sizing accuracy. List issues as CRITICAL, WARN, or NOTE. Be concise.

Review this plan:

$PLAN_CONTENT" > /tmp/review-$$-10.txt 2>&1 &
R10_PID=$!

# --- Wait for all reviewers ---
PIDS=($R1_PID $R2_PID $R3_PID $R4_PID $R5_PID $R6_PID $R7_PID $R8_PID $R9_PID $R10_PID)
echo "Waiting for all 10 reviewers to complete..." >&2
wait "${PIDS[@]}" 2>/dev/null || true
echo "All reviewers complete. Running synthesis..." >&2

# --- Build synthesis input ---
SYNTHESIS_INPUT=""
REVIEWER_NAMES=(
  "Architect-1 (deepseek-r1:32b)"
  "Architect-2 (gemini)"
  "Engineer-1 (qwen2.5-coder:32b)"
  "Engineer-2 (deepseek-coder-v2:16b)"
  "Security-1 (deepseek-r1:32b)"
  "Security-2 (gemini)"
  "Product-1 (llama3.3:70b)"
  "Product-2 (gemini)"
  "QA-1 (deepseek-coder-v2:16b)"
  "QA-2 (qwen2.5-coder:32b)"
)
for i in 1 2 3 4 5 6 7 8 9 10; do
  REVIEWER_IDX=$((i - 1))
  REVIEWER_NAME="${REVIEWER_NAMES[$REVIEWER_IDX]}"
  SYNTHESIS_INPUT+="=== Reviewer $i: $REVIEWER_NAME ===\n$(cat /tmp/review-$$-$i.txt 2>/dev/null || echo 'NO OUTPUT')\n\n"
done

# --- Run synthesizer (qwen2.5:32b) ---
SYNTHESIS=$(echo -e "$SYNTHESIS_INPUT" | /usr/local/opt/ollama/bin/ollama run qwen2.5:32b \
"You are a technical review synthesizer. You have received reviews from 10 AI reviewers.
Synthesize their findings into a final verdict.

Output format (EXACTLY):
VERDICT: PASS|WARN|BLOCK
SUMMARY: <one paragraph>

CRITICAL ISSUES:
- <list any CRITICAL items from reviewers, or 'None'>

WARNINGS:
- <list any WARN items, or 'None'>

Rules:
- BLOCK if ANY reviewer flagged CRITICAL issues
- WARN if warnings exist but no CRITICAL issues
- PASS if only NOTEs or no issues

Be decisive. Do not hedge.")

# --- Build full report ---
REPORT_CONTENT="# Plan Review: $(basename "$PLAN_FILE")
Date: $(date)
Plan: $PLAN_FILE

## Synthesis
$SYNTHESIS

## Reviewer Outputs
"

for i in 1 2 3 4 5 6 7 8 9 10; do
  REVIEWER_IDX=$((i - 1))
  REVIEWER_NAME="${REVIEWER_NAMES[$REVIEWER_IDX]}"
  REPORT_CONTENT+="
### Reviewer $i: $REVIEWER_NAME

$(cat /tmp/review-$$-$i.txt 2>/dev/null || echo 'NO OUTPUT')

---
"
done

echo "$REPORT_CONTENT" > "$REPORT_FILE"

# --- Print synthesis and report path ---
echo ""
echo "========================================"
echo "SYNTHESIS VERDICT"
echo "========================================"
echo "$SYNTHESIS"
echo "========================================"
echo "Report saved to: $REPORT_FILE"

# --- Clean up temp files ---
rm -f /tmp/review-$$-*.txt
rmdir "$TMPDIR_PID" 2>/dev/null || true

# --- Extract verdict and exit appropriately ---
VERDICT=$(echo "$SYNTHESIS" | grep "^VERDICT:" | awk '{print $2}' | tr -d '[:space:]')

if [[ "$VERDICT" == "BLOCK" ]]; then
  echo "EXIT: BLOCK — review found CRITICAL issues. Fix before executing." >&2
  exit 1
elif [[ "$VERDICT" == "PASS" || "$VERDICT" == "WARN" ]]; then
  exit 0
else
  echo "WARNING: Unknown or empty verdict '$VERDICT' — failing open (exit 0)" >&2
  exit 0
fi
