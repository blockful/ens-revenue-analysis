-- ENS Monthly Revenue (USD) by Category — Cash Basis
-- Registration: baseCost from all NameRegistered events (verified accurate all versions)
-- Premium: premium field from v4/v5 NameRegistered (v1-v3 lack this field)
-- Renewal: v1/v2/v3/v5 raw cost (accurate) + ENS curated v4 view (corrected)
--          + raw v4 cost for months outside Dec2024-Sep2025 bad window

WITH monthly_eth_price AS (
  SELECT
    date_trunc('month', minute) AS month,
    AVG(price) AS avg_price_usd
  FROM prices.usd
  WHERE blockchain = 'ethereum'
    AND contract_address = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
    AND minute >= TIMESTAMP '2019-05-01'
  GROUP BY 1
),

-- REGISTRATIONS: baseCost from all controllers
-- v1-v3 have a single 'cost' field (includes any premium)
reg_v1 AS (
  SELECT date_trunc('month', evt_block_time) AS month,
    SUM(CAST(cost AS double)/1e18) AS base_eth, 0.0 AS premium_eth
  FROM ethereumnameservice_ethereum.ethregistrarcontroller_1_evt_nameregistered
  GROUP BY 1
),
reg_v2 AS (
  SELECT date_trunc('month', evt_block_time) AS month,
    SUM(CAST(cost AS double)/1e18) AS base_eth, 0.0 AS premium_eth
  FROM ethereumnameservice_ethereum.ethregistrarcontroller_2_evt_nameregistered
  GROUP BY 1
),
reg_v3 AS (
  SELECT date_trunc('month', evt_block_time) AS month,
    SUM(CAST(cost AS double)/1e18) AS base_eth, 0.0 AS premium_eth
  FROM ethereumnameservice_ethereum.ethregistrarcontroller_3_evt_nameregistered
  GROUP BY 1
),
-- v4+v5 have separate baseCost and premium
reg_v45 AS (
  SELECT date_trunc('month', evt_block_time) AS month,
    SUM(CAST(baseCost AS double)/1e18) AS base_eth,
    SUM(CAST(premium AS double)/1e18) AS premium_eth
  FROM ethereumnameservice_ethereum.ethregistrarcontroller_4_evt_nameregistered
  GROUP BY 1
  UNION ALL
  SELECT date_trunc('month', evt_block_time) AS month,
    SUM(CAST(baseCost AS double)/1e18) AS base_eth,
    SUM(CAST(premium AS double)/1e18) AS premium_eth
  FROM ethereumnameservice_ethereum.ethregistrarcontroller_5_evt_nameregistered
  GROUP BY 1
),

all_registrations AS (
  SELECT month, SUM(base_eth) AS base_eth, SUM(premium_eth) AS premium_eth
  FROM (
    SELECT * FROM reg_v1 UNION ALL SELECT * FROM reg_v2
    UNION ALL SELECT * FROM reg_v3 UNION ALL SELECT * FROM reg_v45
  ) t
  GROUP BY 1
),

-- RENEWALS: verified sources only
-- v1/v2/v3/v5: raw cost field (always accurate)
renewal_accurate AS (
  SELECT date_trunc('month', evt_block_time) AS month, SUM(CAST(cost AS double)/1e18) AS renewal_eth
  FROM ethereumnameservice_ethereum.ethregistrarcontroller_1_evt_namerenewed
  GROUP BY 1
  UNION ALL
  SELECT date_trunc('month', evt_block_time), SUM(CAST(cost AS double)/1e18)
  FROM ethereumnameservice_ethereum.ethregistrarcontroller_2_evt_namerenewed
  GROUP BY 1
  UNION ALL
  SELECT date_trunc('month', evt_block_time), SUM(CAST(cost AS double)/1e18)
  FROM ethereumnameservice_ethereum.ethregistrarcontroller_3_evt_namerenewed
  GROUP BY 1
  UNION ALL
  SELECT date_trunc('month', evt_block_time), SUM(CAST(cost AS double)/1e18)
  FROM ethereumnameservice_ethereum.ethregistrarcontroller_5_evt_namerenewed
  GROUP BY 1
),

-- v4: curated view for the BAD window only (Dec 2024 - Sep 2025)
renewal_v4_curated AS (
  SELECT date_trunc('month', evt_block_time) AS month, SUM(CAST(cost AS double)/1e18) AS renewal_eth
  FROM dune.ethereumnameservice.result_ethregistrarcontroller4_namerenewed
  WHERE evt_block_time >= TIMESTAMP '2024-12-01' AND evt_block_time < TIMESTAMP '2025-10-01'
  GROUP BY 1
),

-- v4: raw cost for months OUTSIDE the bad window (cost field is accurate)
renewal_v4_raw AS (
  SELECT date_trunc('month', evt_block_time) AS month, SUM(CAST(cost AS double)/1e18) AS renewal_eth
  FROM ethereumnameservice_ethereum.ethregistrarcontroller_4_evt_namerenewed
  WHERE evt_block_time < TIMESTAMP '2024-12-01' OR evt_block_time >= TIMESTAMP '2025-10-01'
  GROUP BY 1
),

-- Combine v4 renewals
renewal_v4 AS (
  SELECT * FROM renewal_v4_curated
  UNION ALL
  SELECT * FROM renewal_v4_raw
),

all_renewals AS (
  SELECT month, SUM(renewal_eth) AS renewal_eth
  FROM (
    SELECT * FROM renewal_accurate
    UNION ALL
    SELECT * FROM renewal_v4
  ) t
  GROUP BY 1
),

-- COMBINE all revenue
combined AS (
  SELECT
    COALESCE(r.month, n.month) AS month,
    COALESCE(r.base_eth, 0) AS registration_eth,
    COALESCE(r.premium_eth, 0) AS premium_eth,
    COALESCE(n.renewal_eth, 0) AS renewal_eth
  FROM all_registrations r
  FULL OUTER JOIN all_renewals n ON r.month = n.month
)

SELECT
  c.month,
  ROUND(c.registration_eth * p.avg_price_usd, 2) AS registration_usd,
  ROUND(c.premium_eth * p.avg_price_usd, 2) AS premium_usd,
  ROUND(c.renewal_eth * p.avg_price_usd, 2) AS renewal_usd,
  ROUND((c.registration_eth + c.premium_eth + c.renewal_eth) * p.avg_price_usd, 2) AS total_usd,
  ROUND(c.registration_eth, 4) AS registration_eth,
  ROUND(c.premium_eth, 4) AS premium_eth,
  ROUND(c.renewal_eth, 4) AS renewal_eth
FROM combined c
LEFT JOIN monthly_eth_price p ON c.month = p.month
ORDER BY 1
