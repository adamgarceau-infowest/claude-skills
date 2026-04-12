---
name: gads
description: "Inject InfoWest Google Ads API context — account IDs, Python connection pattern, ad group inventory, call assets, brand rules, and reusable code snippets for managing the IW Residential Search campaign."
---

# /gads — InfoWest Google Ads API Context

When this skill is invoked, load the following as active context for all Google Ads work this session. Use the Python snippets directly — don't rewrite the boilerplate.

---

## Connection

```python
from google.ads.googleads.client import GoogleAdsClient

client = GoogleAdsClient.load_from_storage("/Users/garceau/google-ads.yaml")
CUSTOMER_ID = "3570376140"   # InfoWest MCC child account

# Always run with arm64 Python:
# arch -arm64 /Library/Frameworks/Python.framework/Versions/3.13/bin/python3 script.py
```

**Config file:** `/Users/garceau/google-ads.yaml`
**Login customer ID (MCC):** `3570376140`

---

## Active Campaign

| Field | Value |
|-------|-------|
| Name | IW Residential Internet Search Leads 6APR2026 |
| Campaign ID | `23730625638` |
| Resource name | `customers/3570376140/campaigns/23730625638` |
| Bidding | Maximize Conversions (no tCPA until 50+ conv/30 days) |
| Network | Search only — no Search Partners |
| Location | **Presence only** (not "Presence or interest") |
| Landing page | https://neighbors.infowest.com/residential-internet-page |
| Conversions | Phone calls ≥60s + `ssp_start` form submission |

---

## Ad Group Inventory

| ID | Name | Status | Landing Page |
|----|------|--------|--------------|
| (original) | AG1 - Local Intent | ENABLED | neighbors.infowest.com/residential-internet-page |
| (original) | AG2 - Fiber Internet | PAUSED | neighbors.infowest.com/residential-internet-page |
| (original) | AG3 - Speed & Reliability | PAUSED | neighbors.infowest.com/residential-internet-page |
| (original) | AG4 - Conquest | PAUSED | neighbors.infowest.com/residential-internet-page |
| (original) | AG5 - Price & Plans | PAUSED | neighbors.infowest.com/residential-internet-page |
| (original) | AG6 - Moving / New Service | PAUSED | neighbors.infowest.com/residential-internet-page |
| `193533853845` | AG7 - Business Internet | PAUSED | https://infowest.com/scott/ |
| `194700598026` | AG8 - VoIP / Business Phone | PAUSED | https://infowest.com/service/infowest-voice/ |

**Wave schedule:**
- Wave 1 (now): AG6 + AG2
- Wave 2 (week 2): AG3 + AG5
- Wave 3 (week 3): AG7 + AG8
- Wave 4+ (week 4): AG4 Conquest (60% of AG1 bids)

---

## Call Assets

| Number | Owner | Linked To |
|--------|-------|-----------|
| (435) 674-0165 | Main InfoWest | Campaign-level (all residential AGs) |
| (435) 272-4442 | Scott — Business direct | AG7 + AG8 only |

**Scott's call asset resource name:** `customers/3570376140/assets/348156334746`

---

## Key People

- **Scott Laws** — business sales consultant. Direct line: 435-272-4442. Landing: https://infowest.com/scott/
- **General InfoWest:** (435) 674-0165

---

## Brand Rules (Hard — Violations Get Fixed)

1. **Never name competitors** in ad copy — not TDS, Quantum, CenturyLink, or any ISP. Use "the cable company," "the phone company," "other providers."
2. **Never say "no rate hikes"** or "rates never change." Say: "flat rate, no surprises" / "same bill, month after month."
3. **No "seamless," "robust," "cutting-edge,"** or other marketing filler. Describe what it actually does.
4. Conquest group (AG4) **can bid on competitor branded keywords** — just never mention competitors in ad text.
5. Comparison framing: "InfoWest vs The Cable Company" = fine. "InfoWest vs TDS" = not fine.

---

## Reusable Snippets

### Query — Pull all RSAs with headlines/descriptions
```python
ga_service = client.get_service("GoogleAdsService")
query = """
    SELECT
        ad_group.name,
        ad_group_ad.ad.id,
        ad_group_ad.ad.resource_name,
        ad_group_ad.ad.responsive_search_ad.headlines,
        ad_group_ad.ad.responsive_search_ad.descriptions,
        ad_group_ad.status
    FROM ad_group_ad
    WHERE campaign.id = 23730625638
    AND ad_group_ad.ad.type = RESPONSIVE_SEARCH_AD
"""
for row in ga_service.search(customer_id=CUSTOMER_ID, query=query):
    ag = row.ad_group.name
    ad = row.ad_group_ad.ad
    status = row.ad_group_ad.status.name
    print(f"\n=== {ag} ({status}) ===")
    for h in ad.responsive_search_ad.headlines:
        pin = f" [PIN {h.pinned_field.name}]" if h.pinned_field else ""
        print(f"  H: {h.text}{pin}")
    for d in ad.responsive_search_ad.descriptions:
        print(f"  D: {d.text}")
```

