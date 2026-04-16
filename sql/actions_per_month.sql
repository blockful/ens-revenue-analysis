-- ENS Actions per Month (Registrations, Premiums, Renewals)
-- Sources: v4+v5 NameRegistered (with premium split), v1-v5 NameRenewed
-- Note: v1-v3 NameRegistered don't have premium field, so we count them as standard registrations
-- Note: ens.view_registrations spellbook misses v5, so we query controllers directly

-- v1-v3 registrations (no premium field available)
SELECT date_trunc('month', evt_block_time) AS month, 'Registration' AS category, COUNT(*) AS actions
FROM ethereumnameservice_ethereum.ethregistrarcontroller_1_evt_nameregistered
GROUP BY 1
UNION ALL
SELECT date_trunc('month', evt_block_time), 'Registration', COUNT(*)
FROM ethereumnameservice_ethereum.ethregistrarcontroller_2_evt_nameregistered
GROUP BY 1
UNION ALL
SELECT date_trunc('month', evt_block_time), 'Registration', COUNT(*)
FROM ethereumnameservice_ethereum.ethregistrarcontroller_3_evt_nameregistered
GROUP BY 1

UNION ALL

-- v4 registrations (split by premium)
SELECT date_trunc('month', evt_block_time),
  CASE WHEN CAST(premium AS double) > 0 THEN 'Premium' ELSE 'Registration' END,
  COUNT(*)
FROM ethereumnameservice_ethereum.ethregistrarcontroller_4_evt_nameregistered
GROUP BY 1, 2

UNION ALL

-- v5 registrations (split by premium)
SELECT date_trunc('month', evt_block_time),
  CASE WHEN CAST(premium AS double) > 0 THEN 'Premium' ELSE 'Registration' END,
  COUNT(*)
FROM ethereumnameservice_ethereum.ethregistrarcontroller_5_evt_nameregistered
GROUP BY 1, 2

UNION ALL

-- All renewals (v1-v5)
SELECT date_trunc('month', evt_block_time), 'Renewal', COUNT(*)
FROM ethereumnameservice_ethereum.ethregistrarcontroller_1_evt_namerenewed
GROUP BY 1
UNION ALL
SELECT date_trunc('month', evt_block_time), 'Renewal', COUNT(*)
FROM ethereumnameservice_ethereum.ethregistrarcontroller_2_evt_namerenewed
GROUP BY 1
UNION ALL
SELECT date_trunc('month', evt_block_time), 'Renewal', COUNT(*)
FROM ethereumnameservice_ethereum.ethregistrarcontroller_3_evt_namerenewed
GROUP BY 1
UNION ALL
SELECT date_trunc('month', evt_block_time), 'Renewal', COUNT(*)
FROM ethereumnameservice_ethereum.ethregistrarcontroller_4_evt_namerenewed
GROUP BY 1
UNION ALL
SELECT date_trunc('month', evt_block_time), 'Renewal', COUNT(*)
FROM ethereumnameservice_ethereum.ethregistrarcontroller_5_evt_namerenewed
GROUP BY 1
