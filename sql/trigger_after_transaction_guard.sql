-- Helper: reactivate dormant accounts just-in-time
CREATE TRIGGER IF NOT EXISTS trg_tx_after_ins_post
AFTER INSERT ON transactions
FOR EACH ROW
WHEN NEW.status = 'SUCCESS' AND NEW.channel <> 'SYSTEM'
BEGIN
    -- Reactivate DORMANT accounts touched by this tx
    UPDATE accounts
      SET status = 'ACTIVE', status_updated_at = DATETIME('now','localtime')
    WHERE id IN (NEW.dr_account_id, NEW.cr_account_id) AND status = 'DORMANT';

    -- Post debits and credits
    UPDATE accounts SET current_balance = current_balance - NEW.amount
      WHERE id = NEW.dr_account_id;
    UPDATE accounts SET current_balance = current_balance + NEW.amount
      WHERE id = NEW.cr_account_id;

    -- Automatic fee (skip if this is already a fee transaction via reference prefix)
    INSERT INTO transactions (
        dr_account_id, cr_account_id, amount, currency, status, is_suspicious,
        channel, initiated_by_type, initiated_by_id, narrative, reference,
        created_at, posted_at, value_date
    )
    SELECT
        NEW.dr_account_id,
        CAST((SELECT value FROM system_parameters WHERE key='fee_income_account_id') AS INTEGER) AS fee_gl_id,
        ROUND(NEW.amount * COALESCE((SELECT CAST(value AS NUMERIC) FROM system_parameters WHERE key='fee_rate_percent'), 1.0) / 100.0, 2) AS fee_amt,
        'LSL', 'SUCCESS', 0,
        NEW.channel, 'SYSTEM', NULL,
        'FEE-OF-TX ' || NEW.id,
        'FEE:' || NEW.id,
        DATETIME('now','localtime'),
        DATETIME('now','localtime'),
        NEW.value_date
    WHERE
        (NEW.reference IS NULL OR NEW.reference NOT LIKE 'FEE:%')
        AND EXISTS (SELECT 1 FROM system_parameters WHERE key='fee_income_account_id')
        AND EXISTS (SELECT 1 FROM accounts a WHERE a.id = CAST((SELECT value FROM system_parameters WHERE key='fee_income_account_id') AS INTEGER) AND a.status = 'ACTIVE')
        AND ROUND(NEW.amount * COALESCE((SELECT CAST(value AS NUMERIC) FROM system_parameters WHERE key='fee_rate_percent'), 1.0) / 100.0, 2) > 0;
END;

-- Apply postings when status transitions to SUCCESS (first time)
CREATE TRIGGER IF NOT EXISTS trg_tx_after_upd_post
AFTER UPDATE OF status ON transactions
FOR EACH ROW
WHEN NEW.status = 'SUCCESS' AND (OLD.status IS NULL OR OLD.status <> 'SUCCESS')
BEGIN
    -- Reactivate accounts if needed
    UPDATE accounts
      SET status = 'ACTIVE',
          status_updated_at = DATETIME('now','localtime')
    WHERE id IN (NEW.dr_account_id, NEW.cr_account_id)
      AND status = 'DORMANT';

    -- Post debits and credits
    UPDATE accounts SET current_balance = current_balance - NEW.amount
      WHERE id = NEW.dr_account_id;

    UPDATE accounts SET current_balance = current_balance + NEW.amount
      WHERE id = NEW.cr_account_id;

    -- Automatic fee (same guard as insert)
    INSERT INTO transactions (
        dr_account_id, cr_account_id, amount, currency, status, is_suspicious,
        channel, initiated_by_type, initiated_by_id, narrative, reference,
        created_at, posted_at, value_date
    )
    SELECT
        NEW.dr_account_id,
        CAST((SELECT value FROM system_parameters WHERE key='fee_income_account_id') AS INTEGER) AS fee_gl_id,
        ROUND(NEW.amount * COALESCE((SELECT CAST(value AS NUMERIC) FROM system_parameters WHERE key='fee_rate_percent'), 1.0) / 100.0, 2) AS fee_amt,
        'LSL', 'SUCCESS', 0,
        NEW.channel, 'SYSTEM', NULL,
        'FEE-OF-TX ' || NEW.id,
        'FEE:' || NEW.id,
        DATETIME('now','localtime'),
        DATETIME('now','localtime'),
        NEW.value_date
    WHERE
        (NEW.reference IS NULL OR NEW.reference NOT LIKE 'FEE:%')
        AND EXISTS (SELECT 1 FROM system_parameters WHERE key='fee_income_account_id')
        AND EXISTS (SELECT 1 FROM accounts a WHERE a.id = CAST((SELECT value FROM system_parameters WHERE key='fee_income_account_id') AS INTEGER) AND a.status = 'ACTIVE')
        AND ROUND(NEW.amount * COALESCE((SELECT CAST(value AS NUMERIC) FROM system_parameters WHERE key='fee_rate_percent'), 1.0) / 100.0, 2) > 0;
END;
