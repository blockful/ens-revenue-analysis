-- ENS New Wallets per Month
-- Counts each wallet by the month of its FIRST ENS action (NameRegistered or NameRenewed, v1-v5).
-- Uses evt_tx_from so both registrations and renewals count wallets that took action.

WITH all_actions AS (
  SELECT evt_block_time, evt_tx_from AS wallet
  FROM ethereumnameservice_ethereum.ethregistrarcontroller_1_evt_nameregistered
  UNION ALL
  SELECT evt_block_time, evt_tx_from
  FROM ethereumnameservice_ethereum.ethregistrarcontroller_1_evt_namerenewed
  UNION ALL
  SELECT evt_block_time, evt_tx_from
  FROM ethereumnameservice_ethereum.ethregistrarcontroller_2_evt_nameregistered
  UNION ALL
  SELECT evt_block_time, evt_tx_from
  FROM ethereumnameservice_ethereum.ethregistrarcontroller_2_evt_namerenewed
  UNION ALL
  SELECT evt_block_time, evt_tx_from
  FROM ethereumnameservice_ethereum.ethregistrarcontroller_3_evt_nameregistered
  UNION ALL
  SELECT evt_block_time, evt_tx_from
  FROM ethereumnameservice_ethereum.ethregistrarcontroller_3_evt_namerenewed
  UNION ALL
  SELECT evt_block_time, evt_tx_from
  FROM ethereumnameservice_ethereum.ethregistrarcontroller_4_evt_nameregistered
  UNION ALL
  SELECT evt_block_time, evt_tx_from
  FROM ethereumnameservice_ethereum.ethregistrarcontroller_4_evt_namerenewed
  UNION ALL
  SELECT evt_block_time, evt_tx_from
  FROM ethereumnameservice_ethereum.ethregistrarcontroller_5_evt_nameregistered
  UNION ALL
  SELECT evt_block_time, evt_tx_from
  FROM ethereumnameservice_ethereum.ethregistrarcontroller_5_evt_namerenewed
),

first_action AS (
  SELECT wallet, MIN(evt_block_time) AS first_time
  FROM all_actions
  WHERE wallet IS NOT NULL
  GROUP BY wallet
),

monthly AS (
  SELECT date_trunc('month', first_time) AS month, COUNT(*) AS new_wallets
  FROM first_action
  GROUP BY 1
)

SELECT
  month,
  new_wallets,
  SUM(new_wallets) OVER (ORDER BY month ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_wallets
FROM monthly
ORDER BY month