### Update RSA headlines/descriptions
```python
ad_service = client.get_service("AdService")
PIN_H1 = client.enums.ServedAssetFieldTypeEnum.HEADLINE_1

def h(text, pin=None):
    asset = client.get_type("AdTextAsset")
    asset.text = text
    if pin: asset.pinned_field = pin
    return asset

def d(text):
    asset = client.get_type("AdTextAsset")
    asset.text = text
    return asset

op = client.get_type("AdOperation")
ad = op.update
ad.resource_name = "customers/3570376140/ads/AD_ID_HERE"
rsa = ad.responsive_search_ad
rsa.headlines.extend([h("Headline 1", PIN_H1), h("Headline 2"), ...])
rsa.descriptions.extend([d("Description 1"), d("Description 2")])
op.update_mask.paths.extend(["responsive_search_ad.headlines", "responsive_search_ad.descriptions"])

ad_service.mutate_ads(customer_id=CUSTOMER_ID, operations=[op])
```

### Create ad group
```python
ag_service = client.get_service("AdGroupService")
CAMPAIGN_RN = "customers/3570376140/campaigns/23730625638"

op = client.get_type("AdGroupOperation")
ag = op.create
ag.name = "AG9 - New Group Name"
ag.campaign = CAMPAIGN_RN
ag.status = client.enums.AdGroupStatusEnum.PAUSED
ag.type_ = client.enums.AdGroupTypeEnum.SEARCH_STANDARD
ag.cpc_bid_micros = 3_000_000  # $3.00

resp = ag_service.mutate_ad_groups(customer_id=CUSTOMER_ID, operations=[op])
ag_rn = resp.results[0].resource_name
```

### Add keywords
```python
kw_service = client.get_service("AdGroupCriterionService")
EXACT  = client.enums.KeywordMatchTypeEnum.EXACT
PHRASE = client.enums.KeywordMatchTypeEnum.PHRASE
BROAD  = client.enums.KeywordMatchTypeEnum.BROAD

kw_ops = []
for text, match_type in [("keyword text", EXACT), ("phrase match kw", PHRASE)]:
    op = client.get_type("AdGroupCriterionOperation")
    kw = op.create
    kw.ad_group = ag_rn
    kw.status = client.enums.AdGroupCriterionStatusEnum.ENABLED
    kw.keyword.text = text
    kw.keyword.match_type = match_type
    kw_ops.append(op)

kw_service.mutate_ad_group_criteria(customer_id=CUSTOMER_ID, operations=kw_ops)
```

### Add call asset to ad group
```python
asset_service = client.get_service("AssetService")
ag_asset_svc  = client.get_service("AdGroupAssetService")
CALL_FIELD    = client.enums.AssetFieldTypeEnum.CALL

# Create asset
asset_op = client.get_type("AssetOperation")
asset = asset_op.create
asset.name = "Scott Direct — 435-272-4442"
asset.call_asset.country_code = "US"
asset.call_asset.phone_number = "4352724442"

asset_resp = asset_service.mutate_assets(customer_id=CUSTOMER_ID, operations=[asset_op])
asset_rn = asset_resp.results[0].resource_name

# Link to ad group
link_op = client.get_type("AdGroupAssetOperation")
link = link_op.create
link.ad_group = ag_rn
link.asset = asset_rn
link.field_type = CALL_FIELD

ag_asset_svc.mutate_ad_group_assets(customer_id=CUSTOMER_ID, operations=[link_op])
```

### Add negative keywords (campaign-level)
```python
campaign_criterion_service = client.get_service("CampaignCriterionService")
CAMPAIGN_RN = "customers/3570376140/campaigns/23730625638"

neg_ops = []
for kw_text in ["free internet", "jobs", "customer service number"]:
    op = client.get_type("CampaignCriterionOperation")
    neg = op.create
    neg.campaign = CAMPAIGN_RN
    neg.negative = True
    neg.keyword.text = kw_text
    neg.keyword.match_type = client.enums.KeywordMatchTypeEnum.BROAD
    neg_ops.append(op)

campaign_criterion_service.mutate_campaign_criteria(customer_id=CUSTOMER_ID, operations=neg_ops)
```

---

## Character Limits (RSA)

| Field | Max |
|-------|-----|
| Headline | 30 chars |
| Description | 90 chars |
| Max headlines per RSA | 15 |
| Max descriptions per RSA | 4 |
| Min headlines | 3 |
| Min descriptions | 2 |

---

## Notes

- AG1 was the pre-existing ad group — it has weaker copy, clean it up if editing
- AG4 Conquest is Wave 4 — lowest priority, only enable after 50+ conversions in account
- `ssp_start` conversion is a cross-domain event: neighbors.infowest.com → maps.infowest.com — verify GA4 cross-domain linker is active
- Negative keywords (140) were added campaign-level on April 8, 2026
- Bid adjustment: -40% midnight–6am MT (add in UI if not done)
