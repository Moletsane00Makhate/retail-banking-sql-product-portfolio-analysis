-- ============================================================================
-- BANK SIM: SEED DATA (SQLite / DB Browser compatible)
-- ============================================================================
PRAGMA foreign_keys = ON;
BEGIN TRANSACTION;

-- ----------------------------------------------------------------------------
-- 1) Branches (5 total, one HQ)
-- ----------------------------------------------------------------------------
INSERT OR IGNORE INTO branches (branch_code, name, is_hq)
VALUES
  ('HQ' , 'Maseru HQ', 1),
  ('MAP', 'Maputsoe',  0),
  ('LER', 'Leribe',    0),
  ('MAF', 'Mafeteng',  0),
  ('MOH', 'Mohale''s Hoek', 0);

-- ----------------------------------------------------------------------------
-- 2) System Parameters (defaults)
--    fee_income_account_id is set AFTER GL account creation below
-- ----------------------------------------------------------------------------
INSERT OR IGNORE INTO system_parameters(key, value) VALUES ('fee_rate_percent', '1.0');         -- 1%
INSERT OR IGNORE INTO system_parameters(key, value) VALUES ('suspicious_threshold_lsl', '10000');
INSERT OR IGNORE INTO system_parameters(key, value) VALUES ('dormancy_months', '6');

-- ----------------------------------------------------------------------------
-- 3) HQ GL Accounts (Chart of Accounts - central services)
--    account_category='GL', account_type=NULL, currency='LSL'
--    12-digit account numbers, unique and descriptive by convention
-- ----------------------------------------------------------------------------
-- Helper: get HQ id
WITH hq AS (SELECT id AS hq_id FROM branches WHERE branch_code='HQ')
INSERT OR IGNORE INTO accounts (
    account_number, customer_id, branch_id, account_category, account_type,
    status, opened_at, status_updated_at, current_balance, currency
)
SELECT
    v.account_number, NULL, hq.hq_id, 'GL', NULL, 'ACTIVE',
    DATETIME('now','localtime'), DATETIME('now','localtime'), 0.00, 'LSL'
FROM hq
JOIN (
  VALUES
    ('990000000001'), -- GL: Fee Income
    ('990000000002'), -- GL: Data Purchases
    ('990000000003'), -- GL: Electricity Purchases
    ('990000000004'), -- GL: Interbank Clearing
    ('990000000005'), -- GL: DSTV Payments
    ('990000000006'), -- GL: Tax Payments
    ('990000000007')  -- GL: POS Settlements
) AS v(account_number)
ON 1=1;

-- Set system parameter for fee income GL (points to the created account id)
INSERT OR REPLACE INTO system_parameters(key, value)
SELECT 'fee_income_account_id', CAST(a.id AS TEXT)
FROM accounts a
JOIN branches b ON b.id = a.branch_id
WHERE b.branch_code='HQ' AND a.account_category='GL' AND a.account_number='990000000001';

-- ----------------------------------------------------------------------------
-- 4) Per-Branch Suspense & GL Clearing Accounts
--    For each branch: create SUSPENSE and GL accounts for ATM withdrawals,
--    BNA deposits, and Teller/ATM differences.
--    Numbering scheme (12 digits):
--      <BRANCH_SEQ><TYPE><SUFFIX>
--      BRANCH_SEQ: HQ=01, MAP=02, LER=03, MAF=04, MOH=05
--      TYPE: 01 ATM_SUSP, 02 BNA_SUSP, 03 DIFF_SUSP, 81 ATM_GL, 82 BNA_GL, 83 DIFF_GL
-- ----------------------------------------------------------------------------
WITH map_codes AS (
  SELECT 'HQ'  AS code,  '01' AS seq UNION ALL
  SELECT 'MAP', '02' UNION ALL
  SELECT 'LER', '03' UNION ALL
  SELECT 'MAF', '04' UNION ALL
  SELECT 'MOH', '05'
),
targets AS (
  SELECT b.id AS branch_id, m.seq
  FROM branches b JOIN map_codes m ON b.branch_code = m.code
),
acct_defs AS (
  SELECT 'SUSPENSE' AS category, '01' AS type_code UNION ALL  -- ATM Withdrawal Suspense
  SELECT 'SUSPENSE', '02'           UNION ALL                  -- BNA Deposit Suspense
  SELECT 'SUSPENSE', '03'           UNION ALL                  -- Teller/ATM Differences Suspense
  SELECT 'GL',       '81'           UNION ALL                  -- ATM Clearing GL
  SELECT 'GL',       '82'           UNION ALL                  -- BNA Clearing GL
  SELECT 'GL',       '83'                                      -- Cash Differences GL
)
INSERT OR IGNORE INTO accounts (
    account_number, customer_id, branch_id, account_category, account_type,
    status, opened_at, status_updated_at, current_balance, currency
)
SELECT
    -- Build a 12-digit code: <seq><type_code>00000000
    printf('%s%s%08d', t.seq, a.type_code, 0) AS account_number,
    NULL,
    t.branch_id,
    a.category, NULL,
    'ACTIVE',
    DATETIME('now','localtime'), DATETIME('now','localtime'),
    0.00, 'LSL'
