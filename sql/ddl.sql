-- ============================================================================
-- Bank Simulation Schema (SQLite compatible) - SCHEMA ONLY
-- ============================================================================
PRAGMA foreign_keys = ON;
-- ----------------------------------------------------------------------------
-- 1) Reference: Branches
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS branches (
    id                INTEGER PRIMARY KEY,
    branch_code       TEXT    NOT NULL UNIQUE,           -- e.g., "HQ", "LER"
    name              TEXT    NOT NULL,
    is_hq             INTEGER NOT NULL DEFAULT 0 CHECK (is_hq IN (0,1)),
    created_at        TEXT    NOT NULL DEFAULT (DATETIME('now','localtime'))
);

CREATE INDEX IF NOT EXISTS ix_branches_is_hq ON branches(is_hq);

-- ----------------------------------------------------------------------------
-- 2) People & Orgs: Customers and Employees
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS customers (
    id                INTEGER PRIMARY KEY,
    customer_code     TEXT    NOT NULL UNIQUE,           -- human-friendly ID
    customer_type     TEXT    NOT NULL CHECK (customer_type IN ('PERSON','BUSINESS')),
    first_name        TEXT,                              -- nullable for BUSINESS
    last_name         TEXT,
    business_name     TEXT,                              -- nullable for PERSON
    phone             TEXT,
    email             TEXT,
    is_active         INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1)),
    created_at        TEXT    NOT NULL DEFAULT (DATETIME('now','localtime'))
);

CREATE INDEX IF NOT EXISTS ix_customers_type_active ON customers(customer_type, is_active);

-- Employees (to support branch tellers and initiators)
CREATE TABLE IF NOT EXISTS employees (
    id                INTEGER PRIMARY KEY,
    employee_code     TEXT    NOT NULL UNIQUE,
    branch_id         INTEGER NOT NULL REFERENCES branches(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    role              TEXT    NOT NULL CHECK (role IN ('TELLER','MANAGER','BACKOFFICE','OPS','OTHER')),
    first_name        TEXT    NOT NULL,
    last_name         TEXT    NOT NULL,
    is_active         INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1)),
    created_at        TEXT    NOT NULL DEFAULT (DATETIME('now','localtime'))
);

CREATE INDEX IF NOT EXISTS ix_employees_branch_role ON employees(branch_id, role);

-- ----------------------------------------------------------------------------
-- 3) KYC: One-to-one KYC profile + scanned documents (BLOBs)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS kyc_profiles (
    id                INTEGER PRIMARY KEY,
    customer_id       INTEGER NOT NULL UNIQUE
                      REFERENCES customers(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    -- KYC flags (proof-of-identity, proof-of-residence, proof-of-income)
    has_poi           INTEGER NOT NULL DEFAULT 0 CHECK (has_poi IN (0,1)),
    has_por           INTEGER NOT NULL DEFAULT 0 CHECK (has_por IN (0,1)),
    has_poinc         INTEGER NOT NULL DEFAULT 0 CHECK (has_poinc IN (0,1)),
    poi_id_number     TEXT,       -- ID/passport number (optional)
    poi_expiry_date   TEXT,       -- YYYY-MM-DD (optional)
    created_at        TEXT NOT NULL DEFAULT (DATETIME('now','localtime')),
    updated_at        TEXT NOT NULL DEFAULT (DATETIME('now','localtime'))
);

CREATE TABLE IF NOT EXISTS kyc_documents (
    id                INTEGER PRIMARY KEY,
    customer_id       INTEGER NOT NULL
                      REFERENCES customers(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    doc_type          TEXT    NOT NULL CHECK (doc_type IN ('PROOF_ID','PROOF_RESIDENCE','PROOF_INCOME')),
    filename          TEXT,
    mime_type         TEXT,
    file_blob         BLOB,
    uploaded_at       TEXT    NOT NULL DEFAULT (DATETIME('now','localtime')),
    UNIQUE(customer_id, doc_type) -- at most one of each type per customer
);

CREATE INDEX IF NOT EXISTS ix_kyc_documents_customer ON kyc_documents(customer_id, doc_type);

-- ----------------------------------------------------------------------------
-- 4) Devices (for initiators and branch infrastructure: ATM, BNA, POS, etc.)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS devices (
    id                INTEGER PRIMARY KEY,
    device_code       TEXT    NOT NULL UNIQUE,
    branch_id         INTEGER NOT NULL REFERENCES branches(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    device_type       TEXT    NOT NULL CHECK (device_type IN ('ATM','BNA','POS','OTHER')),
    is_active         INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1)),
    created_at        TEXT    NOT NULL DEFAULT (DATETIME('now','localtime'))
);

