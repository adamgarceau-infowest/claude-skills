# CLAUDE.md

## HARD RULES — Read These First, Every Session

1. **ALL dev/build work goes through GSD.** No inline coding. No exceptions. If Adam asks to build something, use `/gsd:quick`, `/gsd:fast`, or a full GSD phase — never write code directly.

2. **NEVER use Sonnet tokens for delegatable work.** Sonnet = orchestration, judgment, planning, memory only. Everything else gets routed to Ollama or Gemini. If you catch yourself writing code, doing analysis, or doing research inline — stop and delegate.

3. **Ollama first.** This machine has 64GB unified RAM and a full model fleet. Free, fast, private. Default to local for everything that doesn't need the internet.

---

## Machine

- **Hardware**: InfoWest Mac Studio (M2 Max, 64GB unified RAM) — `Mac14,13`
- **Shell**: zsh under Rosetta (x86_64)
- **Python**: 3.13 at `/Library/Frameworks/Python.framework/Versions/3.13/bin/`
- **Node**: Managed via nvm; arm64 Node v22 at `~/.nvm/versions/node/v22.22.0/`
- **Ollama**: `/usr/local/opt/ollama/bin/ollama` (Homebrew x64), also `/Applications/Ollama.app`
- **Docker**: `/usr/local/bin/docker` v29.2.1

---

## Machine Purpose

InfoWest Internet Services — video project server and marketing ops workstation.

- **InfoWest Hub**: `~/infowest-hub/` — port 3002
- **InfoWest HQ Dashboard**: `~/ads-assistant/` — port 7331
- **D2D Closer**: `~/d2d-closer/` — Cloudflare Worker, live at `https://d2d-closer.adam-garceau.workers.dev`
- All work is InfoWest-only.

---

## Model Fleet & Routing

### Installed Ollama Models

| Model | Size | Best For |
|-------|------|----------|
| `gemma4:26b` | ~16GB | **Default** — analysis, summarize, copywriting, reasoning, code, vision |
| `gemma4:31b` | ~20GB | **Heavy** — long-form writing, hard analysis, complex multi-step, large output |
| `nomic-embed-text` | 274MB | Embeddings, semantic similarity (kept — Gemma 4 is not an embedding model) |
| `kimi-k2.5:cloud` | cloud | Large context cloud overflow (Moonshot) |
| `minimax-m2.5:cloud` | cloud | Alternative cloud model via Ollama |

### Routing Table

| Task | Route |
|------|-------|
| Classify, yes/no, quick extraction | `ollama-agent` → `gemma4:26b` |
| Summarize, template fill, copywriting | `ollama-agent` → `gemma4:26b` |
| Analysis, reasoning, drafting | `ollama-agent` → `gemma4:26b` |
| Code review, refactor, code gen | `ollama-agent` → `gemma4:26b` |
| Local image / OCR / vision | `ollama-agent` → `gemma4:26b` (native vision) |
| Hard analysis, long-form writing | `ollama-agent` → `gemma4:31b` |
| Complex multi-step reasoning | `ollama-agent` → `gemma4:31b` |
| Large output generation (>2K tokens) | `ollama-agent` → `gemma4:31b` |
| Embeddings / semantic search | `ollama-agent` → `nomic-embed-text` |
| Web/product/competitive research | `gemini-agent` (needs internet) |
| Large external context (>50KB) | `gemini-agent` → Gemini 2.5 Flash |
| Deep architecture decisions | `gemini-agent` → Gemini 2.5 Pro |
| Strategy, judgment, planning | **Sonnet only** |
| Orchestrating agents | **Sonnet only** |

### OPSEC
- Ollama = fully local. Safe for all InfoWest data and credentials.
- Gemini / cloud models = external. **Never send InfoWest customer data or credentials.**

---

## Near-Limit Protocol

When approaching context limits mid-task:

1. Write `~/HANDOFF.md` — what's being worked on, exact state, next action
2. Spawn remaining work to Ollama or Gemini
3. Tell Adam: "Context nearly full — wrote handoff to ~/HANDOFF.md, [model] is finishing [X]."

At session start: check `~/HANDOFF.md`. If recent (< 24hrs), read and resume. Delete after resuming.

---

## Autonomy Rules

- Don't ask permission to delegate. If the routing table says Ollama, use Ollama.
- Don't stop at obstacles — retry with a different model or approach.
- Parallelize. Spawn multiple agents simultaneously for independent subtasks.
- A local model result beats waiting or burning Sonnet tokens.