FROM targets t
CROSS JOIN acct_defs a;

-- ----------------------------------------------------------------------------
-- 5) Employees: Two Tellers per Branch
-- ----------------------------------------------------------------------------
INSERT OR IGNORE INTO employees (employee_code, branch_id, role, first_name, last_name, is_active)
SELECT
  printf('TLR-%s-%02d', b.branch_code, n.num) AS employee_code,
  b.id, 'TELLER',
  'Teller', printf('%s%02d', b.branch_code, n.num),
  1
FROM branches b
CROSS JOIN (SELECT 1 AS num UNION ALL SELECT 2) n;

-- ----------------------------------------------------------------------------
-- 6) Devices: Two ATMs and Two BNAs per Branch
-- ----------------------------------------------------------------------------
-- ATMs
INSERT OR IGNORE INTO devices (device_code, branch_id, device_type, is_active)
SELECT
  printf('ATM-%s-%02d', b.branch_code, n.num),
  b.id, 'ATM', 1
FROM branches b
CROSS JOIN (SELECT 1 AS num UNION ALL SELECT 2) n;

-- BNAs
INSERT OR IGNORE INTO devices (device_code, branch_id, device_type, is_active)
SELECT
  printf('BNA-%s-%02d', b.branch_code, n.num),
  b.id, 'BNA', 1
FROM branches b
CROSS JOIN (SELECT 1 AS num UNION ALL SELECT 2) n;

COMMIT;

-- ----------------------------------------------------------------------------
-- 7) Sanity Checks (read-only)
-- ----------------------------------------------------------------------------
-- Branches
SELECT 'branches_total' AS check_name, COUNT(*) AS val FROM branches;

-- Employees: two tellers per branch -> should be 10 for 5 branches
SELECT 'tellers_total' AS check_name, COUNT(*) AS val FROM employees WHERE role='TELLER';

-- Devices: two ATMs per branch -> 10; two BNAs per branch -> 10
SELECT 'atms_total'  AS check_name, COUNT(*) AS val FROM devices WHERE device_type='ATM';
SELECT 'bnas_total'  AS check_name, COUNT(*) AS val FROM devices WHERE device_type='BNA';

-- Accounts per branch:
--   Suspense (3 per branch) -> 15 total
--   GL clearing (3 per branch) -> 15 total
SELECT 'suspense_total' AS check_name, COUNT(*) AS val FROM accounts WHERE account_category='SUSPENSE';
SELECT 'branch_gl_total' AS check_name, COUNT(*) AS val
  FROM accounts a JOIN branches b ON a.branch_id=b.id
 WHERE a.account_category='GL' AND b.branch_code <> 'HQ';

-- HQ service GLs should be 7
SELECT 'hq_service_gl_total' AS check_name, COUNT(*) AS val
  FROM accounts a JOIN branches b ON a.branch_id=b.id
 WHERE a.account_category='GL' AND b.branch_code='HQ';

-- Fee income parameter references an existing account id
SELECT 'fee_income_param_exists' AS check_name, CASE WHEN EXISTS (
           SELECT 1 FROM system_parameters p JOIN accounts a ON a.id = CAST(p.value AS INTEGER) WHERE p.key='fee_income_account_id'
       ) THEN 'OK'
       ELSE 'MISSING'
       END AS status;

-- Currency invariants (all LSL)
SELECT 'accounts_currency_all_lsl' AS check_name,
       CASE WHEN COUNT(*)=0 THEN 'OK' ELSE 'FOUND_NON_LSL' END AS status
  FROM accounts WHERE currency <> 'LSL';

-- New accounts start at 0.00
SELECT 'accounts_zero_balance' AS check_name,
       CASE WHEN COUNT(*)=0 THEN 'OK' ELSE 'NON_ZERO_BAL' END AS status
  FROM accounts WHERE ROUND(current_balance,2) <> 0.00;
