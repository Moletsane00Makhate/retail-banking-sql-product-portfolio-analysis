-- =======================
-- Audit: TRANSACTIONS
-- =======================
CREATE TRIGGER IF NOT EXISTS audit_tx_ai
AFTER INSERT ON transactions
FOR EACH ROW
BEGIN
    INSERT INTO audit_log(table_name, row_id, action, old_values, new_values, actor_type, actor_id, at)
    VALUES(
        'transactions', NEW.id, 'INSERT',
        NULL,
        json_object(
            'id', NEW.id,
            'dr_account_id', NEW.dr_account_id,
            'cr_account_id', NEW.cr_account_id,
            'amount', NEW.amount,
            'status', NEW.status,
            'is_suspicious', NEW.is_suspicious,
            'channel', NEW.channel,
            'initiated_by_type', NEW.initiated_by_type,
            'initiated_by_id', NEW.initiated_by_id,
            'reference', NEW.reference,
            'created_at', NEW.created_at,
            'posted_at', NEW.posted_at
        ),
        NEW.initiated_by_type, NEW.initiated_by_id, DATETIME('now','localtime')
    );
END;

CREATE TRIGGER IF NOT EXISTS audit_tx_au
AFTER UPDATE ON transactions
FOR EACH ROW
BEGIN
    INSERT INTO audit_log(table_name, row_id, action, old_values, new_values, actor_type, actor_id, at)
    VALUES(
        'transactions', NEW.id, 'UPDATE',
        json_object(
            'status', OLD.status,
            'amount', OLD.amount,
            'is_suspicious', OLD.is_suspicious,
            'reference', OLD.reference
        ),
        json_object(
            'status', NEW.status,
            'amount', NEW.amount,
            'is_suspicious', NEW.is_suspicious,
            'reference', NEW.reference
        ),
        NEW.initiated_by_type, NEW.initiated_by_id, DATETIME('now','localtime')
    );
END;

CREATE TRIGGER IF NOT EXISTS audit_tx_ad
AFTER DELETE ON transactions
FOR EACH ROW
BEGIN
    INSERT INTO audit_log(table_name, row_id, action, old_values, new_values, actor_type, actor_id, at)
    VALUES(
        'transactions', OLD.id, 'DELETE',
        json_object(
            'dr_account_id', OLD.dr_account_id,
            'cr_account_id', OLD.cr_account_id,
            'amount', OLD.amount,
            'status', OLD.status,
            'reference', OLD.reference
        ),
        NULL,
        NULL, NULL, DATETIME('now','localtime')
    );
END;

-- =======================
-- Audit: ACCOUNTS
-- =======================
CREATE TRIGGER IF NOT EXISTS audit_accounts_ai
AFTER INSERT ON accounts
FOR EACH ROW
BEGIN
    INSERT INTO audit_log(table_name, row_id, action, old_values, new_values, at)
    VALUES(
        'accounts', NEW.id, 'INSERT',
        NULL,
        json_object(
            'account_number', NEW.account_number,
            'customer_id', NEW.customer_id,
            'branch_id', NEW.branch_id,
            'category', NEW.account_category,
            'type', NEW.account_type,
            'status', NEW.status,
            'balance', NEW.current_balance
        ),
        DATETIME('now','localtime')
    );
END;

CREATE TRIGGER IF NOT EXISTS audit_accounts_au
AFTER UPDATE ON accounts
FOR EACH ROW
BEGIN
    INSERT INTO audit_log(table_name, row_id, action, old_values, new_values, at)
    VALUES(
        'accounts', NEW.id, 'UPDATE',
        json_object(
            'status', OLD.status,
            'balance', OLD.current_balance
        ),
        json_object(
            'status', NEW.status,
            'balance', NEW.current_balance
        ),
        DATETIME('now','localtime')
    );
END;

CREATE TRIGGER IF NOT EXISTS audit_accounts_ad
AFTER DELETE ON accounts
FOR EACH ROW
BEGIN
    INSERT INTO audit_log(table_name, row_id, action, old_values, new_values, at)
    VALUES(
        'accounts', OLD.id, 'DELETE',
        json_object(
            'account_number', OLD.account_number,
            'customer_id', OLD.customer_id,
            'branch_id', OLD.branch_id,
            'status', OLD.status,
            'balance', OLD.current_balance
        ),
        NULL,
        DATETIME('now','localtime')
    );
END;

