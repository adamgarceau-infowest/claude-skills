---
name: iw-checkin
description: "Publish monthly Q2 OKR check-ins to Tability. Pulls call data automatically, asks for fiber installs and 3 manual questions, posts all 8 KRs in one shot."
---

# /iw-checkin — Q2 OKR Monthly Check-In

Pulls IW call data for the month, collects fiber install numbers and 3 manual answers, computes all KR metrics, shows a progress table, and pushes check-ins to all 8 Q2 Tability outcomes in one shot.

**Usage:** `/iw-checkin [--month YYYY-MM]` — defaults to current month if omitted.

---

## Tability Outcome IDs (Q2 2026 Plan: 730c8fb4-a5a6-429d-9720-b8f440cedfe2)

| KR | Outcome ID |
|----|-----------|
| KR1.1 — ≥$18,200 new MRR | `fe05f6c1-3aec-4e94-9ea3-71ae3b4e411a` |
| KR1.2 — ≥16 inbound calls/day | `63195af7-e9d3-42f4-9981-5fe69109649e` |
| KR1.3 — ≥9 new contacts/day | `65583b8b-09a8-486d-846c-58c70f968f21` |
| KR2.1 — Website + packages live by Apr 30 | `dd670b35-192c-4dd8-8fe2-39ed4136fcee` |
| KR2.2 — ≥5 persona campaigns by Jun 30 | `f1da4271-6bef-4241-a9e9-6e785a24b18d` |
| KR3.1 — All Q2 blitz campaigns on schedule | `d451b218-b07f-4de6-a372-e2f6e3937b24` |
| KR3.2 — ≥280 fiber installs in Q2 | `3a4a1894-6771-4c53-8fc4-b11ae7261863` |
| KR3.3 — ≥5.0 installs/day entering Q3 | `0efc889c-8c25-476b-87a3-620f3432eab2` |

---

## Execution Steps

### Step 1 — Determine the month
Parse `--month YYYY-MM` from the command args. If not provided, use today's date to determine the current month. State: "Running check-in for **YYYY-MM**."

Calculate `days_in_month` (actual calendar days, e.g. April = 30).

---

### Step 2 — Pull call data via MCP
Load the `mcp__IW-CallData__Call_Analytics` tool and call it with:
- `type`: "Sales"
- `sections`: "volume"
- Date range: first day of the month through last day of the month (or today if current month)

Extract from the response:
- `inbound_calls` — total inbound calls to the sales queue for the period
- `new_customers` — new customer contacts (look for `nonInteraction`, `new_customers`, or equivalent field)
- `days_covered` — number of days actually in the returned data (use `header.days` or derive from date range)

Compute:
- `inbound_per_day = round(inbound_calls / days_covered, 1)`
- `new_contacts_per_day = round(new_customers / days_covered, 1)`

If call data returns an error or zero calls, note it and proceed — use "N/A" for those KRs.

---

### Step 3 — Pull fiber install data from Hub API

