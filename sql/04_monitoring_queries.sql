-- ════════════════════════════════════════════════════════════════
-- STEP 2: Monitoring Queries (Run Monthly)
-- ════════════════════════════════════════════════════════════════

-- 1. Portfolio Default Rate by Month
SELECT
    DATE_TRUNC('month', observation_date) AS cohort_month,
    COUNT(*)                              AS total_accounts,
    SUM(target_default)                   AS defaults,
    ROUND(AVG(target_default)*100, 2)     AS default_rate_pct
FROM credit_risk.v_target_labels
GROUP BY 1 ORDER BY 1;

-- 2. Default Rate by Product
SELECT
    lm.product_code,
    COUNT(*)                              AS total_loans,
    SUM(t.target_default)                 AS defaults,
    ROUND(AVG(t.target_default)*100, 2)   AS default_rate_pct,
    ROUND(AVG(lm.sanction_amount), 0)     AS avg_sanction_amount
FROM credit_risk.v_target_labels t
JOIN credit_risk.loan_master lm ON t.loan_id = lm.loan_id
GROUP BY 1 ORDER BY 4 DESC;

-- 3. Default Rate by Bureau Score Band
SELECT
    bf.bureau_score_band,
    COUNT(*)                              AS total,
    SUM(t.target_default)                 AS defaults,
    ROUND(AVG(t.target_default)*100, 2)   AS default_rate_pct
FROM credit_risk.v_target_labels t
JOIN credit_risk.loan_master lm ON t.loan_id = lm.loan_id
JOIN credit_risk.v_bureau_features bf ON lm.customer_id = bf.customer_id
GROUP BY 1 ORDER BY 4 DESC;

-- 4. NPA Migration Summary
SELECT
    month_end_date,
    asset_class,
    COUNT(*)                                AS accounts,
    SUM(outstanding_principal)              AS total_outstanding,
    SUM(provision_amount)                   AS total_provision,
    ROUND(SUM(provision_amount)/NULLIF(SUM(outstanding_principal),0)*100,2) AS pcr_pct
FROM credit_risk.account_portfolio_monthly
GROUP BY 1, 2 ORDER BY 1, 2;

-- 5. Write-Off & Recovery
SELECT
    DATE_TRUNC('year', writeoff_date)   AS writeoff_year,
    writeoff_type,
    COUNT(*)                            AS cases,
    SUM(writeoff_amount)                AS total_writeoff,
    SUM(recovery_amount)                AS total_recovery,
    ROUND(SUM(recovery_amount)/NULLIF(SUM(writeoff_amount),0)*100,2) AS recovery_rate_pct
FROM credit_risk.write_off_data
GROUP BY 1, 2 ORDER BY 1;

-- 6. Bounce Rate by Sourcing Channel
SELECT
    lm.sourcing_channel,
    COUNT(DISTINCT lm.loan_id)              AS loans,
    SUM(rt.bounce_flag::INT)                AS total_bounces,
    COUNT(rt.txn_id)                        AS total_txns,
    ROUND(SUM(rt.bounce_flag::INT)::NUMERIC/NULLIF(COUNT(rt.txn_id),0)*100,2) AS bounce_rate_pct
FROM credit_risk.loan_master lm
JOIN credit_risk.repayment_transactions rt ON lm.loan_id = rt.loan_id
GROUP BY 1 ORDER BY 5 DESC;
