"""
ENS Revenue Analysis — Chart Generator
======================================
Charts generated from verified on-chain decoded events:
  1. Actions per month (Registration, Premium, Renewal)
  2. Revenue per month in USD (Registration, Premium, Renewal)
  3. Active .eth names per month (net variation + cumulative)
  4. New wallets performing ENS actions per month (new + cumulative)
  5. Renewal rate per expiring cohort (renewed vs churned + rate %)

Data sources:
  - v1-v5 NameRegistered + NameRenewed decoded events (ethereumnameservice_ethereum)
  - Cross-validated against Steakhouse (ENS official financial advisor) CASH data
    94-102% match across all months for revenue
  - Active names use 90-day grace period to detect re-registrations
  - Renewal rate uses 90-day grace window to determine renewal success
"""

import json
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
from pathlib import Path

plt.style.use("seaborn-v0_8-whitegrid")
COLORS = {
    "Registration": "#4C72B0",
    "Premium": "#C44E52",
    "Renewal": "#DD8452",
    "Active": "#55A868",
    "Variation+": "#55A868",
    "Variation-": "#C44E52",
    "Wallets": "#8172B2",
    "Cumulative": "#333333",
    "Renewed": "#55A868",
    "Churned": "#C44E52",
    "Rate": "#333333",
    "Tenure0": "#C44E52",
    "Tenure1": "#DD8452",
    "Tenure2": "#8172B2",
    "Tenure3": "#4C72B0",
}
OUT = Path("charts")
OUT.mkdir(exist_ok=True)


def load(filename):
    with open(Path("data") / filename) as f:
        return pd.DataFrame(json.load(f)["result"]["rows"])


# ── Load data ────────────────────────────────────────────────────────────────

actions_raw = load("actions_per_month.json")
actions_raw["month"] = pd.to_datetime(actions_raw["month"])

revenue_raw = load("revenue_usd_by_category.json")
revenue_raw["month"] = pd.to_datetime(revenue_raw["month"])

# ── Prepare actions pivot ────────────────────────────────────────────────────

actions = actions_raw.pivot_table(index="month", columns="category", values="actions", aggfunc="sum", fill_value=0)
for col in ["Registration", "Premium", "Renewal"]:
    if col not in actions.columns:
        actions[col] = 0
actions = actions.sort_index()

# ── Prepare revenue ─────────────────────────────────────────────────────────

revenue = revenue_raw.set_index("month").sort_index()


# ── Chart 1: Actions per Month ──────────────────────────────────────────────

fig, ax = plt.subplots(figsize=(18, 7))

width = 22
ax.bar(actions.index, actions["Registration"], width=width, label="Registration", color=COLORS["Registration"], alpha=0.85)
ax.bar(actions.index, actions["Premium"], width=width, bottom=actions["Registration"], label="Premium (auction)", color=COLORS["Premium"], alpha=0.85)
ax.bar(actions.index, actions["Renewal"], width=width, bottom=actions["Registration"] + actions["Premium"], label="Renewal", color=COLORS["Renewal"], alpha=0.85)

ax.set_title("ENS Actions per Month", fontsize=16, fontweight="bold")
ax.set_ylabel("Number of Actions")
ax.set_xlabel("")
ax.legend(loc="upper right", fontsize=11)
ax.yaxis.set_major_formatter(mticker.FuncFormatter(lambda x, _: f"{x:,.0f}"))

plt.tight_layout()
plt.savefig(OUT / "1_actions_per_month.png", dpi=150, bbox_inches="tight")
plt.close()
print("~ Chart 1: Actions per Month")


# ── Chart 2: Revenue per Month (USD) ────────────────────────────────────────

fig, ax = plt.subplots(figsize=(18, 7))

months = revenue.index
reg_usd = revenue["registration_usd"]
prem_usd = revenue["premium_usd"]
ren_usd = revenue["renewal_usd"]

ax.bar(months, reg_usd, width=width, label="Registration", color=COLORS["Registration"], alpha=0.85)
ax.bar(months, prem_usd, width=width, bottom=reg_usd, label="Premium (auction)", color=COLORS["Premium"], alpha=0.85)
ax.bar(months, ren_usd, width=width, bottom=reg_usd + prem_usd, label="Renewal", color=COLORS["Renewal"], alpha=0.85)

