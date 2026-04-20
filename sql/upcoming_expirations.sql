-- ENS Upcoming Expirations by Tenure (next cliff, split by # prior renewals)
-- Method: reuse the "active intervals" construction from active_names_per_month.sql.
-- Within each current interval (end_time > now), count renewal events → tenure.
-- Group future expirations by month and tenure bucket.

WITH all_events AS (
  SELECT label AS labelhash, evt_block_time, from_unixtime(CAST(expires AS bigint)) AS expires_dt, 'register' AS kind
  FROM ethereumnameservice_ethereum.ethregistrarcontroller_1_evt_nameregistered
  UNION ALL
  SELECT label, evt_block_time, from_unixtime(CAST(expires AS bigint)), 'renew'
  FROM ethereumnameservice_ethereum.ethregistrarcontroller_1_evt_namerenewed
  UNION ALL
  SELECT label, evt_block_time, from_unixtime(CAST(expires AS bigint)), 'register'
  FROM ethereumnameservice_ethereum.ethregistrarcontroller_2_evt_nameregistered
  UNION ALL
  SELECT label, evt_block_time, from_unixtime(CAST(expires AS bigint)), 'renew'
  FROM ethereumnameservice_ethereum.ethregistrarcontroller_2_evt_namerenewed
  UNION ALL
  SELECT label, evt_block_time, from_unixtime(CAST(expires AS bigint)), 'register'
  FROM ethereumnameservice_ethereum.ethregistrarcontroller_3_evt_nameregistered
  UNION ALL
  SELECT label, evt_block_time, from_unixtime(CAST(expires AS bigint)), 'renew'
  FROM ethereumnameservice_ethereum.ethregistrarcontroller_3_evt_namerenewed
  UNION ALL
  SELECT label, evt_block_time, from_unixtime(CAST(expires AS bigint)), 'register'
  FROM ethereumnameservice_ethereum.ethregistrarcontroller_4_evt_nameregistered
  UNION ALL
  SELECT label, evt_block_time, from_unixtime(CAST(expires AS bigint)), 'renew'
  FROM ethereumnameservice_ethereum.ethregistrarcontroller_4_evt_namerenewed
  UNION ALL
  SELECT labelhash, evt_block_time, from_unixtime(CAST(expires AS bigint)), 'register'
  FROM ethereumnameservice_ethereum.ethregistrarcontroller_5_evt_nameregistered
  UNION ALL
  SELECT labelhash, evt_block_time, from_unixtime(CAST(expires AS bigint)), 'renew'
  FROM ethereumnameservice_ethereum.ethregistrarcontroller_5_evt_namerenewed
),

with_prev_max AS (
  SELECT *,
    MAX(expires_dt) OVER (
      PARTITION BY labelhash ORDER BY evt_block_time
      ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
    ) AS prev_max_expires
  FROM all_events
),

flagged AS (
  SELECT *,
    CASE WHEN prev_max_expires IS NULL
              OR prev_max_expires + INTERVAL '90' DAY < evt_block_time
         THEN 1 ELSE 0 END AS is_new_interval
  FROM with_prev_max
),

with_interval_id AS (
  SELECT *,
    SUM(is_new_interval) OVER (PARTITION BY labelhash ORDER BY evt_block_time) AS interval_id
  FROM flagged
),

intervals AS (
  SELECT
    labelhash,
    interval_id,
    MIN(evt_block_time) AS start_time,
    MAX(expires_dt) AS end_time,
    SUM(CASE WHEN kind = 'renew' THEN 1 ELSE 0 END) AS renewal_count
  FROM with_interval_id
  GROUP BY labelhash, interval_id
),

-- Active intervals = those whose end_time is still in the future
active_intervals AS (
  SELECT * FROM intervals
  WHERE end_time > current_timestamp
)

SELECT
  date_trunc('month', end_time) AS expiry_month,
  CASE
    WHEN renewal_count = 0 THEN '0 renewals (one-shot)'
    WHEN renewal_count = 1 THEN '1 renewal'
    WHEN renewal_count = 2 THEN '2 renewals'
    ELSE '3+ renewals'
  END AS tenure_bucket,
  COUNT(*) AS names,
  SUM(renewal_count) AS total_renewals_in_bucket
FROM active_intervals
GROUP BY 1, 2
ORDER BY 1, 2
