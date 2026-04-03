---
name: ollama-agent
description: >
  Delegate a task to a local Ollama model as a sub-agent. Use this skill when
  you need fast, free, offline inference for classification, text analysis,
  template filling, structured data extraction, or code tasks. Default is
  qwen2.5:14b. Top local model is qwen3.5:27b for complex reasoning and code.
  Code tasks use deepseek-coder-v2:16b or qwen2.5-coder:14b. Triggers on:
  "use ollama", "ask ollama", "local model", "ollama agent", or PROACTIVELY
  whenever the routing table in CLAUDE.md says to delegate — do not wait to
  be asked.
argument-hint: "[task type: classify | extract | code | summarize | template]"
allowed-tools:
  - Bash
---

# Ollama Agent — Local Sub-Agent Protocol

You are routing a task to a local Ollama model. Follow this protocol to keep
the M4 Pro responsive — pick the smallest model that can do the job.

## Model Selection (M4 Pro — 24GB RAM)

| Model | Size | When to Use |
|-------|------|-------------|
| `qwen2.5:7b` | 4.7GB | Classify, yes/no, simple extraction — fastest |
| `qwen2.5:14b` | 9GB | **Default** — analysis, template fill, summarize |
| `qwen2.5:14b-128k` | 9GB | Same but for long-context input (>8K tokens) |
| `deepseek-coder-v2:16b` | 8.9GB | Code review, refactor, test gen |
| `qwen2.5-coder:14b` | 9GB | Code gen alternative if deepseek hallucinates |
| `gpt-oss:20b` | 13GB | General reasoning step up from 14b |
| `qwen3.5:27b` | 17GB | **Best local model** — complex reasoning, hard multi-step tasks |
| `qwen2.5:32b` | 19GB | Max quality fallback — slow, use only if 27b fails |

**Rule:** Start at `qwen2.5:14b`. Step up only if quality is unacceptable. Step down if speed matters more than quality.

## Task → Model Routing

| Task | Model |
|------|-------|
| Classify anything (business/personal, category, intent) | `qwen2.5:7b` |
| Extract structured fields from text | `qwen2.5:14b` |
| Summarize a document or thread | `qwen2.5:14b` |
| Fill a JSON template from free text | `qwen2.5:14b` |
| Translate short foreign text | `qwen2.5:14b` |
| Review generated code for bugs | `deepseek-coder-v2:16b` |
| Suggest refactor / explain code | `deepseek-coder-v2:16b` |
| Generate short code snippets | `qwen2.5-coder:14b` |
| Complex multi-step reasoning | `qwen3.5:27b` |
| Hard code generation (multi-file logic) | `qwen3.5:27b` |
| Near-limit handoff continuation tasks | `qwen3.5:27b` |

## Calling Protocol

**Always log before and after every call** so the dashboard shows activity:

```bash
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [OLLAMA/qwen2.5:14b] START: TASK_DESCRIPTION" >> ~/.claude/logs/agent-activity.log
# ... run call ...
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [OLLAMA/qwen2.5:14b] ✓ done (${elapsed}s)" >> ~/.claude/logs/agent-activity.log
```

### Standard call
```bash
curl -s http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen2.5:14b",
    "prompt": "YOUR PROMPT",
    "stream": false,
    "options": {"temperature": 0.1, "num_predict": 512}
  }' | python3 -c "import json,sys; print(json.load(sys.stdin)['response'])"
```

### JSON output call (set lower temperature for structure)
```bash
curl -s http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen2.5:14b",
    "prompt": "YOUR PROMPT\n\nOutput raw JSON only. No explanation. No markdown.",
    "stream": false,
    "options": {"temperature": 0.0, "num_predict": 1024}
  }' | python3 -c "import json,sys; r=json.load(sys.stdin)['response']; import re; print(re.sub(r'^\`\`\`(?:json)?\s*|\s*\`\`\`$', '', r.strip(), flags=re.MULTILINE))"
```

### Check Ollama is running
```bash
curl -s http://localhost:11434/api/tags | python3 -c "import json,sys; [print(m['name']) for m in json.load(sys.stdin).get('models',[])]"
```

## Prompt Engineering for Ollama

- **Instruction format:** Qwen and DeepSeek models follow instruction format well. Be terse.
- **JSON:** Explicitly say "Output raw JSON only. No markdown fences. No explanation." and set `temperature: 0.0`
- **Short context:** Keep prompts under 2000 tokens for 7b/14b models — they degrade with very long context
- **One task:** Don't chain multiple asks in one prompt. One prompt = one task.

## Classification Template (Business vs Personal)

```
Classify this purchase as business or personal for a freelance photographer/videographer.

Item: DESCRIPTION
Vendor: VENDOR

Business items: camera bodies, lenses, lights, audio equipment, gimbals, tripods, memory cards, batteries, cables, bags for gear, filters, drones, monitors.
Personal items: food, clothing, personal electronics unrelated to photo/video, household items.

Output JSON: {"is_business": true/false, "confidence": "high/medium/low", "reason": "one sentence"}

Raw JSON only. No explanation.
```

## Extraction Template (Structured Fields from Text)

```
Extract purchase fields from this text. Output JSON matching this schema exactly:
{
  "date": "YYYY-MM-DD or null",
  "vendor": "string or null",
  "invoice_number": "string or null",
  "items": [
    {"description": "string", "amount": float, "currency": "ISO code"}
  ]
}

Text:
---
PASTE TEXT HERE
---

Raw JSON only. No markdown. No explanation.
```

## Processing Ollama Output

1. Parse the response string (already extracted via the python3 pipe)
2. If JSON was requested: strip any stray backticks, then `json.loads()`
3. If analysis: read the text and use the insight directly
4. **Review before trusting:** 7b models occasionally hallucinate field names

## Error Handling

- Connection refused: Ollama not running → `open /Applications/Ollama.app` or `ollama serve`
- Slow response: Swap to smaller model. 32b on battery is very slow.
- Model not found: Run `curl -s http://localhost:11434/api/tags` to list available models
- Garbled JSON: Retry with `temperature: 0.0` and explicit "no markdown" instruction