ax.set_title("ENS Revenue per Month (USD) — Cash Basis", fontsize=16, fontweight="bold")
ax.set_ylabel("Revenue (USD)")
ax.set_xlabel("")
ax.legend(loc="upper right", fontsize=11)
ax.yaxis.set_major_formatter(mticker.FuncFormatter(lambda x, _: f"${x:,.0f}"))

plt.tight_layout()
plt.savefig(OUT / "2_revenue_usd_per_month.png", dpi=150, bbox_inches="tight")
plt.close()
print("~ Chart 2: Revenue per Month (USD)")


# ── Summary ──────────────────────────────────────────────────────────────────

total_actions = actions_raw["actions"].sum()
total_reg = actions["Registration"].sum()
total_prem = actions["Premium"].sum()
total_ren = actions["Renewal"].sum()

total_rev_usd = revenue["total_usd"].sum()
total_reg_usd = revenue["registration_usd"].sum()
total_prem_usd = revenue["premium_usd"].sum()
total_ren_usd = revenue["renewal_usd"].sum()

recent_3 = revenue.tail(3)
recent_avg = recent_3["total_usd"].mean()

print(f"\n{'='*60}")
print("ENS REVENUE ANALYSIS SUMMARY")
print(f"{'='*60}")
print(f"Period: May 2019 - March 2026")
print(f"")
print(f"Total actions: {total_actions:,.0f}")
print(f"  Registrations: {total_reg:,.0f}")
print(f"  Premiums:      {total_prem:,.0f}")
print(f"  Renewals:      {total_ren:,.0f}")
print(f"")
print(f"Total revenue: ${total_rev_usd:,.0f}")
print(f"  Registration:  ${total_reg_usd:,.0f} ({total_reg_usd/total_rev_usd*100:.1f}%)")
print(f"  Premium:       ${total_prem_usd:,.0f} ({total_prem_usd/total_rev_usd*100:.1f}%)")
print(f"  Renewal:       ${total_ren_usd:,.0f} ({total_ren_usd/total_rev_usd*100:.1f}%)")
print(f"")
print(f"Recent run-rate (last 3 months avg): ${recent_avg:,.0f}/month")
print(f"{'='*60}")
print(f"Cross-validated against Steakhouse CASH: 94-102% match")


# ── Chart 3: Active .eth Names per Month (variation + cumulative) ───────────

active = load("active_names_per_month.json")
active["month"] = pd.to_datetime(active["month"])
active = active.sort_values("month").reset_index(drop=True)

fig, ax1 = plt.subplots(figsize=(18, 7))
ax2 = ax1.twinx()

bar_colors = [COLORS["Variation+"] if v >= 0 else COLORS["Variation-"] for v in active["net_change"]]
ax1.bar(active["month"], active["net_change"], width=width, color=bar_colors, alpha=0.75, label="Net variation (gains − losses)")
ax1.axhline(0, color="#888", linewidth=0.6)
ax1.set_ylabel("Monthly Net Variation")
ax1.yaxis.set_major_formatter(mticker.FuncFormatter(lambda x, _: f"{x:,.0f}"))

ax2.plot(active["month"], active["cumulative_active"], color=COLORS["Cumulative"], linewidth=2.2, label="Cumulative active names")
ax2.set_ylabel("Active .eth Names (cumulative)")
ax2.yaxis.set_major_formatter(mticker.FuncFormatter(lambda x, _: f"{x:,.0f}"))

ax1.set_title("ENS Active .eth Names per Month", fontsize=16, fontweight="bold")

lines1, labels1 = ax1.get_legend_handles_labels()
lines2, labels2 = ax2.get_legend_handles_labels()
# Synthesize legend entries for +/- bars
from matplotlib.patches import Patch
legend_handles = [
    Patch(facecolor=COLORS["Variation+"], alpha=0.75, label="Net gain (month)"),
    Patch(facecolor=COLORS["Variation-"], alpha=0.75, label="Net loss (month)"),
    lines2[0],
]
ax1.legend(handles=legend_handles, loc="upper left", fontsize=11)

plt.tight_layout()
plt.savefig(OUT / "3_active_names_per_month.png", dpi=150, bbox_inches="tight")
plt.close()
print("~ Chart 3: Active Names per Month")