CREATE INDEX IF NOT EXISTS ix_devices_branch_type ON devices(branch_id, device_type);

-- ----------------------------------------------------------------------------
-- 5) Accounts (customer + GL + suspense)
-- ----------------------------------------------------------------------------
-- Account categories separate operational (customer) from GL/suspense ledgers.
-- Balance stored with 2dp; new accounts start at 0.00 per spec.
CREATE TABLE IF NOT EXISTS accounts (
    id                INTEGER PRIMARY KEY,
    account_number    TEXT    NOT NULL UNIQUE CHECK (length(account_number) = 12 AND account_number GLOB '[0-9]*'),
    customer_id       INTEGER, -- nullable for GL/SUSPENSE accounts
    branch_id         INTEGER NOT NULL,
    account_category  TEXT    NOT NULL CHECK (account_category IN ('CUSTOMER','GL','SUSPENSE')),
    account_type      TEXT    CHECK (
                                (account_category = 'CUSTOMER' AND account_type IN ('CURRENT','SAVINGS','LOAN','FIXED_DEPOSIT'))
                                OR (account_category IN ('GL','SUSPENSE') AND account_type IS NULL)
                              ),
    status            TEXT    NOT NULL CHECK (status IN ('ACTIVE','DORMANT','CLOSED')),
    opened_at         TEXT    NOT NULL DEFAULT (DATETIME('now','localtime')),
    status_updated_at TEXT    NOT NULL DEFAULT (DATETIME('now','localtime')),
    current_balance   NUMERIC NOT NULL DEFAULT 0.00 CHECK (current_balance = ROUND(current_balance, 2)),
    currency          TEXT    NOT NULL DEFAULT 'LSL' CHECK (currency = 'LSL'),
    -- FOREIGN KEYS
    FOREIGN KEY (customer_id) REFERENCES customers(id)
      ON UPDATE CASCADE ON DELETE RESTRICT,
    FOREIGN KEY (branch_id) REFERENCES branch(branch_id)
      ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS ix_accounts_branch ON accounts(branch_id);
CREATE INDEX IF NOT EXISTS ix_accounts_customer ON accounts(customer_id);
CREATE INDEX IF NOT EXISTS ix_accounts_status ON accounts(status);
CREATE INDEX IF NOT EXISTS ix_accounts_category_type ON accounts(account_category, account_type);

-- ----------------------------------------------------------------------------
-- 6) Cards (ATM cards) - linked to a CURRENT account; destroyable flag
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cards (
    id                INTEGER PRIMARY KEY,
    card_number       TEXT    NOT NULL UNIQUE CHECK (length(card_number) = 16 AND card_number GLOB '[0-9]*'),
    account_id        INTEGER NOT NULL
                      REFERENCES accounts(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    customer_id       INTEGER NOT NULL
                      REFERENCES customers(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    is_active         INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1)),
    is_destroyed      INTEGER NOT NULL DEFAULT 0 CHECK (is_destroyed IN (0,1)),
    issued_at         TEXT    NOT NULL DEFAULT (DATETIME('now','localtime')),
    destroyed_at      TEXT,

    -- NOTE: Enforcing "account must be CURRENT" will be done via triggers later.
    -- This schema-level comment remains to document the rule.
    CHECK ( (is_destroyed = 0) OR (destroyed_at IS NULL OR typeof(destroyed_at) = 'text') )
);

