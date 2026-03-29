-- ════════════════════════════════════════════════════════════════
-- Credit Risk Engine — Corrected DDL + COPY
-- Schema: credit_risk
-- All table columns verified against actual CSV headers
-- ════════════════════════════════════════════════════════════════

CREATE SCHEMA IF NOT EXISTS credit_risk;

-- ─────────────────────────────────────────
-- 1. CUSTOMER MASTER
-- CSV: CUSTOMER_MASTER.csv (19 cols)
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS credit_risk.customer_master (
    customer_id                 BIGINT PRIMARY KEY,
    cif_number                  VARCHAR(20),
    customer_name               VARCHAR(100),
    dob                         DATE,
    age                         INT,
    gender                      VARCHAR(10),
    marital_status              VARCHAR(20),
    occupation_type             VARCHAR(60),
    annual_income               NUMERIC(18,2),
    city                        VARCHAR(50),
    state                       VARCHAR(50),
    pincode                     VARCHAR(10),
    pan_number                  VARCHAR(15),
    mobile_number               VARCHAR(15),
    email_id                    VARCHAR(100),
    kyc_status                  VARCHAR(30),
    years_at_current_residence  INT,
    own_rent_flag               VARCHAR(30),
    load_date                   DATE
);

-- ─────────────────────────────────────────
-- 2. LOAN MASTER
-- CSV: LOAN_MASTER_DAILY.csv (17 cols)
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS credit_risk.loan_master (
    loan_id             BIGINT PRIMARY KEY,
    customer_id         BIGINT REFERENCES credit_risk.customer_master(customer_id),
    product_code        VARCHAR(20),
    product_description VARCHAR(100),
    sanction_amount     NUMERIC(18,2),
    interest_rate       NUMERIC(6,2),
    tenure_months       INT,
    emi_amount          NUMERIC(18,2),
    loan_status         VARCHAR(50),
    disbursement_date   DATE,
    maturity_date       DATE,
    branch_code         VARCHAR(20),
    sourcing_channel    VARCHAR(30),
    loan_officer_id     VARCHAR(20),
    processing_fee      NUMERIC(12,2),
    insurance_flag      BOOLEAN,
    load_date           DATE
);

-- ─────────────────────────────────────────
-- 3. APPLICATION FORM
-- CSV: APPLICATION_FORM_DATA.csv (21 cols)
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS credit_risk.application_form (
    application_id               BIGINT PRIMARY KEY,
    customer_id                  BIGINT,
    declared_income              NUMERIC(18,2),
    employment_type              VARCHAR(60),
    company_name                 VARCHAR(100),
    company_category             VARCHAR(30),
    work_experience_years        INT,
    years_at_current_employer    INT,
    loan_purpose                 VARCHAR(60),
    requested_amount             NUMERIC(18,2),
    requested_tenure             INT,
    foir                         NUMERIC(6,4),
    existing_monthly_obligations NUMERIC(18,2),
    co_applicant_flag            BOOLEAN,
    co_applicant_income          NUMERIC(18,2),
    ltv_ratio                    NUMERIC(6,4),
    property_value               NUMERIC(18,2),
    application_date             DATE,
    application_status           VARCHAR(30),
    credit_decisioning_model     VARCHAR(30),
    load_date                    DATE
);

-- ─────────────────────────────────────────
-- 4. CIBIL RAW PULL (Primary Bureau Table)
-- CSV: CIBIL_RAW_PULL.csv (22 cols)
-- Note: no refresh_cycle in this CSV
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS credit_risk.bureau_cibil (
    customer_id                   BIGINT,
    bureau_agency                 VARCHAR(30),
    bureau_score                  INT,
    score_version                 VARCHAR(30),
    total_tradelines              INT,
    secured_tradelines            INT,
    unsecured_tradelines          INT,
    credit_card_tradelines        INT,
    total_outstanding             NUMERIC(18,2),
    total_sanctioned_limit        NUMERIC(18,2),
    credit_utilisation_pct        NUMERIC(6,2),
    recent_enquiries_3m           INT,
    recent_enquiries_6m           INT,
    max_dpd_12m                   INT,
    max_dpd_24m                   INT,
    number_of_defaults            INT,
    oldest_account_vintage_months INT,
    written_off_accounts          INT,
    suit_filed_flag               BOOLEAN,
    wilful_default_flag           BOOLEAN,
    bureau_pull_date              DATE,
    load_date                     DATE,
    PRIMARY KEY (customer_id, bureau_agency)
);

