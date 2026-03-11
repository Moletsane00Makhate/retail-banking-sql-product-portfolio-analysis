-- ============================================================
-- v_tx_enriched: A wide, analysis-friendly transaction view
-- denormalizes transactions with branch, account, customer, and initiator details so you can slice by channel, status, branch, product type, ...etc.
-- ============================================================
CREATE VIEW IF NOT EXISTS v_tx_enriched AS
WITH params AS (
  SELECT
    CAST((SELECT value FROM system_parameters WHERE key='suspicious_threshold_lsl') AS NUMERIC) AS suspicious_threshold
),
dr AS (
  SELECT
    t.id, t.created_at, t.posted_at, t.value_date, t.reference, t.narrative,
    t.amount, t.currency, t.status, t.channel, t.is_suspicious,
    t.initiated_by_type, t.initiated_by_id,
    'DR' AS leg,
    a.id   AS account_id,
    a.account_number,
    a.account_category,
    a.account_type,
    a.status AS account_status,
    a.branch_id,
    b.branch_code,
    b.name AS branch_name,
    a.customer_id,
    c.customer_type,
    COALESCE(c.business_name, TRIM(c.first_name||' '||c.last_name)) AS customer_name,
    -t.amount AS signed_amount   -- debits are negative from this account's pov
  FROM transactions t
  JOIN accounts a ON a.id = t.dr_account_id
  JOIN branches b ON b.id = a.branch_id
  LEFT JOIN customers c ON c.id = a.customer_id
),
cr AS (
  SELECT
    t.id, t.created_at, t.posted_at, t.value_date, t.reference, t.narrative,
    t.amount, t.currency, t.status, t.channel, t.is_suspicious,
    t.initiated_by_type, t.initiated_by_id,
    'CR' AS leg,
    a.id   AS account_id,
    a.account_number,
    a.account_category,
    a.account_type,
    a.status AS account_status,
    a.branch_id,
    b.branch_code,
    b.name AS branch_name,
    a.customer_id,
    c.customer_type,
    COALESCE(c.business_name, TRIM(c.first_name||' '||c.last_name)) AS customer_name,
    +t.amount AS signed_amount   -- credits are positive
  FROM transactions t
  JOIN accounts a ON a.id = t.cr_account_id
  JOIN branches b ON b.id = a.branch_id
  LEFT JOIN customers c ON c.id = a.customer_id
)
SELECT
  x.*,
  -- Convenience time breakdowns
  DATE(x.posted_at)           AS posted_date,
  strftime('%Y-%m', x.posted_at) AS posted_ym
FROM (SELECT * FROM dr UNION ALL SELECT * FROM cr) AS x;
