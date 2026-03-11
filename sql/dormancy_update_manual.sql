-- Set accounts to DORMANT if no successful transactions in the last 6 months
-- No time-based trigger for SQLite
UPDATE accounts AS a
SET status = 'DORMANT', status_updated_at = DATETIME('now','localtime')
WHERE a.status = 'ACTIVE' AND a.account_category = 'CUSTOMER'
  AND NOT EXISTS (
        SELECT 1
        FROM transactions t
        WHERE (t.dr_account_id = a.id OR t.cr_account_id = a.id) AND t.status = 'SUCCESS' AND DATE(t.posted_at) >= DATE('now','localtime','-6 months')
  );
