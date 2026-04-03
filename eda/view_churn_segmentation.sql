-- ============================================================
-- v_customer_churn_flags: per-customer churn/risk segmentation
-- ============================================================
CREATE VIEW IF NOT EXISTS v_customer_churn_flags AS
WITH params AS (
  SELECT CAST(COALESCE((SELECT value FROM system_parameters WHERE key='dormancy_months'),'6') AS INTEGER) AS dormancy_months
),
base AS (
  SELECT
    s.customer_id,
    s.customer_name,
    s.customer_type,
    s.active_cnt, s.dormant_cnt, s.closed_cnt, s.accounts_total, s.customer_bal_total,
    la.last_tx_date,
    la.days_since_last_tx,
    (SELECT dormancy_months*30 FROM params) AS dormancy_days
  FROM v_customer_accounts_state s
  LEFT JOIN v_customer_last_activity la ON la.customer_id = s.customer_id
)
SELECT
  b.*,
  CASE
    WHEN b.closed_cnt > 0 AND b.closed_cnt = b.accounts_total             THEN 'CHURNED'
    WHEN b.active_cnt = 0 AND (b.days_since_last_tx IS NULL
                               OR b.days_since_last_tx > b.dormancy_days) THEN 'DORMANT'
    WHEN b.days_since_last_tx IS NOT NULL AND b.days_since_last_tx <= 30  THEN 'ACTIVE_30D'
    WHEN b.days_since_last_tx IS NOT NULL AND b.days_since_last_tx <= 90  THEN 'AT_RISK_90D'
    ELSE 'AT_RISK'
  END AS churn_segment
FROM base b;
