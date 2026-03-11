-- Whenever an account's status changes, refresh status_updated_at
CREATE TRIGGER IF NOT EXISTS trg_accounts_status_touch
AFTER UPDATE OF status ON accounts
FOR EACH ROW
WHEN NEW.status <> OLD.status
BEGIN
    UPDATE accounts
       SET status_updated_at = DATETIME('now','localtime')
     WHERE id = NEW.id;
END;
