-- Channel mix (last 30 days)
CREATE VIEW IF NOT EXISTS v_channel_mix_30d AS
SELECT
  channel,
  COUNT(*) AS tx_count,
  SUM(CASE WHEN status='SUCCESS' THEN 1 ELSE 0 END) AS success_count,
  ROUND(100.0 * SUM(CASE WHEN status='SUCCESS' THEN 1 ELSE 0 END) / COUNT(*), 2) AS success_rate_pct,
  ROUND(AVG(amount),2) AS avg_amount,
  ROUND(SUM(CASE WHEN status='SUCCESS' THEN amount ELSE 0 END),2) AS sum_amount_success
FROM transactions
WHERE DATE(posted_at) >= DATE('now','localtime','-30 days')
GROUP BY channel
ORDER BY tx_count DESC;

-- Initiator mix (who kicks off transactions)
CREATE VIEW IF NOT EXISTS v_initiator_mix AS
SELECT
  initiated_by_type,
  COUNT(*) AS tx_count,
  SUM(CASE WHEN status='SUCCESS' THEN 1 ELSE 0 END) AS success_count
FROM transactions
GROUP BY initiated_by_type
ORDER BY tx_count DESC;

-- Device utilization (ATMs, BNAs, POS) from transactions initiated by devices
CREATE VIEW IF NOT EXISTS v_device_utilization AS
SELECT
  d.device_type,
  d.device_code,
  d.branch_id,
  b.branch_code,
  COUNT(t.id) AS tx_count,
  SUM(CASE WHEN t.status='SUCCESS' THEN 1 ELSE 0 END) AS success_count,
  ROUND(AVG(CASE WHEN t.status='SUCCESS' THEN t.amount END),2) AS avg_amount_success
FROM devices d
LEFT JOIN transactions t
  ON t.initiated_by_type='DEVICE' AND t.initiated_by_id = d.id
LEFT JOIN branches b ON b.id = d.branch_id
GROUP BY d.id
ORDER BY d.device_type, d.device_code;
