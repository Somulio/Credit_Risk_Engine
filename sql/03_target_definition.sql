-- ════════════════════════════════════════════════════════════════
-- STEP 2: Target Variable Definition
-- Bad = DPD >= 90 in months 7-18 OR Settlement OR Write-Off
-- ════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW credit_risk.v_target_labels AS
WITH loan_windows AS (
    SELECT
        loan_id,
        customer_id,
        disbursement_date,
        disbursement_date + INTERVAL '6 months'  AS observation_date,
        disbursement_date + INTERVAL '18 months' AS performance_end_date
    FROM credit_risk.loan_master
    WHERE disbursement_date IS NOT NULL
),
performance AS (
    SELECT
        lw.loan_id,
        lw.customer_id,
        lw.observation_date,
        MAX(d.dpd)                                          AS max_dpd_in_window,
        MAX(CASE WHEN d.dpd >= 30  THEN 1 ELSE 0 END)      AS dpd30_flag,
        MAX(CASE WHEN d.dpd >= 60  THEN 1 ELSE 0 END)      AS dpd60_flag,
        MAX(CASE WHEN d.dpd >= 90  THEN 1 ELSE 0 END)      AS dpd90_flag,
        MAX(CASE WHEN d.dpd >= 120 THEN 1 ELSE 0 END)      AS dpd120_flag
    FROM loan_windows lw
    JOIN credit_risk.dpd_history d ON lw.loan_id = d.loan_id
    WHERE d.month_end_date > lw.observation_date
      AND d.month_end_date <= lw.performance_end_date
    GROUP BY lw.loan_id, lw.customer_id, lw.observation_date
)
SELECT
    p.loan_id,
    p.customer_id,
    p.observation_date,
    COALESCE(p.dpd30_flag, 0)                               AS dpd30_flag,
    COALESCE(p.dpd60_flag, 0)                               AS dpd60_flag,
    COALESCE(p.dpd90_flag, 0)                               AS dpd90_flag,
    COALESCE(p.max_dpd_in_window, 0)                        AS max_dpd_in_window,
    CASE WHEN sc.loan_id IS NOT NULL THEN 1 ELSE 0 END      AS settlement_flag,
    CASE WHEN wo.loan_id IS NOT NULL THEN 1 ELSE 0 END      AS writeoff_flag,
    -- FINAL BAD FLAG (target)
    CASE
        WHEN COALESCE(p.dpd90_flag, 0) = 1
          OR sc.loan_id IS NOT NULL
          OR wo.loan_id IS NOT NULL
        THEN 1 ELSE 0
    END                                                     AS target_default
FROM performance p
LEFT JOIN credit_risk.settlement_cases sc ON p.loan_id = sc.loan_id
LEFT JOIN credit_risk.write_off_data   wo ON p.loan_id = wo.loan_id;

SELECT * FROM credit_risk.v_target_labels LIMIT 10;

-- ─────────────────────────────────────────
-- FINAL MODELLING DATASET VIEW
-- ─────────────────────────────────────────
CREATE OR REPLACE VIEW credit_risk.v_modelling_dataset AS
SELECT
    f.*,
    t.target_default,
    t.dpd30_flag,
    t.dpd60_flag,
    t.settlement_flag,
    t.writeoff_flag,
    t.observation_date
FROM credit_risk.v_model_features f
JOIN credit_risk.v_target_labels t ON f.loan_id = t.loan_id;

SELECT * FROM credit_risk.v_modelling_dataset LIMIT 10;
