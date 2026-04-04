-- ============================================================
-- v_customer_reactivation_events: dormant -> active
-- ============================================================
CREATE VIEW IF NOT EXISTS v_customer_reactivation_events AS
WITH flips AS (
  SELECT
    al.row_id        AS account_id,
    DATE(al.at)      AS reactivated_date
  FROM audit_log al
  WHERE al.table_name='accounts'
    AND al.action='UPDATE'
    AND json_extract(al.old_values,'$.status')='DORMANT'
    AND json_extract(al.new_values,'$.status')='ACTIVE'
),
acc AS (
  SELECT a.id AS account_id, a.customer_id
  FROM accounts a
)
SELECT
  f.reactivated_date,
  c.id AS customer_id,
  COALESCE(c.business_name, TRIM(c.first_name||' '||c.last_name)) AS customer_name,
  COUNT(DISTINCT f.account_id) AS accounts_reactivated
FROM flips f
JOIN acc a  ON a.account_id = f.account_id
JOIN customers c ON c.id = a.customer_id
GROUP BY f.reactivated_date, c.id
ORDER BY f.reactivated_date DESC, accounts_reactivated DESC;
