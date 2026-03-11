-- Sum of balances equals net of successful postings (should hold if all postings/fees use this engine)
WITH ledger AS (
  SELECT dr_account_id AS account_id, -amount AS delta FROM transactions WHERE status='SUCCESS'
  UNION ALL
  SELECT cr_account_id AS account_id,  amount AS delta FROM transactions WHERE status='SUCCESS'
),
roll_up AS (
  SELECT account_id, ROUND(SUM(delta),2) AS net FROM ledger GROUP BY account_id
)
SELECT
  (SELECT ROUND(SUM(current_balance),2) FROM accounts) AS sum_balances,
  (SELECT ROUND(SUM(net),2) FROM roll_up)               AS sum_ledger_net,
  ROUND((SELECT SUM(current_balance) FROM accounts) - (SELECT SUM(net) FROM roll_up), 2) AS difference;