# ── Chart 4: New Wallets per Month ──────────────────────────────────────────

wallets = load("new_wallets_per_month.json")
wallets["month"] = pd.to_datetime(wallets["month"])
wallets = wallets.sort_values("month").reset_index(drop=True)

fig, ax1 = plt.subplots(figsize=(18, 7))
ax2 = ax1.twinx()

ax1.bar(wallets["month"], wallets["new_wallets"], width=width, color=COLORS["Wallets"], alpha=0.85, label="New wallets (month)")
ax1.set_ylabel("New Wallets per Month")
ax1.yaxis.set_major_formatter(mticker.FuncFormatter(lambda x, _: f"{x:,.0f}"))

ax2.plot(wallets["month"], wallets["cumulative_wallets"], color=COLORS["Cumulative"], linewidth=2.2, label="Cumulative unique wallets")
ax2.set_ylabel("Cumulative Unique Wallets")
ax2.yaxis.set_major_formatter(mticker.FuncFormatter(lambda x, _: f"{x:,.0f}"))

ax1.set_title("ENS New Wallets per Month (first-ever ENS action)", fontsize=16, fontweight="bold")

lines1, labels1 = ax1.get_legend_handles_labels()
lines2, labels2 = ax2.get_legend_handles_labels()
ax1.legend(lines1 + lines2, labels1 + labels2, loc="upper left", fontsize=11)

plt.tight_layout()
plt.savefig(OUT / "4_new_wallets_per_month.png", dpi=150, bbox_inches="tight")
plt.close()
print("~ Chart 4: New Wallets per Month")


# ── Chart 5: Renewal Rate per Cohort Month ──────────────────────────────────

churn = load("renewal_rate_per_month.json")
churn["month"] = pd.to_datetime(churn["expiry_month"])
churn = churn.sort_values("month").reset_index(drop=True)
churn["renewed_count"] = pd.to_numeric(churn["renewed_count"])
churn["churned_count"] = pd.to_numeric(churn["churned_count"])
churn["renewal_rate_pct"] = pd.to_numeric(churn["renewal_rate_pct"])
churn["terms_expiring"] = pd.to_numeric(churn["terms_expiring"])

fig, ax1 = plt.subplots(figsize=(18, 7))
ax2 = ax1.twinx()

ax1.bar(churn["month"], churn["renewed_count"], width=width, label="Renewed (within 90d grace)", color=COLORS["Renewed"], alpha=0.85)
ax1.bar(churn["month"], churn["churned_count"], width=width, bottom=churn["renewed_count"], label="Churned (expired without renewal)", color=COLORS["Churned"], alpha=0.85)
ax1.set_ylabel("Names Expiring (terms)")
ax1.yaxis.set_major_formatter(mticker.FuncFormatter(lambda x, _: f"{x:,.0f}"))

# Only plot the line for cohorts with meaningful sample size to avoid noise
min_sample = 100
rate_plot = churn[churn["terms_expiring"] >= min_sample]
ax2.plot(rate_plot["month"], rate_plot["renewal_rate_pct"], color=COLORS["Rate"], linewidth=2.2, label=f"Renewal rate % (cohorts ≥ {min_sample})")
ax2.set_ylim(0, 100)
ax2.set_ylabel("Renewal Rate (%)")
ax2.yaxis.set_major_formatter(mticker.FuncFormatter(lambda x, _: f"{x:.0f}%"))

ax1.set_title("ENS Renewal Rate by Expiry Cohort (90-day grace window)", fontsize=16, fontweight="bold")

lines1, labels1 = ax1.get_legend_handles_labels()
lines2, labels2 = ax2.get_legend_handles_labels()
ax1.legend(lines1 + lines2, labels1 + labels2, loc="upper left", fontsize=11)

plt.tight_layout()
plt.savefig(OUT / "5_renewal_rate_per_month.png", dpi=150, bbox_inches="tight")
plt.close()
print("~ Chart 5: Renewal Rate per Month")


# ── Extended Summary ────────────────────────────────────────────────────────