Call the Hub fiber installs API for the target month:
```
GET http://localhost:3002/api/fiber-installs?start=YYYY-MM-01&end=YYYY-MM-DD
```
Use the first day of the month for `start`. For `end`, use the last day of the month (or today if it's the current month).

Extract from the response:
- `monthly_installs = total`
- `days_covered` = number of calendar days between start and end (derive from the dateRange in the response)

Then fetch Q2 running total by calling:
```
GET http://localhost:3002/api/fiber-installs?start=2026-04-01&end=YYYY-MM-DD
```
(Always use April 1 as start for all Q2 months — the endpoint sums all fiber installs in the window, giving a running Q2 total.)

Extract: `q2_running_total = total` from the Q2-range call.

If the API returns an error or total=0 and it's clearly wrong (e.g., April returning 0 when we know there were installs), fall back to asking Adam manually.

Compute:
- `current_daily_rate = round(monthly_installs / days_covered, 1)` (pace for this month)
- `q2_mrr = q2_running_total * 65` (running Q2 MRR at $65 ARPU)

---

### Step 4 — Collect 3 manual answers
Ask Adam in a single message:

> **3 quick questions for check-in:**
> 1. **KR2.1 — Website**: Is the new InfoWest website + all 5 service packages live? (yes / no)
> 2. **KR2.2 — Campaigns**: How many of the 5 persona campaigns are launched? Enter 0–5. (Budget, Family, Tech, Professional, Ultimate)
> 3. **KR3.1 — Blitz on schedule**: Are all Q2 blitz campaigns launching on schedule per the blitz calendar? (yes / no)

---

### Step 5 — Show progress table and confirm
Display this table with the computed values filled in:

```
Q2 OKR Check-In — YYYY-MM
─────────────────────────────────────────────────────
KR      Target              Current         % to Goal
─────────────────────────────────────────────────────
KR1.1   $18,200 Q2 MRR     $X,XXX          XX%
KR1.2   16 inbound/day     X.X/day         XX%
KR1.3   9 contacts/day     X.X/day         XX%
KR2.1   Website live       Yes / No        —
KR2.2   5 campaigns        X/5             XX%
KR3.1   Blitz on schedule  Yes / No        —
KR3.2   280 installs Q2    XX (running)    XX%
KR3.3   5.0/day (Q3 pace)  X.X/day         XX%
─────────────────────────────────────────────────────
```

For percentage calculations:
- KR1.1: `q2_mrr / 18200 * 100`
- KR1.2: `inbound_per_day / 16 * 100`
- KR1.3: `new_contacts_per_day / 9 * 100`
- KR2.2: `campaigns_launched / 5 * 100`
- KR3.2: `q2_running_total / 280 * 100`
- KR3.3: `current_daily_rate / 5.0 * 100`

Then ask: **"Post these to Tability? (yes/no)"**

---

### Step 6 — Push all 8 check-ins
If confirmed, load `mcp__claude_ai_Tability__tability_create_checkin` via ToolSearch if not already loaded.

Fire all 8 in parallel with `workspace_id: "infowest"`:

| Outcome ID | value | notes |
|-----------|-------|-------|
| `fe05f6c1-...` (KR1.1) | `q2_mrr` | "YYYY-MM: Q2 running total {q2_running_total} installs × $65 = ${q2_mrr} MRR" |
| `63195af7-...` (KR1.2) | `inbound_per_day` | "YYYY-MM: {inbound_per_day}/day ({inbound_calls} calls / {days_covered} days)" |
| `65583b8b-...` (KR1.3) | `new_contacts_per_day` | "YYYY-MM: {new_contacts_per_day}/day ({new_customers} new contacts / {days_covered} days)" |
| `dd670b35-...` (KR2.1) | `1` if yes, `0` if no | "Website + service packages live" or "Not yet live as of YYYY-MM" |
| `f1da4271-...` (KR2.2) | campaigns count (0-5) | "{campaigns_launched}/5 persona campaigns launched" |
| `d451b218-...` (KR3.1) | `1` if yes, `0` if no | "Blitz campaigns on schedule" or "Behind schedule as of YYYY-MM" |
| `3a4a1894-...` (KR3.2) | `q2_running_total` | "Q2 running total: {q2_running_total} installs (target: 280)" |
| `0efc889c-...` (KR3.3) | `current_daily_rate` | "Current pace: {current_daily_rate}/day this month (target: 5.0/day entering Q3)" |

---

### Step 7 — Confirm success
After all 8 calls return successfully:

> Check-in posted for YYYY-MM. All 8 KRs updated in Tability.
> View plan: https://tability.app/infowest/plans/730c8fb4-a5a6-429d-9720-b8f440cedfe2

---

## Notes

**Call data baseline:** Feb–Mar 2026 = ~13 inbound/day, ~7 new contacts/day. Jan 2026 data is unreliable (system just coming online).

**Fiber install source:** Hub API at `http://localhost:3002/api/fiber-installs` reads from the `fiber_installs` tab of the Sonar sheet (`1MqGhHWI3WTc7gNh8bNGaJ4TzvxQbKcllH6Pofx5Oqio`). This tab is populated by the n8n "Sonar Fiber Install Tracker" workflow, which receives ZIP exports from Sonar via webhook, filters for GoFiber services, groups by activation date, and upserts daily counts. Fully automated, no manual input needed.

**ARPU:** $65/month flat for all Q2 MRR calculations.

**Q2 date range:** April 1 – June 30, 2026. Running total resets at Q3.
