-- Customers holding multiple ACTIVE, non-destroyed cards per current account
CREATE VIEW IF NOT EXISTS v_cards_multiple_active_per_account AS
WITH base AS (
  SELECT
    a.id AS account_id,
    COUNT(*) FILTER (WHERE c.is_active=1 AND c.is_destroyed=0) AS active_cards
  FROM accounts a
  JOIN cards c ON c.account_id = a.id
  WHERE a.account_category='CUSTOMER' AND a.account_type='CURRENT'
  GROUP BY a.id
)
SELECT * FROM base WHERE active_cards > 1;

-- Cards whose customer/account linkage is suspicious (should be prevented by triggers)
CREATE VIEW IF NOT EXISTS v_cards_link_anomalies AS
SELECT
  c.id AS card_id,
  c.card_number,
  c.account_id,
  c.customer_id AS card_customer_id,
  a.customer_id AS account_customer_id
FROM cards c
LEFT JOIN accounts a ON a.id = c.account_id
WHERE a.customer_id IS NULL
   OR a.account_type <> 'CURRENT'
   OR c.customer_id <> a.customer_id;

-- KYC compliance gaps using kyc_profiles flags (simple view)
CREATE VIEW IF NOT EXISTS v_kyc_gaps AS
SELECT
  cu.id AS customer_id,
  COALESCE(cu.business_name, TRIM(cu.first_name||' '||cu.last_name)) AS customer_name,
  kp.has_poi, kp.has_por, kp.has_poinc,
  (CASE WHEN kp.has_poi=1 AND kp.has_por=1 AND kp.has_poinc=1 THEN 0 ELSE 1 END) AS has_gap
FROM customers cu
LEFT JOIN kyc_profiles kp ON kp.customer_id = cu.id
WHERE kp.id IS NULL
   OR kp.has_poi=0 OR kp.has_por=0 OR kp.has_poinc=0;

-- KYC documents matrix (who is missing which doc type)
CREATE VIEW IF NOT EXISTS v_kyc_docs_matrix AS
WITH doc_pivot AS (
  SELECT
    customer_id,
    MAX(CASE WHEN doc_type='PROOF_ID'        THEN 1 ELSE 0 END) AS has_proof_id,
    MAX(CASE WHEN doc_type='PROOF_RESIDENCE' THEN 1 ELSE 0 END) AS has_proof_residence,
    MAX(CASE WHEN doc_type='PROOF_INCOME'    THEN 1 ELSE 0 END) AS has_proof_income
  FROM kyc_documents
  GROUP BY customer_id
)
SELECT
  c.id AS customer_id,
  COALESCE(c.business_name, TRIM(c.first_name||' '||c.last_name)) AS customer_name,
  COALESCE(p.has_proof_id,0)        AS has_proof_id,
  COALESCE(p.has_proof_residence,0) AS has_proof_residence,
  COALESCE(p.has_proof_income,0)    AS has_proof_income,
  CASE WHEN COALESCE(p.has_proof_id,0)=1
         AND COALESCE(p.has_proof_residence,0)=1
         AND COALESCE(p.has_proof_income,0)=1 THEN 0 ELSE 1 END AS has_gap
FROM customers c
LEFT JOIN doc_pivot p ON p.customer_id = c.id;
