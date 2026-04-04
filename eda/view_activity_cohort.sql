-- ============================================================
-- v_cohort_retention_monthly: first-activity cohorts & activity
-- ============================================================
CREATE VIEW IF NOT EXISTS v_cohort_retention_monthly AS
WITH first_tx AS (
  SELECT
    a.customer_id,
    MIN(strftime('%Y-%m', t.posted_at)) AS cohort_ym
  FROM transactions t
  JOIN accounts a
    ON a.id IN (t.dr_account_id, t.cr_account_id)
  WHERE t.status='SUCCESS' AND a.customer_id IS NOT NULL
  GROUP BY a.customer_id
),
activity AS (
  SELECT
    a.customer_id,
    strftime('%Y-%m', t.posted_at) AS ym
  FROM transactions t
  JOIN accounts a
    ON a.id IN (t.dr_account_id, t.cr_account_id)
  WHERE t.status='SUCCESS' AND a.customer_id IS NOT NULL
  GROUP BY a.customer_id, strftime('%Y-%m', t.posted_at)
),
cohort_size AS (
  SELECT cohort_ym, COUNT(*) AS customers_in_cohort
  FROM first_tx
  GROUP BY cohort_ym
)
SELECT
  f.cohort_ym,
  act.ym AS activity_ym,
  COUNT(DISTINCT act.customer_id) AS active_customers,
  cs.customers_in_cohort,
  ROUND(100.0 * COUNT(DISTINCT act.customer_id) / cs.customers_in_cohort, 2) AS retention_pct
FROM first_tx f
JOIN activity act ON act.customer_id = f.customer_id
JOIN cohort_size cs ON cs.cohort_ym = f.cohort_ym
GROUP BY f.cohort_ym, act.ym
ORDER BY f.cohort_ym DESC, act.ym DESC;
