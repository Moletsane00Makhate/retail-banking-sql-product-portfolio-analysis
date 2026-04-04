-- ============================================================
-- v_churn_by_branch
-- ============================================================
CREATE VIEW IF NOT EXISTS v_churn_by_branch AS
WITH cust_branch AS (
  -- Assign customer to the branch where they hold the most accounts (tie-breaker: lowest branch_id)
  SELECT
    a.customer_id,
    a.branch_id,
    COUNT(*) AS accts_at_branch,
    ROW_NUMBER() OVER (PARTITION BY a.customer_id ORDER BY COUNT(*) DESC, a.branch_id) AS rn
  FROM accounts a
  WHERE a.customer_id IS NOT NULL
  GROUP BY a.customer_id, a.branch_id
)
SELECT
  b.branch_code,
  f.churn_segment,
  COUNT(*) AS customers
FROM v_customer_churn_flags f
LEFT JOIN cust_branch cb
  ON cb.customer_id = f.customer_id AND cb.rn = 1
LEFT JOIN branches b ON b.id = cb.branch_id
GROUP BY b.branch_code, f.churn_segment
ORDER BY b.branch_code, customers DESC;

-- ============================================================
-- v_churn_by_product (customer account types)
-- ============================================================
CREATE VIEW IF NOT EXISTS v_churn_by_product AS
WITH cust_products AS (
  SELECT
    a.customer_id,
    GROUP_CONCAT(DISTINCT a.account_type) AS product_mix
  FROM accounts a
  WHERE a.customer_id IS NOT NULL AND a.account_category='CUSTOMER'
  GROUP BY a.customer_id
)
SELECT
  cp.product_mix,
  f.churn_segment,
  COUNT(*) AS customers,
  ROUND(SUM(COALESCE(f.customer_bal_total,0)),2) AS total_balance
FROM v_customer_churn_flags f
LEFT JOIN cust_products cp ON cp.customer_id = f.customer_id
GROUP BY cp.product_mix, f.churn_segment
ORDER BY customers DESC;
