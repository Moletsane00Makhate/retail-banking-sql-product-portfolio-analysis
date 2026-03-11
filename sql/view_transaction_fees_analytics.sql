-- Identify fee transactions by reference prefix 'FEE:<tx_id>'
CREATE VIEW IF NOT EXISTS v_fee_transactions AS
SELECT *
FROM transactions
WHERE status='SUCCESS' AND reference LIKE 'FEE:%';

-- Fee income trend by month and branch of the paying (debit) account
CREATE VIEW IF NOT EXISTS v_fee_income_by_month AS
SELECT
  strftime('%Y-%m', t.posted_at) AS ym,
  b.branch_code AS payer_branch_code,
  COUNT(*) AS fee_tx_count,
  ROUND(SUM(t.amount),2) AS fee_amount_total
FROM transactions t
JOIN accounts payer ON payer.id = t.dr_account_id
JOIN branches b ON b.id = payer.branch_id
WHERE t.status='SUCCESS' AND t.reference LIKE 'FEE:%'
GROUP BY ym, payer_branch_code
ORDER BY ym DESC, payer_branch_code;
