---
name: iw-lp
description: "InfoWest dynamic landing pages — run sync, check status, regenerate content, manage the Cloudflare Worker and Google Ads final URLs for all 8 ad group landing pages."
---

# /iw-lp — InfoWest Landing Page System

## What This System Does

Automatically generates intent-matched landing pages for each Google Ads ad group, deploys
them to Cloudflare Workers, and updates the final URLs on the ads. Runs weekly via cron.

## Live URLs

| Ad Group | Intent | URL |
|----------|--------|-----|
| AG1 Local Intent | local | https://iw-landing-pages.adam-garceau.workers.dev/lp/local |
| AG2 Fiber | fiber | https://iw-landing-pages.adam-garceau.workers.dev/lp/fiber |
| AG3 Speed | speed | https://iw-landing-pages.adam-garceau.workers.dev/lp/speed |
| AG4 Conquest | switch | https://iw-landing-pages.adam-garceau.workers.dev/lp/switch |
| AG5 Price | pricing | https://iw-landing-pages.adam-garceau.workers.dev/lp/pricing |
| AG6 Moving | moving | https://iw-landing-pages.adam-garceau.workers.dev/lp/moving |
| AG7 Business | business | https://iw-landing-pages.adam-garceau.workers.dev/lp/business |
| AG8 VoIP | voip | https://iw-landing-pages.adam-garceau.workers.dev/lp/voip |

**Health check:** https://iw-landing-pages.adam-garceau.workers.dev/lp/_health

**Custom domain (pending):** Once `infowest.com` is proxied through Cloudflare (orange cloud in DNS),
uncomment the `routes` block in `~/iw-landing-pages/wrangler.toml` and `wrangler deploy`.
URLs will then be `neighbors.infowest.com/lp/{intent}`.

## Key Files

| File | Purpose |
|------|---------|
| `~/iw-landing-pages/src/worker.js` | Cloudflare Worker — HTML template + KV lookup |
| `~/iw-landing-pages/wrangler.toml` | Worker config, KV binding |
| `~/.infowest/scripts/iw-lp-sync.py` | Sync script — generates content, pushes KV, updates ad URLs |
| `~/.infowest/cron/lp-sync.sh` | Cron wrapper (runs Monday 7am) |

## KV Namespace

- **Name:** iw-lp-content
- **ID:** `08af35a39d404f62a752a143971e0013`
- **Key format:** `lp:{intent}` (e.g. `lp:fiber`, `lp:moving`)

## Common Commands

### Run full sync (all 8 ad groups)
```bash
arch -arm64 /Library/Frameworks/Python.framework/Versions/3.13/bin/python3 \
  ~/.infowest/scripts/iw-lp-sync.py
```

### Regenerate one intent only
```bash
arch -arm64 /Library/Frameworks/Python.framework/Versions/3.13/bin/python3 \
  ~/.infowest/scripts/iw-lp-sync.py fiber
# Replace fiber with: speed, switch, pricing, moving, business, voip, local
```

### Update Google Ads URLs only (no content regen)
```bash
arch -arm64 /Library/Frameworks/Python.framework/Versions/3.13/bin/python3 \
  ~/.infowest/scripts/iw-lp-sync.py --urls-only
```

### Check what's in KV for an intent
```bash
cd ~/iw-landing-pages && npx wrangler kv key get "lp:fiber" \
  --namespace-id 08af35a39d404f62a752a143971e0013 | python3 -m json.tool | head -20
```

### Manually push content to KV
```bash
cd ~/iw-landing-pages && npx wrangler kv key put "lp:fiber" "$(cat /tmp/fiber.json)" \
  --namespace-id 08af35a39d404f62a752a143971e0013
```

### Deploy Worker changes
```bash
cd ~/iw-landing-pages && npx wrangler deploy
```

### Add custom domain once infowest.com is on Cloudflare
1. Uncomment `routes` in `~/iw-landing-pages/wrangler.toml`
2. `cd ~/iw-landing-pages && npx wrangler deploy`
3. Update `BASE_URL` in `~/.infowest/scripts/iw-lp-sync.py` to `https://neighbors.infowest.com`
4. Run `iw-lp-sync.py --urls-only` to update all Google Ads final URLs

## Content Schema (KV JSON)

```json
{
  "page_title": "string (max 60 chars)",
  "meta_desc": "string (max 155 chars)",
  "h1": "string (max 60 chars — must match search intent)",
  "hero_sub": "string (max 100 chars)",
  "value_points": ["string x4"],
  "features": [{"icon": "emoji", "title": "string", "desc": "string"} x8],
  "faqs": [{"q": "string", "a": "string"} x5],
  "cta_text": "string",
  "cta_sub": "string",
  "final_cta_heading": "string",
  "final_cta_sub": "string"
}
```

## Cron Schedule

`0 7 * * 1` — Monday 7:00 AM (weekly full regeneration)
Logs: `~/.infowest/cron/logs/lp-sync-YYYY-MM-DD.log`

## Ollama Model

Default: `qwen2.5:14b` (reliable JSON output)
Config: `OLLAMA_MODEL` in `iw-lp-sync.py`
Switch to `gemma4:26b` for better quality if it's responding cleanly.

## Brand Rules (always enforced in generation prompts)

- Never name competitors — "the cable company", "other providers"
- Never say "no rate hikes" — say "flat rate, no surprises" / "same bill month after month"
- Warm, local, confident tone — like a trusted neighbor
- Lead with InfoWest strengths, not competitor weaknesses
