-- Suspicious flag + CLOSED account handling + initiator existence checks
CREATE TRIGGER IF NOT EXISTS trg_tx_before_ins_guard
BEFORE INSERT ON transactions
FOR EACH ROW
BEGIN
    -- Normalize suspicious flag by threshold
    SET NEW.is_suspicious =
        CASE
            WHEN NEW.status = 'SUCCESS' AND NEW.amount >= COALESCE((SELECT CAST(value AS NUMERIC) FROM system_parameters WHERE key='suspicious_threshold_lsl'), 10000.00)
            THEN 1
            ELSE 0
        END;

    -- If either side is CLOSED, force transaction to FAIL (do not abort; we record the failed tx)
    IF EXISTS(SELECT 1 FROM accounts WHERE id = NEW.dr_account_id AND status = 'CLOSED')
       OR EXISTS(SELECT 1 FROM accounts WHERE id = NEW.cr_account_id AND status = 'CLOSED')
    THEN
        SET NEW.status = 'FAILED';
        SET NEW.narrative = COALESCE(NEW.narrative,'') || ' | AUTO_FAIL:CLOSED_ACCOUNT';
    END IF;

    -- Validate initiator existence by type (abort if incorrect)
    CASE NEW.initiated_by_type
        WHEN 'CUSTOMER' THEN
            SELECT CASE WHEN NOT EXISTS (SELECT 1 FROM customers c WHERE c.id = NEW.initiated_by_id AND c.is_active=1)
                        THEN RAISE(ABORT, 'Invalid initiated_by_id for CUSTOMER') END;
        WHEN 'EMPLOYEE' THEN
            SELECT CASE WHEN NOT EXISTS (SELECT 1 FROM employees e WHERE e.id = NEW.initiated_by_id AND e.is_active=1)
                        THEN RAISE(ABORT, 'Invalid initiated_by_id for EMPLOYEE') END;
        WHEN 'DEVICE' THEN
            SELECT CASE WHEN NOT EXISTS (SELECT 1 FROM devices d WHERE d.id = NEW.initiated_by_id AND d.is_active=1)
                        THEN RAISE(ABORT, 'Invalid initiated_by_id for DEVICE') END;
        WHEN 'SYSTEM' THEN
            -- allow NULL or any integer; no check
            SELECT 1;
        ELSE
            SELECT RAISE(ABORT, 'Unknown initiated_by_type');
    END;
END;

CREATE TRIGGER IF NOT EXISTS trg_tx_before_upd_guard
BEFORE UPDATE OF amount, status, initiated_by_type, initiated_by_id ON transactions
FOR EACH ROW
BEGIN
    -- Keep suspicious flag consistent whenever amount or status changes
    SET NEW.is_suspicious =
        CASE
            WHEN NEW.status = 'SUCCESS'
                 AND NEW.amount >= COALESCE(
                        (SELECT CAST(value AS NUMERIC) FROM system_parameters WHERE key='suspicious_threshold_lsl'),
                        10000.00)
            THEN 1
            ELSE 0
        END;

    -- If either side is CLOSED, force FAILED
    IF EXISTS(SELECT 1 FROM accounts WHERE id = NEW.dr_account_id AND status = 'CLOSED')
       OR EXISTS(SELECT 1 FROM accounts WHERE id = NEW.cr_account_id AND status = 'CLOSED')
    THEN
        SET NEW.status = 'FAILED';
        SET NEW.narrative = COALESCE(NEW.narrative,'') || ' | AUTO_FAIL:CLOSED_ACCOUNT';
    END IF;

    -- Re-validate initiator
    CASE NEW.initiated_by_type
        WHEN 'CUSTOMER' THEN
            SELECT CASE WHEN NOT EXISTS (SELECT 1 FROM customers c WHERE c.id = NEW.initiated_by_id AND c.is_active=1)
                        THEN RAISE(ABORT, 'Invalid initiated_by_id for CUSTOMER') END;
        WHEN 'EMPLOYEE' THEN
            SELECT CASE WHEN NOT EXISTS (SELECT 1 FROM employees e WHERE e.id = NEW.initiated_by_id AND e.is_active=1)
                        THEN RAISE(ABORT, 'Invalid initiated_by_id for EMPLOYEE') END;
        WHEN 'DEVICE' THEN
            SELECT CASE WHEN NOT EXISTS (SELECT 1 FROM devices d WHERE d.id = NEW.initiated_by_id AND d.is_active=1)
                        THEN RAISE(ABORT, 'Invalid initiated_by_id for DEVICE') END;
        WHEN 'SYSTEM' THEN
            SELECT 1;
        ELSE
            SELECT RAISE(ABORT, 'Unknown initiated_by_type');
    END;
END;
