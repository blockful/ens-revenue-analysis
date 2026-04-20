-- ENS Renewal Rate per Month (cohort = expiry month)
-- For each event (registration or renewal), the term expires at `expires`.
-- Using LEAD over same label, the term was "renewed" if the next event happens within 90 days
-- of expiry (grace period). Otherwise it churned.
-- Only cohorts whose grace window has closed (expires < now - 90d) are counted.

WITH all_events AS (
  SELECT label AS labelhash, evt_block_time, from_unixtime(CAST(expires AS bigint)) AS expires_dt
  FROM ethereumnameservice_ethereum.ethregistrarcontroller_1_evt_nameregistered
  UNION ALL
  SELECT label, evt_block_time, from_unixtime(CAST(expires AS bigint))
  FROM ethereumnameservice_ethereum.ethregistrarcontroller_1_evt_namerenewed
  UNION ALL
  SELECT label, evt_block_time, from_unixtime(CAST(expires AS bigint))
  FROM ethereumnameservice_ethereum.ethregistrarcontroller_2_evt_nameregistered
  UNION ALL
  SELECT label, evt_block_time, from_unixtime(CAST(expires AS bigint))
  FROM ethereumnameservice_ethereum.ethregistrarcontroller_2_evt_namerenewed
  UNION ALL
  SELECT label, evt_block_time, from_unixtime(CAST(expires AS bigint))
  FROM ethereumnameservice_ethereum.ethregistrarcontroller_3_evt_nameregistered
  UNION ALL
  SELECT label, evt_block_time, from_unixtime(CAST(expires AS bigint))
  FROM ethereumnameservice_ethereum.ethregistrarcontroller_3_evt_namerenewed
  UNION ALL
  SELECT label, evt_block_time, from_unixtime(CAST(expires AS bigint))
  FROM ethereumnameservice_ethereum.ethregistrarcontroller_4_evt_nameregistered
  UNION ALL
  SELECT label, evt_block_time, from_unixtime(CAST(expires AS bigint))
  FROM ethereumnameservice_ethereum.ethregistrarcontroller_4_evt_namerenewed
  UNION ALL
  SELECT labelhash, evt_block_time, from_unixtime(CAST(expires AS bigint))
  FROM ethereumnameservice_ethereum.ethregistrarcontroller_5_evt_nameregistered
  UNION ALL
  SELECT labelhash, evt_block_time, from_unixtime(CAST(expires AS bigint))
  FROM ethereumnameservice_ethereum.ethregistrarcontroller_5_evt_namerenewed
),

with_next AS (
  SELECT
    labelhash,
    evt_block_time,
    expires_dt,
    LEAD(evt_block_time) OVER (PARTITION BY labelhash ORDER BY evt_block_time) AS next_event_time
  FROM all_events
),

classified AS (
  SELECT
    date_trunc('month', expires_dt) AS expiry_month,
    CASE WHEN next_event_time IS NOT NULL
              AND next_event_time <= expires_dt + INTERVAL '90' DAY
         THEN 1 ELSE 0 END AS renewed
  FROM with_next
  WHERE expires_dt < current_timestamp - INTERVAL '90' DAY
)

SELECT
  expiry_month,
  COUNT(*) AS terms_expiring,
  SUM(renewed) AS renewed_count,
  COUNT(*) - SUM(renewed) AS churned_count,
  ROUND(100.0 * SUM(renewed) / COUNT(*), 2) AS renewal_rate_pct
FROM classified
GROUP BY 1
ORDER BY 1