-- ─────────────────────────────────────────
-- 5. BUREAU REFRESH 6M (Monitoring Table)
-- CSV: BUREAU_REFRESH_6M.csv (16 cols)
-- Separate from CIBIL_RAW_PULL — refresh/delta tracking
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS credit_risk.bureau_refresh (
    customer_id              BIGINT,
    bureau_agency            VARCHAR(30),
    refresh_cycle            VARCHAR(30),
    bureau_score             INT,
    score_delta_vs_previous  NUMERIC(8,2),
    total_tradelines         INT,
    secured_tradelines       INT,
    unsecured_tradelines     INT,
    total_outstanding        NUMERIC(18,2),
    recent_enquiries_3m      INT,
    max_dpd_12m              INT,
    number_of_defaults       INT,
    credit_utilisation_pct   NUMERIC(6,2),
    new_accounts_opened_3m   INT,
    bureau_pull_date         DATE,
    load_date                DATE,
    PRIMARY KEY (customer_id, bureau_agency, refresh_cycle)
);

-- ─────────────────────────────────────────
-- 6. DPD HISTORY MONTHLY
-- CSV: DPD_HISTORY_MONTHLY.csv (9 cols)
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS credit_risk.dpd_history (
    loan_id        BIGINT,
    month_end_date DATE,
    dpd            INT,
    overdue_amount NUMERIC(18,2),
    emi_due        NUMERIC(18,2),
    bounce_flag    BOOLEAN,
    asset_class    VARCHAR(20),
    mob            INT,
    load_date      DATE,
    PRIMARY KEY (loan_id, month_end_date)
);

-- ─────────────────────────────────────────
-- 7. BANK STATEMENT SUMMARY
-- CSV: BANK_STATEMENT_SUMMARY.csv (23 cols)
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS credit_risk.bank_statement (
    customer_id                 BIGINT PRIMARY KEY,
    avg_monthly_credit          NUMERIC(18,2),
    avg_monthly_debit           NUMERIC(18,2),
    avg_eod_balance             NUMERIC(18,2),
    min_balance                 NUMERIC(18,2),
    max_balance                 NUMERIC(18,2),
    emi_bounce_count            INT,
    salary_credit_count         INT,
    salary_flag                 BOOLEAN,
    inward_cheque_bounce_count  INT,
    outward_cheque_bounce_count INT,
    avg_monthly_emi_outflow     NUMERIC(18,2),
    cash_withdrawal_pct         NUMERIC(6,2),
    upi_txn_count_monthly       INT,
    international_txn_flag      BOOLEAN,
    gaming_txn_flag             BOOLEAN,
    casino_txn_flag             BOOLEAN,
    credit_card_payment_flag    BOOLEAN,
    statement_start_date        DATE,
    statement_end_date          DATE,
    bank_name                   VARCHAR(50),
    account_type                VARCHAR(20),
    load_date                   DATE
);

-- ─────────────────────────────────────────
-- 8. INCOME DOCUMENTS
-- CSV: INCOME_DOCUMENT_PARSED.csv (15 cols)
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS credit_risk.income_documents (
    customer_id          BIGINT PRIMARY KEY,
    declared_income      NUMERIC(18,2),
    verified_income      NUMERIC(18,2),
    income_deviation_pct NUMERIC(6,2),
    document_type        VARCHAR(60),
    document_source      VARCHAR(60),
    mismatch_flag        BOOLEAN,
    mismatch_severity    VARCHAR(20),
    itr_assessed_income  NUMERIC(18,2),
    gst_turnover         NUMERIC(18,2),
    form26as_tds_amount  NUMERIC(18,2),
    verification_status  VARCHAR(30),
    verification_date    DATE,
    verifier_agency      VARCHAR(50),
    load_date            DATE
);

-- ─────────────────────────────────────────
-- 9. ACCOUNT PORTFOLIO MONTHLY
-- CSV: ACCOUNT_PORTFOLIO_MONTHLY.csv (10 cols)
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS credit_risk.account_portfolio_monthly (
    loan_id                 BIGINT,
    month_end_date          DATE,
    outstanding_principal   NUMERIC(18,2),
    accrued_interest        NUMERIC(18,2),
    dpd                     INT,
    asset_class             VARCHAR(20),
    provision_amount        NUMERIC(18,2),
    write_off_flag          BOOLEAN,
    npa_classification_date DATE,
    load_date               DATE,
    PRIMARY KEY (loan_id, month_end_date)
);

