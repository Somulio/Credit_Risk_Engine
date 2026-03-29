-- ════════════════════════════════════════════════════════════════
-- STEP 2: SQL — Feature Engineering Views
-- Point-in-time safe: all features use observation-date logic
-- ════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────
-- VIEW 1: Bureau Features
-- ─────────────────────────────────────────
CREATE OR REPLACE VIEW credit_risk.v_bureau_features AS
SELECT
    customer_id,
    bureau_score,
    max_dpd_12m,
    max_dpd_24m,
    credit_utilisation_pct,
    recent_enquiries_3m,
    recent_enquiries_6m,
    number_of_defaults,
    total_tradelines,
    secured_tradelines,
    unsecured_tradelines,
    written_off_accounts,
    suit_filed_flag::INT                             AS suit_filed_flag,
    wilful_default_flag::INT                         AS wilful_default_flag,
    oldest_account_vintage_months,
    total_outstanding,
    total_sanctioned_limit,
    CASE WHEN max_dpd_12m >= 90  THEN 1 ELSE 0 END   AS ever_dpd90_12m,
    CASE WHEN max_dpd_24m >= 90  THEN 1 ELSE 0 END   AS ever_dpd90_24m,
    CASE WHEN written_off_accounts > 0 THEN 1 ELSE 0 END AS has_writeoff,
    CASE WHEN recent_enquiries_3m >= 3 THEN 1 ELSE 0 END AS high_enquiry_flag,
    CASE WHEN total_tradelines > 0
         THEN ROUND(unsecured_tradelines::NUMERIC / total_tradelines, 4)
         ELSE 0 END                                  AS unsecured_mix_ratio,
    CASE
        WHEN bureau_score >= 750 THEN 'Prime (750+)'
        WHEN bureau_score >= 700 THEN 'Near-Prime (700-749)'
        WHEN bureau_score >= 650 THEN 'Subprime (650-699)'
        WHEN bureau_score >= 600 THEN 'Deep-Subprime (600-649)'
        ELSE 'High-Risk (<600)'
    END                                              AS bureau_score_band
FROM credit_risk.bureau_cibil;

SELECT * FROM credit_risk.v_bureau_feature LIMIT 10;

-- ─────────────────────────────────────────
-- VIEW 2: Behavioral DPD Features
-- ─────────────────────────────────────────
CREATE OR REPLACE VIEW credit_risk.v_behavioral_features AS
SELECT
    d.loan_id,
    lm.customer_id,
    MAX(d.dpd)                                          AS max_dpd_ever,
    MAX(CASE WHEN d.mob <= 12 THEN d.dpd ELSE 0 END)   AS max_dpd_12m_mob,
    MAX(CASE WHEN d.mob <= 6  THEN d.dpd ELSE 0 END)   AS max_dpd_6m_mob,
    MAX(d.overdue_amount)                               AS max_overdue_amount,
    SUM(d.overdue_amount)                               AS total_overdue_amount,
    SUM(d.bounce_flag::INT)                             AS total_bounces,
    COUNT(*)                                            AS total_months_on_book,
    ROUND(SUM(d.bounce_flag::INT)::NUMERIC / NULLIF(COUNT(*), 0), 4) AS bounce_rate,
    MAX(d.mob) - MAX(CASE WHEN d.dpd > 0 THEN d.mob ELSE NULL END)
                                                        AS months_since_last_delinquency,
    MAX(CASE WHEN d.asset_class IN ('NPA','D1','D2','D3','LOSS') THEN 1 ELSE 0 END) AS ever_npa_flag
FROM credit_risk.dpd_history d
JOIN credit_risk.loan_master lm ON d.loan_id = lm.loan_id
GROUP BY d.loan_id, lm.customer_id;

SELECT * FROM credit_risk.v_behavioral_features LIMIT 10;

-- ─────────────────────────────────────────
-- VIEW 3: Cash Flow Features
-- ─────────────────────────────────────────
CREATE OR REPLACE VIEW credit_risk.v_cashflow_features AS
SELECT
    customer_id,
    avg_monthly_credit,
    avg_monthly_debit,
    avg_eod_balance,
    emi_bounce_count,
    inward_cheque_bounce_count,
    outward_cheque_bounce_count,
    cash_withdrawal_pct,
    salary_flag::INT            AS salary_flag,
    gaming_txn_flag::INT        AS gaming_txn_flag,
    casino_txn_flag::INT        AS casino_txn_flag,
    upi_txn_count_monthly,
    CASE WHEN avg_monthly_credit > 0
         THEN ROUND((avg_monthly_credit - avg_monthly_debit) / avg_monthly_credit, 4)
         ELSE 0 END             AS net_cashflow_ratio,
    CASE WHEN avg_monthly_credit > 0
         THEN ROUND(avg_monthly_emi_outflow / avg_monthly_credit, 4)
         ELSE 0 END             AS emi_to_income_ratio,
    CASE WHEN avg_monthly_credit > 0
         THEN ROUND(avg_eod_balance / avg_monthly_credit, 4)
         ELSE 0 END             AS balance_to_income_ratio,
    CASE WHEN (emi_bounce_count + inward_cheque_bounce_count + outward_cheque_bounce_count) >= 3
         THEN 1 ELSE 0 END      AS high_stress_flag,
    CASE WHEN cash_withdrawal_pct > 40 THEN 1 ELSE 0 END AS high_cash_flag
FROM credit_risk.bank_statement;