-- =======================
-- Audit: CARDS
-- =======================
CREATE TRIGGER IF NOT EXISTS audit_cards_ai
AFTER INSERT ON cards
FOR EACH ROW
BEGIN
    INSERT INTO audit_log(table_name, row_id, action, old_values, new_values, at)
    VALUES(
        'cards', NEW.id, 'INSERT',
        NULL,
        json_object(
            'card_number', NEW.card_number,
            'account_id', NEW.account_id,
            'customer_id', NEW.customer_id,
            'is_active', NEW.is_active,
            'is_destroyed', NEW.is_destroyed
        ),
        DATETIME('now','localtime')
    );
END;

CREATE TRIGGER IF NOT EXISTS audit_cards_au
AFTER UPDATE ON cards
FOR EACH ROW
BEGIN
    INSERT INTO audit_log(table_name, row_id, action, old_values, new_values, at)
    VALUES(
        'cards', NEW.id, 'UPDATE',
        json_object(
            'is_active', OLD.is_active,
            'is_destroyed', OLD.is_destroyed
        ),
        json_object(
            'is_active', NEW.is_active,
            'is_destroyed', NEW.is_destroyed
        ),
        DATETIME('now','localtime')
    );
END;

CREATE TRIGGER IF NOT EXISTS audit_cards_ad
AFTER DELETE ON cards
FOR EACH ROW
BEGIN
    INSERT INTO audit_log(table_name, row_id, action, old_values, new_values, at)
    VALUES(
        'cards', OLD.id, 'DELETE',
        json_object(
            'card_number', OLD.card_number,
            'account_id', OLD.account_id,
            'customer_id', OLD.customer_id
        ),
        NULL,
        DATETIME('now','localtime')
    );
END;

-- =======================
-- Audit: KYC (profiles & documents)
-- =======================
CREATE TRIGGER IF NOT EXISTS audit_kycp_ai
AFTER INSERT ON kyc_profiles
FOR EACH ROW
BEGIN
    INSERT INTO audit_log(table_name, row_id, action, new_values, at)
    VALUES(
        'kyc_profiles', NEW.id, 'INSERT',
        json_object(
            'customer_id', NEW.customer_id,
            'has_poi', NEW.has_poi, 'has_por', NEW.has_por, 'has_poinc', NEW.has_poinc
        ),
        DATETIME('now','localtime')
    );
END;

CREATE TRIGGER IF NOT EXISTS audit_kycp_au
AFTER UPDATE ON kyc_profiles
FOR EACH ROW
BEGIN
    INSERT INTO audit_log(table_name, row_id, action, old_values, new_values, at)
    VALUES(
        'kyc_profiles', NEW.id, 'UPDATE',
        json_object('has_poi', OLD.has_poi, 'has_por', OLD.has_por, 'has_poinc', OLD.has_poinc),
        json_object('has_poi', NEW.has_poi, 'has_por', NEW.has_por, 'has_poinc', NEW.has_poinc),
        DATETIME('now','localtime')
    );
END;

CREATE TRIGGER IF NOT EXISTS audit_kycp_ad
AFTER DELETE ON kyc_profiles
FOR EACH ROW
BEGIN
    INSERT INTO audit_log(table_name, row_id, action, old_values, at)
    VALUES(
        'kyc_profiles', OLD.id, 'DELETE',
        json_object(
            'customer_id', OLD.customer_id,
            'has_poi', OLD.has_poi, 'has_por', OLD.has_por, 'has_poinc', OLD.has_poinc
        ),
        DATETIME('now','localtime')
    );
END;

CREATE TRIGGER IF NOT EXISTS audit_kycd_ai
AFTER INSERT ON kyc_documents
FOR EACH ROW
BEGIN
    INSERT INTO audit_log(table_name, row_id, action, new_values, at)
    VALUES(
        'kyc_documents', NEW.id, 'INSERT',
        json_object('customer_id', NEW.customer_id, 'doc_type', NEW.doc_type, 'filename', NEW.filename, 'mime_type', NEW.mime_type),
        DATETIME('now','localtime')
    );
END;

CREATE TRIGGER IF NOT EXISTS audit_kycd_ad
AFTER DELETE ON kyc_documents
FOR EACH ROW
BEGIN
    INSERT INTO audit_log(table_name, row_id, action, old_values, at)
    VALUES(
        'kyc_documents', OLD.id, 'DELETE',
        json_object('customer_id', OLD.customer_id, 'doc_type', OLD.doc_type, 'filename', OLD.filename, 'mime_type', OLD.mime_type),
        DATETIME('now','localtime')
    );
END;