-- ─────────────────────────────────────────
-- 10. REPAYMENT TRANSACTIONS
-- CSV: REPAYMENT_TRANSACTIONS.csv (12 cols)
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS credit_risk.repayment_transactions (
    txn_id                BIGINT PRIMARY KEY,
    loan_id               BIGINT,
    txn_date              DATE,
    txn_amount            NUMERIC(18,2),
    txn_type              VARCHAR(40),
    payment_mode          VARCHAR(30),
    instrument_no         VARCHAR(30),
    bounce_flag           BOOLEAN,
    bounce_reason         VARCHAR(60),
    penal_interest_levied NUMERIC(12,2),
    utr_number            VARCHAR(30),
    load_date             DATE
);

-- ─────────────────────────────────────────
-- 11. SETTLEMENT CASES
-- CSV: SETTLEMENT_CASES.csv (11 cols)
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS credit_risk.settlement_cases (
    loan_id                   BIGINT PRIMARY KEY,
    settlement_date           DATE,
    outstanding_at_settlement NUMERIC(18,2),
    settlement_amount         NUMERIC(18,2),
    waiver_amount             NUMERIC(18,2),
    waiver_percentage         NUMERIC(6,2),
    settlement_type           VARCHAR(50),
    sanctioned_by             VARCHAR(50),
    first_payment_date        DATE,
    noc_issued_flag           BOOLEAN,
    load_date                 DATE
);

-- ─────────────────────────────────────────
-- 12. WRITE-OFF DATA
-- CSV: WRITE_OFF_DATA.csv (11 cols)
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS credit_risk.write_off_data (
    loan_id           BIGINT PRIMARY KEY,
    writeoff_date     DATE,
    writeoff_amount   NUMERIC(18,2),
    writeoff_type     VARCHAR(50),
    npa_date          DATE,
    dpd_at_writeoff   INT,
    recovery_amount   NUMERIC(18,2),
    recovery_date     DATE,
    recovery_channel  VARCHAR(50),
    arc_pool_name     VARCHAR(50),
    load_date         DATE
);

-- ─────────────────────────────────────────
-- 13. DISBURSEMENT DETAILS
-- CSV: DISBURSEMENT_DETAILS.csv (9 cols)
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS credit_risk.disbursement_details (
    loan_id                   BIGINT,
    disbursement_tranche_no   INT,
    disbursement_date         DATE,
    disbursed_amount          NUMERIC(18,2),
    payment_mode              VARCHAR(20),
    beneficiary_account       VARCHAR(30),
    beneficiary_ifsc          VARCHAR(15),
    disbursement_reference_no VARCHAR(30),
    load_date                 DATE,
    PRIMARY KEY (loan_id, disbursement_tranche_no)
);


-- ─────────────────────────────────────────
-- PERFORMANCE INDEXES
-- ─────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_loan_customer    ON credit_risk.loan_master(customer_id);
CREATE INDEX IF NOT EXISTS idx_dpd_loan         ON credit_risk.dpd_history(loan_id);
CREATE INDEX IF NOT EXISTS idx_dpd_date         ON credit_risk.dpd_history(month_end_date);
CREATE INDEX IF NOT EXISTS idx_dpd_mob          ON credit_risk.dpd_history(mob);
CREATE INDEX IF NOT EXISTS idx_bureau_customer  ON credit_risk.bureau_cibil(customer_id);
CREATE INDEX IF NOT EXISTS idx_refresh_customer ON credit_risk.bureau_refresh(customer_id);
CREATE INDEX IF NOT EXISTS idx_app_customer     ON credit_risk.application_form(customer_id);
CREATE INDEX IF NOT EXISTS idx_portfolio_date   ON credit_risk.account_portfolio_monthly(month_end_date);
CREATE INDEX IF NOT EXISTS idx_repay_loan       ON credit_risk.repayment_transactions(loan_id);


-- ════════════════════════════════════════════════════════════════
-- COPY COMMANDS
-- Load order respects FK constraints:
-- customer_master → loan_master → all others
-- ════════════════════════════════════════════════════════════════

-- 1. CUSTOMER MASTER
COPY credit_risk.customer_master
FROM 'D:/Data Analyst/Projects/Credit_Risk_Engine_Project/Data/CUSTOMER_MASTER.csv'
DELIMITER ',' CSV HEADER;

-- 2. LOAN MASTER
COPY credit_risk.loan_master
FROM 'D:/Data Analyst/Projects/Credit_Risk_Engine_Project/Data/LOAN_MASTER_DAILY.csv'
DELIMITER ',' CSV HEADER;

-- 3. APPLICATION FORM
COPY credit_risk.application_form
FROM 'D:/Data Analyst/Projects/Credit_Risk_Engine_Project/Data/APPLICATION_FORM_DATA.csv'
DELIMITER ',' CSV HEADER;

