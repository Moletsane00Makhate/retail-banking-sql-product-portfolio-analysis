-- ============================================================
-- v_customer_accounts_state: account status mix per customer
-- ============================================================
CREATE VIEW IF NOT EXISTS v_customer_accounts_state AS
SELECT
  c.id   AS customer_id,
  COALESCE(c.business_name, TRIM(c.first_name||' '||c.last_name)) AS customer_name,
  c.customer_type,
  SUM(CASE WHEN a.status='ACTIVE'  THEN 1 ELSE 0 END)  AS active_cnt,
  SUM(CASE WHEN a.status='DORMANT' THEN 1 ELSE 0 END) AS dormant_cnt,
  SUM(CASE WHEN a.status='CLOSED'  THEN 1 ELSE 0 END)  AS closed_cnt,
  COUNT(a.id) AS accounts_total,
  ROUND(SUM(CASE WHEN a.account_category='CUSTOMER' THEN a.current_balance ELSE 0 END),2) AS customer_bal_total
FROM customers c
LEFT JOIN accounts a ON a.customer_id = c.id
GROUP BY c.id;

-- ============================================================
-- v_customer_last_activity: last successful transaction date
-- ============================================================
CREATE VIEW IF NOT EXISTS v_customer_last_activity AS
WITH tx AS (
  SELECT
    a.customer_id,
    MAX(DATE(t.posted_at)) AS last_tx_date,
    SUM(CASE WHEN DATE(t.posted_at) >= DATE('now','localtime','-30 days')  AND t.status='SUCCESS' THEN 1 ELSE 0 END) AS tx_30d,
    SUM(CASE WHEN DATE(t.posted_at) >= DATE('now','localtime','-90 days')  AND t.status='SUCCESS' THEN 1 ELSE 0 END) AS tx_90d,
    SUM(CASE WHEN DATE(t.posted_at) >= DATE('now','localtime','-180 days') AND t.status='SUCCESS' THEN 1 ELSE 0 END) AS tx_180d
  FROM transactions t
  JOIN accounts a
    ON a.id IN (t.dr_account_id, t.cr_account_id)
  WHERE a.customer_id IS NOT NULL
  GROUP BY a.customer_id
)
SELECT
  c.id AS customer_id,
  COALESCE(c.business_name, TRIM(c.first_name||' '||c.last_name)) AS customer_name,
  tx.last_tx_date,
  -- days since last successful posting (NULL means no activity yet)
  CASE
    WHEN tx.last_tx_date IS NULL THEN NULL
    ELSE CAST((julianday(DATE('now','localtime')) - julianday(tx.last_tx_date)) AS INTEGER)
  END AS days_since_last_tx,
  tx.tx_30d, tx.tx_90d, tx.tx_180d
FROM customers c
LEFT JOIN tx ON tx.customer_id = c.id;
