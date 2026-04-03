-- Daily posted volumes & values by channel and status
CREATE VIEW IF NOT EXISTS v_tx_daily_channel AS
SELECT
  DATE(posted_at) AS d,
  channel,
  status,
  COUNT(*) AS tx_count,
  SUM(amount) AS total_amount
FROM transactions
GROUP BY DATE(posted_at), channel, status;

-- Daily net flow per account category (customer vs GL vs suspense)
CREATE VIEW IF NOT EXISTS v_tx_daily_category AS
SELECT
  e.posted_date AS d,
  e.account_category,
  SUM(e.signed_amount) AS net_amount
FROM v_tx_enriched e
WHERE e.status='SUCCESS'
GROUP BY e.posted_date, e.account_category;

-- Monthly branch totals (SUCCESS only)
CREATE VIEW IF NOT EXISTS v_tx_monthly_branch AS
SELECT
  e.posted_ym AS ym,
  e.branch_code,
  COUNT(*) AS tx_count,
  SUM(CASE WHEN e.leg='CR' THEN e.amount ELSE 0 END) AS credited,
  SUM(CASE WHEN e.leg='DR' THEN e.amount ELSE 0 END) AS debited,
  SUM(e.signed_amount) AS net_flow
FROM v_tx_enriched e
WHERE e.status='SUCCESS'
GROUP BY e.posted_ym, e.branch_code
ORDER BY ym DESC, branch_code;