-- 4. CIBIL RAW PULL → bureau_cibil
COPY credit_risk.bureau_cibil
FROM 'D:/Data Analyst/Projects/Credit_Risk_Engine_Project/Data/CIBIL_RAW_PULL.csv'
DELIMITER ',' CSV HEADER;

-- 5. BUREAU REFRESH 6M → bureau_refresh
COPY credit_risk.bureau_refresh
FROM 'D:/Data Analyst/Projects/Credit_Risk_Engine_Project/Data/BUREAU_REFRESH_6M.csv'
DELIMITER ',' CSV HEADER;

-- 6. DPD HISTORY MONTHLY
COPY credit_risk.dpd_history
FROM 'D:/Data Analyst/Projects/Credit_Risk_Engine_Project/Data/DPD_HISTORY_MONTHLY.csv'
DELIMITER ',' CSV HEADER;

-- 7. BANK STATEMENT SUMMARY
COPY credit_risk.bank_statement
FROM 'D:/Data Analyst/Projects/Credit_Risk_Engine_Project/Data/BANK_STATEMENT_SUMMARY.csv'
DELIMITER ',' CSV HEADER;

-- 8. INCOME DOCUMENTS
COPY credit_risk.income_documents
FROM 'D:/Data Analyst/Projects/Credit_Risk_Engine_Project/Data/INCOME_DOCUMENT_PARSED.csv'
DELIMITER ',' CSV HEADER;

-- 9. ACCOUNT PORTFOLIO MONTHLY
COPY credit_risk.account_portfolio_monthly
FROM 'D:/Data Analyst/Projects/Credit_Risk_Engine_Project/Data/ACCOUNT_PORTFOLIO_MONTHLY.csv'
DELIMITER ',' CSV HEADER;

-- 10. REPAYMENT TRANSACTIONS
COPY credit_risk.repayment_transactions
FROM 'D:/Data Analyst/Projects/Credit_Risk_Engine_Project/Data/REPAYMENT_TRANSACTIONS.csv'
DELIMITER ',' CSV HEADER;

-- 11. SETTLEMENT CASES
COPY credit_risk.settlement_cases
FROM 'D:/Data Analyst/Projects/Credit_Risk_Engine_Project/Data/SETTLEMENT_CASES.csv'
DELIMITER ',' CSV HEADER;

-- 12. WRITE-OFF DATA
COPY credit_risk.write_off_data
FROM 'D:/Data Analyst/Projects/Credit_Risk_Engine_Project/Data/WRITE_OFF_DATA.csv'
DELIMITER ',' CSV HEADER;

-- 13. DISBURSEMENT DETAILS
COPY credit_risk.disbursement_details
FROM 'D:/Data Analyst/Projects/Credit_Risk_Engine_Project/Data/DISBURSEMENT_DETAILS.csv'
DELIMITER ',' CSV HEADER;

-- ════════════════════════════════════════════════════════════════
-- Credit Risk Engine — Master JOIN Query
-- Schema: credit_risk
-- Covers all 13 tables
-- Fan-out protection: multi-row tables pinned to latest record
-- ════════════════════════════════════════════════════════════════