CREATE INDEX IF NOT EXISTS ix_cards_account ON cards(account_id);
CREATE INDEX IF NOT EXISTS ix_cards_customer ON cards(customer_id);
CREATE INDEX IF NOT EXISTS ix_cards_active ON cards(is_active, is_destroyed);

-- ----------------------------------------------------------------------------
-- 7) Transactions (double-entry in one row: DR and CR accounts)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS transactions (
    id                  INTEGER PRIMARY KEY,
    -- Double-entry references
    dr_account_id       INTEGER NOT NULL REFERENCES accounts(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    cr_account_id       INTEGER NOT NULL REFERENCES accounts(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CHECK (dr_account_id <> cr_account_id),
    amount              NUMERIC NOT NULL
                        CHECK (amount > 0 AND amount = ROUND(amount, 2)),
    currency            TEXT    NOT NULL DEFAULT 'LSL' CHECK (currency = 'LSL'),
    -- Outcome & flags
    status              TEXT    NOT NULL CHECK (status IN ('SUCCESS','FAILED')),
    is_suspicious       INTEGER NOT NULL DEFAULT 0 CHECK (is_suspicious IN (0,1)),
    -- Channel of initiation
    channel             TEXT    NOT NULL CHECK (channel IN ('IN_BRANCH','USSD','WEB','SMART_APP','POS','ONLINE_PAYMENTS', 'SYSTEM')),
    -- Who initiated (polymorphic reference by type + id)
    initiated_by_type   TEXT    NOT NULL CHECK (initiated_by_type IN ('CUSTOMER','EMPLOYEE','DEVICE','SYSTEM')),
    initiated_by_id     INTEGER,  -- references customers/employees/devices logically
    narrative           TEXT,
    reference           TEXT,
    created_at          TEXT    NOT NULL DEFAULT (DATETIME('now','localtime')),
    posted_at           TEXT    NOT NULL DEFAULT (DATETIME('now','localtime')),
    value_date          TEXT
);

CREATE INDEX IF NOT EXISTS ix_tx_dr ON transactions(dr_account_id);
CREATE INDEX IF NOT EXISTS ix_tx_cr ON transactions(cr_account_id);
CREATE INDEX IF NOT EXISTS ix_tx_created ON transactions(created_at);
CREATE INDEX IF NOT EXISTS ix_tx_status ON transactions(status);
CREATE INDEX IF NOT EXISTS ix_tx_amount ON transactions(amount);
CREATE INDEX IF NOT EXISTS ix_tx_channel ON transactions(channel);
CREATE INDEX IF NOT EXISTS ix_tx_suspicious ON transactions(is_suspicious);

-- ----------------------------------------------------------------------------
-- 8) Audit Log (for INSERT/UPDATE/DELETE on key tables; triggers later)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS audit_log (
    id                INTEGER PRIMARY KEY,
    table_name        TEXT    NOT NULL,
    row_id            INTEGER NOT NULL,
    action            TEXT    NOT NULL CHECK (action IN ('INSERT','UPDATE','DELETE')),
    old_values        TEXT,        -- JSON/text snapshot (optional)
    new_values        TEXT,        -- JSON/text snapshot (optional)
    actor_type        TEXT    CHECK (actor_type IN ('CUSTOMER','EMPLOYEE','DEVICE','SYSTEM','DBA')),
    actor_id          INTEGER,
    at                TEXT    NOT NULL DEFAULT (DATETIME('now','localtime'))
);

CREATE INDEX IF NOT EXISTS ix_audit_table_row ON audit_log(table_name, row_id);
CREATE INDEX IF NOT EXISTS ix_audit_at ON audit_log(at);

-- ----------------------------------------------------------------------------
-- 9) Optional Parameters (to support future triggers/rules)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS system_parameters (
    key               TEXT PRIMARY KEY,
    value             TEXT NOT NULL,
    updated_at        TEXT NOT NULL DEFAULT (DATETIME('now','localtime'))
);

-- Suggested defaults for later (not inserted here; schema only):
--   'fee_rate_percent' = '1.0'
--   'suspicious_threshold_lsl' = '10000.00'
--   'dormancy_months' = '6'
