---
name: gemini-agent
description: >
  Delegate a task to Google Gemini CLI as a sub-agent. Use this skill when you
  need to offload token-heavy or vision work to Gemini to conserve Anthropic
  credits. Best for: generating large code files from a spec, OCR on receipt
  images, architecture review, documentation generation, translating foreign
  text, and any task with a large context. Also used for near-limit handoff
  continuation — when Claude context is nearly full, Gemini picks up remaining
  delegatable work and keeps things moving. Triggers on: "use gemini", "ask
  gemini", "have gemini", "delegate to gemini", "gemini agent", or PROACTIVELY
  whenever the routing table in CLAUDE.md says to delegate — do not wait to
  be asked. Gemini has 1M token context — use it for large tasks aggressively.
argument-hint: "[task description or @image-path]"
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
---

# Gemini Agent — Sub-Agent Protocol

You are routing a task to Google Gemini CLI. Follow this protocol exactly.

## When to Use Gemini

| Task Type | Why Gemini |
|-----------|-----------|
| Generate a full module/file from spec | Large output, saves Anthropic tokens |
| Receipt/image OCR | Vision model, reads JPG/PNG natively |
| Translate Japanese/foreign text | Gemini Flash handles multilingual well |
| Resolve product codes → full names | Knowledge base lookups |
| Architecture or code review | Large context window |
| Write documentation or README | Long-form generation |

**Do NOT use Gemini for:** quick inline edits, decisions requiring your own judgment, anything you can do in <10 lines yourself.

## Model Selection

Pick the right model — all must be logged to the dashboard.

| Model | When to use |
|-------|-------------|
| `gemini-3-flash-preview` | **Default** — fast, capable, vision, most tasks |
| `gemini-3-pro-preview` | Hard reasoning, ambiguous specs, architecture decisions (may 429, retries auto) |
| `gemini-2.5-flash` | Fallback if Gemini 3 capacity is exhausted |
| `gemini-2.5-pro` | Fallback for complex tasks if Gemini 3 Pro is unavailable |

**Decision guide:**
- OCR, translation, code gen, summaries → `gemini-3-flash-preview`
- Architecture decisions, deep analysis, multi-file reasoning → `gemini-3-pro-preview`
- 429 errors persist after 3 retries → fall back to `gemini-2.5-flash` / `gemini-2.5-pro`

## Calling Protocol

**Always log before and after every call** — this is how the dashboard shows agent activity. Replace `MODEL` and `TASK_DESCRIPTION` with actual values.

```bash
mkdir -p ~/.claude/logs

# Log start
_MODEL="gemini-3-flash-preview"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [GEMINI/$_MODEL] START: TASK_DESCRIPTION" >> ~/.claude/logs/agent-activity.log

# Run task
_t0=$SECONDS
_result=$(gemini --model "$_MODEL" -p "YOUR PROMPT" 2>/dev/null \
  | grep -v "^Loaded cached credentials" \
  | grep -v "^Warning:")

# Log result
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [GEMINI/$_MODEL] ✓ done ($(($SECONDS - _t0))s)" >> ~/.claude/logs/agent-activity.log
echo "$_result"
```

### Text task (one-liner form)
```bash
gemini --model gemini-3-flash-preview -p "YOUR PROMPT" 2>/dev/null | grep -v "^Loaded cached credentials" | grep -v "^Warning:"
```

### Vision task (receipt image, diagram, screenshot)
```bash
gemini --model gemini-3-flash-preview -p "YOUR PROMPT @/absolute/path/to/image.jpg" 2>/dev/null | grep -v "^Loaded cached credentials" | grep -v "^Warning:"
```

### JSON output task
Append to your prompt: `"Output raw JSON only, no markdown fences, no explanation."`
Then strip any stray fences from the result:
```bash
... | sed '/^```/d'
```

## Prompt Engineering for Gemini

- **Be direct:** State the task in the first sentence. No preamble.
- **Specify output format:** "Output only Python code", "Return a JSON array", "Write the full file with no truncation"
- **No truncation:** Add "Write the complete file. Do not truncate or summarize." for code generation
- **Context injection:** Include relevant types/interfaces inline in the prompt — Gemini has no access to your repo

## Receipt OCR Prompt Template

Use this exact prompt structure for gear receipt images:

```
Extract all line items from this receipt image. For each item output a JSON array where each element has:
date (YYYY-MM-DD), vendor (string), invoice_number (string), description (full English name — translate Japanese, resolve product codes like "56MMF1.4DC" to "Sigma 56mm f/1.4 DC DN Contemporary"), subtotal (float USD), tax (float USD), shipping (float USD), original_currency (ISO code), original_amount (float in original currency), is_business (bool — true for camera/video gear), notes (string or null).

Tax-free purchases: tax = 0. If currency is not USD, set original_currency and original_amount; subtotal stays as original amount (currency conversion happens separately).

Output raw JSON array only. No markdown fences. No explanation.
@/path/to/receipt.jpg
```

## Processing Gemini Output

After running the Bash call, you receive raw text. Your job:
1. If JSON was requested: parse it, validate keys, use as data
2. If code was requested: review it, then write to file with the Write tool
3. If analysis was requested: read it, extract the insight, continue your work
4. **Always review Gemini output before writing to disk** — it may have minor errors

## Error Handling

- **429 / MODEL_CAPACITY_EXHAUSTED** on `gemini-3-pro-preview`: Expected — the CLI auto-retries with backoff. Wait it out (usually <30s). If it fails after 3 attempts, fall back to `gemini-2.5-pro` and log the fallback.
- **404 / ModelNotFoundError**: Wrong model string. Use exact strings from the table above — `gemini-3-flash-preview`, `gemini-3-pro-preview`.
- **Auth error / returncode != 0**: Tell user to run `gemini` interactively to re-auth via OAuth.
- **Empty output**: Prompt may have been filtered. Rephrase without sensitive-looking keywords.
- **Truncated code**: Add "Do not truncate. Write the complete file." to prompt and retry.
- **Bad JSON**: Validate with `python3 -c "import json,sys; json.load(sys.stdin)"`, fix manually if needed.
