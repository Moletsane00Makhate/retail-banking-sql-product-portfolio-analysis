-- Transactions at/above suspicious threshold (SUCCESS only)
CREATE VIEW IF NOT EXISTS v_tx_high_amounts AS
SELECT t.*
FROM transactions t
WHERE t.status='SUCCESS'
  AND t.amount >= COALESCE(
        (SELECT CAST(value AS NUMERIC) FROM system_parameters WHERE key='suspicious_threshold_lsl'),
        10000.00
      )
-- TODO: check where customer is an individual not a business
ORDER BY t.amount DESC
LIMIT 1000;

-- Explicit suspicious-flag list (regardless of amount rule evolution)
CREATE VIEW IF NOT EXISTS v_tx_suspicious AS
SELECT *
FROM transactions
WHERE is_suspicious = 1
ORDER BY posted_at DESC;

-- Failure patterns by channel (last 90 days)
CREATE VIEW IF NOT EXISTS v_tx_failures_90d AS
SELECT
  channel,
  COUNT(*) AS tx_count,
  SUM(CASE WHEN status='FAILED' THEN 1 ELSE 0 END) AS failed_count,
  ROUND(100.0 * SUM(CASE WHEN status='FAILED' THEN 1 ELSE 0 END) / COUNT(*), 2) AS fail_rate_pct
FROM transactions
WHERE DATE(posted_at) >= DATE('now','localtime','-90 days')
GROUP BY channel
ORDER BY fail_rate_pct DESC, tx_count DESC;
