# ENS Revenue Analysis

On-chain revenue analysis of the [Ethereum Name Service](https://ens.domains) protocol, covering May 2019 through March 2026. All data is queried directly from decoded contract events on [Dune Analytics](https://dune.com) and cross-validated against [Steakhouse Financial](https://www.steakhouse.financial) (ENS's official financial advisor).

![ENS Actions per Month](charts/1_actions_per_month.png)

![ENS Revenue per Month (USD)](charts/2_revenue_usd_per_month.png)

## Revenue Categories

ENS earns revenue from three on-chain actions:

- **Registration** — base cost paid when a new `.eth` name is registered
- **Premium** — additional cost paid during the temporary premium auction window after a name expires (available from controller v4+)
- **Renewal** — cost paid to extend an existing `.eth` name

Revenue is computed in ETH from contract events and converted to USD using monthly average ETH prices from `prices.usd`.

## Data Sources

All queries target the decoded `NameRegistered` and `NameRenewed` events across ENS registrar controller versions 1 through 5:

| Version | Registration fields | Renewal source | Notes |
|---------|-------------------|----------------|-------|
| v1–v3 | `cost` (combined) | Raw `cost` | No separate premium field; all counted as standard registrations |
| v4 | `baseCost` + `premium` | ENS curated view for Dec 2024–Sep 2025; raw `cost` otherwise | Curated view corrects a known data issue in the v4 renewal cost field |
| v5 | `baseCost` + `premium` | Raw `cost` | |

The Dune spellbook `ens.view_registrations` was intentionally avoided because it misses v5 events.

### Validation

Monthly totals were cross-validated against Steakhouse Financial's CASH accounting data (`dune.steakhouse.result_ens_accounting_revenues`), achieving a **94–102% match** across all months.

## Repository Structure

```
sql/
  actions_per_month.sql        # Action counts by category (registration/premium/renewal)
  revenue_usd_by_category.sql  # Revenue in USD with ETH→USD conversion
  revenue_per_month.sql        # Revenue from Steakhouse accounting (reference)
data/
  actions_per_month.json       # Dune query result export
  revenue_usd_by_category.json # Dune query result export
  premium_proportion.json      # Premium share within registrations
  steakhouse_revenue.json      # Steakhouse accounting data for validation
charts/
  1_actions_per_month.png      # Stacked bar chart of monthly actions
  2_revenue_usd_per_month.png  # Stacked bar chart of monthly revenue (USD)
generate_charts.py             # Python script to regenerate charts from data/
```

## Regenerating Charts

```bash
python -m venv .venv
source .venv/bin/activate
pip install pandas matplotlib
python generate_charts.py
```