-- SELECT
-- cm.customer_id,
--     cm.cif_number,
--     cm.customer_name,
--     cm.age,
--     cm.gender,
--     cm.marital_status,
--     cm.occupation_type,
--     cm.annual_income,
--     cm.city,
--     cm.state,
--     cm.kyc_status,
--     cm.own_rent_flag,
-- lm.loan_id,
--     lm.product_code,
--     lm.product_description,
--     lm.sanction_amount,
--     lm.interest_rate,
--     lm.tenure_months,
--     lm.emi_amount,
--     lm.loan_status,
--     lm.disbursement_date,
--     lm.maturity_date,
--     lm.branch_code,
--     lm.sourcing_channel,
-- af.application_id,
--     af.declared_income,
--     af.employment_type,
--     af.company_name,
--     af.company_category,
--     af.work_experience_years,
--     af.foir,
--     af.ltv_ratio,
--     af.co_applicant_flag,
--     af.loan_purpose,
--     af.application_status,
-- bc.bureau_score,
--     bc.total_tradelines,
--     bc.secured_tradelines,
--     bc.unsecured_tradelines,
--     bc.credit_utilisation_pct,
--     bc.recent_enquiries_3m,
--     bc.recent_enquiries_6m,
--     bc.max_dpd_12m,
--     bc.max_dpd_24m,
--     bc.number_of_defaults,
--     bc.written_off_accounts,
--     bc.suit_filed_flag,
--     bc.wilful_default_flag,
--     bc.bureau_pull_date,
-- br.refresh_cycle,
--     br.score_delta_vs_previous,
--     br.new_accounts_opened_3m,
--     br.bureau_pull_date                     AS refresh_pull_date,
-- dh.month_end_date                       AS latest_dpd_month,
--     dh.dpd                                  AS current_dpd,
--     dh.overdue_amount,
--     dh.bounce_flag                          AS latest_bounce_flag,
--     dh.asset_class,
--     dh.mob,
-- bs.avg_monthly_credit,
--     bs.avg_monthly_debit,
--     bs.avg_eod_balance,
--     bs.emi_bounce_count,
--     bs.salary_flag,
--     bs.cash_withdrawal_pct,
--     bs.gaming_txn_flag,
--     bs.casino_txn_flag,
--     bs.bank_name,
--     bs.account_type,
-- id.verified_income,
--     id.income_deviation_pct,
--     id.mismatch_flag,
--     id.mismatch_severity,
--     id.document_type,
--     id.verification_status,
-- apm.outstanding_principal,
--     apm.accrued_interest,
--     apm.dpd                                 AS portfolio_dpd,
--     apm.asset_class                         AS portfolio_asset_class,
--     apm.provision_amount,
--     apm.write_off_flag,
-- rt.txn_id                               AS latest_txn_id,
--     rt.txn_date                             AS latest_txn_date,
--     rt.txn_amount                           AS latest_txn_amount,
--     rt.payment_mode                         AS latest_payment_mode,
--     rt.bounce_flag                          AS latest_txn_bounce,
--     rt.bounce_reason,
-- sc.settlement_date,
--     sc.outstanding_at_settlement,
--     sc.settlement_amount,
--     sc.waiver_amount,
--     sc.waiver_percentage,
--     sc.settlement_type,
--     sc.noc_issued_flag,
-- wo.writeoff_date,
--     wo.writeoff_amount,
--     wo.writeoff_type,
--     wo.npa_date,
--     wo.dpd_at_writeoff,
--     wo.recovery_amount,
--     wo.recovery_channel,
-- dd.disbursement_tranche_no              AS latest_tranche_no,
--     dd.disbursement_date                    AS latest_disbursement_date,
--     dd.disbursed_amount                     AS latest_disbursed_amount,
--     dd.payment_mode                         AS disbursement_mode,
--     dd.beneficiary_ifsc
-- FROM credit_risk.customer_master cm
-- JOIN credit_risk.loan_master lm
--     ON cm.customer_id = lm.customer_id
-- LEFT JOIN (
--     SELECT DISTINCT ON (customer_id) *
--     FROM credit_risk.application_form
--     ORDER BY customer_id, application_date DESC
-- ) af ON cm.customer_id = af.customer_id
-- LEFT JOIN credit_risk.bureau_cibil bc
--     ON cm.customer_id = bc.customer_id
--     AND bc.bureau_agency = 'CIBIL'
-- LEFT JOIN (
--     SELECT DISTINCT ON (customer_id) *
--     FROM credit_risk.bureau_refresh
--     ORDER BY customer_id, bureau_pull_date DESC
-- ) br ON cm.customer_id = br.customer_id
-- LEFT JOIN (
--     SELECT DISTINCT ON (loan_id) *
--     FROM credit_risk.dpd_history
--     ORDER BY loan_id, month_end_date DESC
-- ) dh ON lm.loan_id = dh.loan_id
-- LEFT JOIN credit_risk.bank_statement bs
--     ON cm.customer_id = bs.customer_id
-- LEFT JOIN credit_risk.income_documents id
--     ON cm.customer_id = id.customer_id
-- LEFT JOIN (
--     SELECT DISTINCT ON (loan_id) *
--     FROM credit_risk.account_portfolio_monthly
--     ORDER BY loan_id, month_end_date DESC
-- ) apm ON lm.loan_id = apm.loan_id
-- LEFT JOIN (
--     SELECT DISTINCT ON (loan_id) *
--     FROM credit_risk.repayment_transactions
--     ORDER BY loan_id, txn_date DESC
-- ) rt ON lm.loan_id = rt.loan_id
-- LEFT JOIN credit_risk.settlement_cases sc
--     ON lm.loan_id = sc.loan_id
-- LEFT JOIN credit_risk.write_off_data wo
--     ON lm.loan_id = wo.loan_id
-- LEFT JOIN (
--     SELECT DISTINCT ON (loan_id) *
--     FROM credit_risk.disbursement_details
--     ORDER BY loan_id, disbursement_tranche_no DESC
-- ) dd ON lm.loan_id = dd.loan_id
-- ORDER BY cm.customer_id, lm.loan_id
-- LIMIT 10;
