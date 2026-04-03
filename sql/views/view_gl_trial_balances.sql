-- Trial balance per branch (SUCCESS only, as of all-time ledger)
CREATE VIEW IF NOT EXISTS v_trial_balance_branch AS
WITH ledger AS (
  SELECT dr_account_id AS account_id, -amount AS delta FROM transactions WHERE status='SUCCESS'
  UNION ALL
  SELECT cr_account_id AS account_id,  amount AS delta FROM transactions WHERE status='SUCCESS'
),
rollup AS (
  SELECT account_id, ROUND(SUM(delta),2) AS ledger_net FROM ledger GROUP BY account_id
)
SELECT
  b.branch_code,
  a.id AS account_id,
  a.account_number,
  a.account_category,
  a.account_type,
  a.status AS account_status,
  ROUND(a.current_balance,2) AS current_balance,
  COALESCE(r.ledger_net,0)   AS ledger_net,
  ROUND(a.current_balance - COALESCE(r.ledger_net,0), 2) AS variance  -- should be 0 if postings are consistent
FROM accounts a
JOIN branches b ON b.id = a.branch_id
LEFT JOIN rollup r ON r.account_id = a.id
ORDER BY b.branch_code, a.account_category, a.account_number;

-- GL & Suspense balances by branch
CREATE VIEW IF NOT EXISTS v_gl_suspense_balances AS
SELECT
  b.branch_code,
  a.account_category,
  COUNT(*) AS accounts,
  ROUND(SUM(a.current_balance),2) AS total_balance
FROM accounts a
JOIN branches b ON b.id = a.branch_id
WHERE a.account_category IN ('GL','SUSPENSE')
GROUP BY b.branch_code, a.account_category
ORDER BY b.branch_code, a.account_category;