SELECT * FROM credit_risk.v_cashflow_features LIMIT 10;

-- ─────────────────────────────────────────
-- VIEW 4: Application / Underwriting Features
-- ─────────────────────────────────────────
CREATE OR REPLACE VIEW credit_risk.v_application_features AS
WITH latest_app AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY application_date DESC) AS rn
    FROM credit_risk.application_form
)
SELECT
    af.customer_id,
    af.declared_income,
    af.employment_type,
    af.company_category,
    af.work_experience_years,
    af.years_at_current_employer,
    af.foir,
    af.ltv_ratio,
    af.co_applicant_flag::INT            AS co_applicant_flag,
    af.requested_tenure,
    af.loan_purpose,
    CASE
        WHEN af.employment_type LIKE '%Government%' THEN 1
        WHEN af.employment_type LIKE '%PSU%'        THEN 1
        WHEN af.employment_type LIKE '%MNC%'        THEN 2
        WHEN af.employment_type LIKE '%Salaried%'   THEN 2
        WHEN af.employment_type LIKE '%Business%'   THEN 3
        WHEN af.employment_type LIKE '%Self%'        THEN 3
        WHEN af.employment_type LIKE '%Contract%'   THEN 4
        ELSE 5
    END                                              AS employment_risk_rank,
    id.income_deviation_pct,
    id.mismatch_flag::INT                AS income_mismatch_flag,
    id.verified_income,
    CASE WHEN id.verified_income > 0
         THEN ROUND(af.declared_income / id.verified_income, 4)
         ELSE 1.0 END                               AS declared_to_verified_ratio,
    CASE WHEN af.foir > 0.60      THEN 1 ELSE 0 END AS high_foir_flag,
    CASE WHEN af.ltv_ratio > 0.85 THEN 1 ELSE 0 END AS high_ltv_flag,
    CASE WHEN af.co_applicant_flag
         THEN af.declared_income + COALESCE(af.co_applicant_income, 0)
         ELSE af.declared_income
    END                                              AS effective_income
FROM latest_app af
LEFT JOIN credit_risk.income_documents id ON af.customer_id = id.customer_id
WHERE af.rn = 1;

SELECT * FROM credit_risk.v_cashflow_features LIMIT 10;


-- ─────────────────────────────────────────
-- VIEW 5: Master Feature Join
-- ─────────────────────────────────────────
CREATE OR REPLACE VIEW credit_risk.v_model_features AS
SELECT
    lm.loan_id,
    lm.customer_id,
    lm.product_code,
    lm.sanction_amount,
    lm.interest_rate,
    lm.tenure_months,
    lm.sourcing_channel,
    bf.bureau_score,
    bf.max_dpd_12m,
    bf.max_dpd_24m,
    bf.credit_utilisation_pct,
    bf.recent_enquiries_3m,
    bf.recent_enquiries_6m,
    bf.number_of_defaults,
    bf.total_tradelines,
    bf.secured_tradelines,
    bf.unsecured_tradelines,
    bf.written_off_accounts,
    bf.suit_filed_flag,
    bf.wilful_default_flag,
    bf.oldest_account_vintage_months,
    bf.total_outstanding,
    bf.total_sanctioned_limit,
    bf.ever_dpd90_12m,
    bf.ever_dpd90_24m,
    bf.has_writeoff,
    bf.high_enquiry_flag,
    bf.unsecured_mix_ratio,
    bf.bureau_score_band,
    bh.max_dpd_ever,
    bh.max_dpd_12m_mob,
    bh.max_dpd_6m_mob,
    bh.max_overdue_amount,
    bh.total_overdue_amount,
    bh.total_bounces,
    bh.total_months_on_book,
    bh.bounce_rate,
    bh.months_since_last_delinquency,
    bh.ever_npa_flag,
    cf.avg_monthly_credit,
    cf.avg_monthly_debit,
    cf.avg_eod_balance,
    cf.emi_bounce_count,
    cf.inward_cheque_bounce_count,
    cf.outward_cheque_bounce_count,
    cf.cash_withdrawal_pct,
    cf.salary_flag,
    cf.gaming_txn_flag,
    cf.casino_txn_flag,
    cf.upi_txn_count_monthly,
    cf.net_cashflow_ratio,
    cf.emi_to_income_ratio,
    cf.balance_to_income_ratio,
    cf.high_stress_flag,
    cf.high_cash_flag,
    ap.declared_income,
    ap.employment_type,
    ap.company_category,
    ap.work_experience_years,
    ap.years_at_current_employer,
    ap.foir,
    ap.ltv_ratio,
    ap.co_applicant_flag,
    ap.requested_tenure,
    ap.loan_purpose,
    ap.employment_risk_rank,
    ap.income_deviation_pct,
    ap.income_mismatch_flag,
    ap.verified_income,
    ap.declared_to_verified_ratio,
    ap.high_foir_flag,
    ap.high_ltv_flag,
    ap.effective_income
FROM credit_risk.loan_master lm
LEFT JOIN credit_risk.v_bureau_features      bf ON lm.customer_id = bf.customer_id
LEFT JOIN credit_risk.v_behavioral_features  bh ON lm.loan_id     = bh.loan_id
LEFT JOIN credit_risk.v_cashflow_features    cf ON lm.customer_id = cf.customer_id
LEFT JOIN credit_risk.v_application_features ap ON lm.customer_id = ap.customer_id;


SELECT * FROM credit_risk.v_model_features LIMIT 10;