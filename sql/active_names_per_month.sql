-- ENS Active .eth Names per Month (variation + cumulative)
-- Method: build per-name "active intervals" from v1-v5 NameRegistered + NameRenewed events.
-- An event continues the prior interval if it happens within 90 days (grace) of the prior max expires;
-- otherwise it starts a new interval (treated as a re-registration).
-- Each interval contributes +1 at start month and -1 at (end month + 1); cumulative sum = active count.

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

with_prev_max AS (
  SELECT
    labelhash,
    evt_block_time,
    expires_dt,
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
    MAX(expires_dt) AS end_time
  FROM with_interval_id
  GROUP BY labelhash, interval_id
),

deltas AS (
  SELECT date_trunc('month', start_time) AS month, 1 AS delta
  FROM intervals
  UNION ALL
  SELECT date_trunc('month', end_time) + INTERVAL '1' MONTH AS month, -1 AS delta
  FROM intervals
  WHERE end_time < current_timestamp
),

monthly_delta AS (
  SELECT month, SUM(delta) AS net_change
  FROM deltas
  GROUP BY month
)

SELECT
  month,
  net_change,
  SUM(net_change) OVER (ORDER BY month ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_active
FROM monthly_delta
WHERE month <= current_timestamp
ORDER BY month
