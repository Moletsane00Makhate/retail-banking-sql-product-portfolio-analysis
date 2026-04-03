-- Accounts by lifecycle status
CREATE VIEW IF NOT EXISTS v_accounts_by_status AS
SELECT status, COUNT(*) AS accounts, ROUND(SUM(current_balance),2) AS total_balance
FROM accounts
GROUP BY status;

-- Accounts opened today (local date)
CREATE VIEW IF NOT EXISTS v_accounts_new_today AS
SELECT *
FROM accounts
WHERE DATE(opened_at) = DATE('now','localtime');

-- Zero-balance accounts (useful for pruning or campaigns)
CREATE VIEW IF NOT EXISTS v_accounts_zero_balance AS
SELECT *
FROM accounts
WHERE ROUND(current_balance,2) = 0.00;

-- Product portfolio per branch (customer accounts only)
CREATE VIEW IF NOT EXISTS v_accounts_portfolio AS
SELECT
  b.branch_code,
  a.account_type,
  COUNT(*)                       AS accounts,
  ROUND(SUM(a.current_balance),2) AS balance_total,
  ROUND(AVG(a.current_balance),2) AS balance_avg
FROM accounts a
JOIN branches b ON b.id = a.branch_id
WHERE a.account_category='CUSTOMER'
GROUP BY b.branch_code, a.account_type
ORDER BY b.branch_code, a.account_type;
