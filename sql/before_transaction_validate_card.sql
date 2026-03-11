-- A card must belong to a CURRENT customer account and the owner must match
CREATE TRIGGER IF NOT EXISTS trg_cards_before_ins_validate
BEFORE INSERT ON cards
FOR EACH ROW
BEGIN
    -- Account must be a CUSTOMER CURRENT account and not CLOSED
    SELECT CASE
        WHEN NOT EXISTS (SELECT 1 FROM accounts a WHERE a.id = NEW.account_id AND a.account_category = 'CUSTOMER' AND a.account_type = 'CURRENT' AND a.status <> 'CLOSED')
        THEN RAISE(ABORT, 'Card must link to an OPEN (ACTIVE/DORMANT) CURRENT account')
    END;

    -- The card holder must be the owner of the account
    SELECT CASE
        WHEN NOT EXISTS (SELECT 1 FROM accounts a WHERE a.id = NEW.account_id AND a.customer_id = NEW.customer_id)
        THEN RAISE(ABORT, 'Card customer_id must match account owner')
    END;
END;

-- Same vaidation on update
CREATE TRIGGER IF NOT EXISTS trg_cards_before_upd_validate
BEFORE UPDATE OF account_id, customer_id ON cards
FOR EACH ROW
BEGIN
    -- Same validations on update
    SELECT CASE
        WHEN NOT EXISTS (SELECT 1 FROM accounts a WHERE a.id = NEW.account_id AND a.account_category = 'CUSTOMER' AND a.account_type = 'CURRENT' AND a.status <> 'CLOSED')
        THEN RAISE(ABORT, 'Card must link to an ACTIVE/DORMANT CURRENT customer account')
    END;

    SELECT CASE
        WHEN NOT EXISTS (SELECT 1 FROM accounts a WHERE a.id = NEW.account_id AND a.customer_id = NEW.customer_id)
        THEN RAISE(ABORT, 'Card customer_id must match account owner')
    END;
END;
