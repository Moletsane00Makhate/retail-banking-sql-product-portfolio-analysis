-- ============================================================
-- v_churn_overview: counts, balances and share by segment
-- ============================================================
CREATE VIEW IF NOT EXISTS v_churn_overview AS
WITH seg AS (
  SELECT churn_segment,
         COUNT(*) AS customers,
         ROUND(SUM(COALESCE(customer_bal_total,0)),2) AS total_balance
  FROM v_customer_churn_flags
  GROUP BY churn_segment
),
tot AS (SELECT SUM(customers) AS n FROM seg)
SELECT
  s.churn_segment,
  s.customers,
  ROUND(100.0 * s.customers / t.n, 2) AS customers_pct,
  s.total_balance
FROM seg s, tot t
ORDER BY customers DESC;
