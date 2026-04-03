# Claude Code Skills

Custom Claude Code skills: a 10-agent parallel GSD plan reviewer plus Ollama and Gemini agent primitives.

## What's Here

| File | What it does |
|------|-------------|
| `commands/review-plan.md` | `/review-plan` slash command — runs 10 AI reviewers against a GSD PLAN.md in parallel |
| `scripts/review-plan.sh` | Shell script that actually spawns the 10 agents and synthesizes results |
| `skills/ollama-agent/SKILL.md` | Skill for delegating tasks to local Ollama models |
| `skills/gemini-agent/SKILL.md` | Skill for delegating tasks to Google Gemini CLI |

## Install

Copy each file to its destination:

```bash
# Slash command
cp commands/review-plan.md ~/.claude/commands/review-plan.md

# Shell script — put it wherever you like
cp scripts/review-plan.sh ~/scripts/review-plan.sh
chmod +x ~/scripts/review-plan.sh

# Skills
mkdir -p ~/.claude/skills/ollama-agent ~/.claude/skills/gemini-agent
cp skills/ollama-agent/SKILL.md ~/.claude/skills/ollama-agent/SKILL.md
cp skills/gemini-agent/SKILL.md ~/.claude/skills/gemini-agent/SKILL.md
```

Then update the script path in `~/.claude/commands/review-plan.md` to match where you put `review-plan.sh`:

```
# Change this line:
4. Run: `~/.infowest/cron/review-plan.sh "<plan_file>"`
# To wherever you put it, e.g.:
4. Run: `~/scripts/review-plan.sh "<plan_file>"`
```

## Prerequisites

**For `review-plan`:**
- [Ollama](https://ollama.com) installed and running
- Models pulled (the script uses these — pull any you're missing):
  ```bash
  ollama pull deepseek-r1:32b
  ollama pull qwen2.5-coder:32b
  ollama pull deepseek-coder-v2:16b
  ollama pull llama3.3:70b
  ollama pull qwen2.5:32b
  ```
- `gemini` CLI installed and authenticated (`gemini auth login`)

**For `ollama-agent` skill:**
- Ollama running locally at `http://localhost:11434`

**For `gemini-agent` skill:**
- `gemini` CLI installed at `/usr/local/bin/gemini`
- Authenticated via `gemini auth login`

## Usage

Once installed, in any Claude Code session:

```
/review-plan path/to/PLAN.md
```

Claude will run 10 reviewers in parallel (7 local Ollama models + 3 Gemini calls) and return a synthesized PASS / WARN / BLOCK verdict.