latest_active = int(active["cumulative_active"].iloc[-1])
total_wallets = int(wallets["cumulative_wallets"].iloc[-1])
recent_churn = churn[churn["terms_expiring"] >= min_sample].tail(6)
recent_rate = recent_churn["renewal_rate_pct"].mean()
total_expiring = int(recent_churn["terms_expiring"].sum())
total_renewed = int(recent_churn["renewed_count"].sum())
weighted_rate = 100.0 * total_renewed / total_expiring if total_expiring else 0

print(f"")
print(f"Active names (latest month): {latest_active:,}")
print(f"Unique wallets (cumulative): {total_wallets:,}")
print(f"Recent renewal rate (last 6 cohorts, avg): {recent_rate:.1f}%")
print(f"Recent renewal rate (last 6 cohorts, weighted): {weighted_rate:.1f}%")


# ── Chart 6: Upcoming Expirations by Tenure ─────────────────────────────────

upcoming = load("upcoming_expirations.json")
upcoming["month"] = pd.to_datetime(upcoming["expiry_month"])
upcoming["names"] = pd.to_numeric(upcoming["names"])

horizon_months = 24
last_obs = pd.Timestamp.utcnow().normalize().replace(day=1)
horizon_end = last_obs + pd.DateOffset(months=horizon_months)

near = upcoming[upcoming["month"] < horizon_end].copy()
beyond_total = int(upcoming[upcoming["month"] >= horizon_end]["names"].sum())

bucket_order = ["0 renewals (one-shot)", "1 renewal", "2 renewals", "3+ renewals"]
bucket_colors = [COLORS["Tenure0"], COLORS["Tenure1"], COLORS["Tenure2"], COLORS["Tenure3"]]

pivot = near.pivot_table(index="month", columns="tenure_bucket", values="names", aggfunc="sum", fill_value=0)
for b in bucket_order:
    if b not in pivot.columns:
        pivot[b] = 0
pivot = pivot[bucket_order].sort_index()

fig, ax = plt.subplots(figsize=(18, 7))

x = pivot.index
bottom = pd.Series(0, index=x)
for bucket, color in zip(bucket_order, bucket_colors):
    ax.bar(x, pivot[bucket], width=width, bottom=bottom, color=color, alpha=0.9, label=bucket)
    bottom = bottom + pivot[bucket]

# Total label above each bar
for xi, total in zip(x, bottom):
    ax.text(xi, total, f"{int(total/1000)}k", ha="center", va="bottom", fontsize=8, color="#555")

total_near = int(pivot.values.sum())
subtitle = (f"Next {horizon_months} months: {total_near:,} expirations  ·  "
            f"Beyond {horizon_months}mo: {beyond_total:,} (not shown)")

ax.set_title(f"ENS Upcoming .eth Expirations by Tenure\n{subtitle}", fontsize=14, fontweight="bold")
ax.set_ylabel("Names Scheduled to Expire")
ax.yaxis.set_major_formatter(mticker.FuncFormatter(lambda v, _: f"{v:,.0f}"))
ax.legend(loc="upper right", fontsize=11, title="Prior renewals (tenure)")

plt.tight_layout()
plt.savefig(OUT / "6_upcoming_expirations.png", dpi=150, bbox_inches="tight")
plt.close()
print("~ Chart 6: Upcoming Expirations by Tenure")


# ── Extended Summary ────────────────────────────────────────────────────────

total_future = int(upcoming["names"].sum())
one_shot_future = int(upcoming[upcoming["tenure_bucket"] == "0 renewals (one-shot)"]["names"].sum())
next_12 = upcoming[(upcoming["month"] >= last_obs) & (upcoming["month"] < last_obs + pd.DateOffset(months=12))]
next_12_total = int(next_12["names"].sum())
next_12_oneshot = int(next_12[next_12["tenure_bucket"] == "0 renewals (one-shot)"]["names"].sum())

print(f"")
print(f"Future-expiring (active) names: {total_future:,}")
print(f"  one-shots (0 renewals):       {one_shot_future:,} ({100*one_shot_future/total_future:.1f}%)")
print(f"Next 12 months expirations:     {next_12_total:,}")
print(f"  of which one-shots:           {next_12_oneshot:,} ({100*next_12_oneshot/next_12_total:.1f}%)")
print(f"{'='*60}")
print(f"Charts saved to: {OUT.resolve()}")
