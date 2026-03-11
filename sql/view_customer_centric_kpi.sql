-- Current balances per customer across all their accounts
CREATE VIEW IF NOT EXISTS v_customer_balances AS
SELECT
  c.id AS customer_id,
  COALESCE(c.business_name, TRIM(c.first_name||' '||c.last_name)) AS customer_name,
  c.customer_type,
  COUNT(a.id) AS accounts,
  ROUND(SUM(CASE WHEN a.account_category='CUSTOMER' THEN a.current_balance ELSE 0 END),2) AS customer_bal_total
FROM customers c
LEFT JOIN accounts a ON a.customer_id = c.id
GROUP BY c.id;

-- Activity in last 12 months (SUCCESS only), by customer
CREATE VIEW IF NOT EXISTS v_customer_activity_12m AS
WITH tx AS (
  SELECT DISTINCT e.customer_id, e.account_id, e.posted_date
  FROM v_tx_enriched e
  WHERE e.customer_id IS NOT NULL
    AND e.status='SUCCESS'
    AND DATE(e.posted_date) >= DATE('now','localtime','-12 months')
)
SELECT
  c.id AS customer_id,
  COALESCE(c.business_name, TRIM(c.first_name||' '||c.last_name)) AS customer_name,
  COUNT(DISTINCT t.account_id) AS active_accounts_12m,
  COUNT(DISTINCT t.posted_date) AS active_days_12m
FROM customers c
LEFT JOIN tx t ON t.customer_id = c.id
GROUP BY c.id
ORDER BY active_days_12m DESC;

-- Potential churn signals: customers whose all accounts are DORMANT/CLOSED
CREATE VIEW IF NOT EXISTS v_customer_inactive AS
WITH states AS (
  SELECT customer_id,
         SUM(CASE WHEN status='ACTIVE' THEN 1 ELSE 0 END)  AS active_cnt,
         SUM(CASE WHEN status='DORMANT' THEN 1 ELSE 0 END) AS dormant_cnt,
         SUM(CASE WHEN status='CLOSED' THEN 1 ELSE 0 END)  AS closed_cnt
  FROM accounts
  WHERE customer_id IS NOT NULL
  GROUP BY customer_id
)
SELECT
  c.id AS customer_id,
  COALESCE(c.business_name, TRIM(c.first_name||' '||c.last_name)) AS customer_name,
  s.active_cnt, s.dormant_cnt, s.closed_cnt
FROM customers c
JOIN states s ON s.customer_id = c.id
WHERE s.active_cnt = 0;  -- no active accounts
