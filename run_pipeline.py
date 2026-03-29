"""
run_pipeline.py
═══════════════════════════════════════════════════════════════
Credit Risk Engine — Full Pipeline Automation
Runs all steps in sequence: Feature Engineering → Model Training
→ Scoring → Monitoring → Dashboard Data Export

Usage:
    python run_pipeline.py              # run all steps
    python run_pipeline.py --step 2     # run from step 2 onwards
    python run_pipeline.py --only 4     # run only step 4

Steps:
    1  Data ingestion & schema validation
    2  Feature engineering → data/processed/model_dataset.csv
    3  Model training & validation → models/
    4  Scoring engine → scored_portfolio.csv
    5  Monthly monitoring → models/monitoring_report_*.json

Author : Sudipto Bhattacharya
Version: 2.0
═══════════════════════════════════════════════════════════════
"""

import os
import sys
import json
import math
import time
import warnings
import argparse
import traceback
from datetime import datetime
from pathlib import Path

import numpy as np
import pandas as pd

warnings.filterwarnings("ignore")

# ── Colour helpers for console output ──────────────────────────
GREEN  = "\033[92m"
YELLOW = "\033[93m"
RED    = "\033[91m"
CYAN   = "\033[96m"
RESET  = "\033[0m"
BOLD   = "\033[1m"

def ok(msg):    print(f"  {GREEN}✓{RESET}  {msg}")
def warn(msg):  print(f"  {YELLOW}⚠{RESET}  {msg}")
def err(msg):   print(f"  {RED}✗{RESET}  {msg}")
def info(msg):  print(f"  {CYAN}→{RESET}  {msg}")
def header(msg):
    print(f"\n{BOLD}{'═'*60}{RESET}")
    print(f"{BOLD}  {msg}{RESET}")
    print(f"{BOLD}{'═'*60}{RESET}")
def hr():
    print(f"  {'─'*54}")

# ── Paths ───────────────────────────────────────────────────────
# Works whether run from terminal (python run_pipeline.py)
# or from inside a Jupyter notebook cell (%run run_pipeline.py)
try:
    ROOT = Path("D:/Data Analyst/Projects/Credit_Risk_Engine_Project/credit-risk-engine-v2/credit-risk-engine/").parent
except NameError:
    ROOT = Path.cwd()   # fallback when __file__ is not defined (Jupyter)
DATA_RAW     = ROOT / "data" / "raw"
DATA_PROC    = ROOT / "data" / "processed"
MODELS_DIR   = ROOT / "models"
CONFIG_DIR   = ROOT / "config"
DASHBOARDS   = ROOT / "dashboards"
LOGS_DIR     = ROOT / "logs"

MODEL_DATASET   = DATA_PROC  / "model_dataset.csv"
SCORED_FILE     = DATA_PROC  / "scored_portfolio.csv"
GBM_PKL         = MODELS_DIR / "gbm_model.pkl"
SCALER_PKL      = MODELS_DIR / "scaler.pkl"
FEATURE_JSON    = MODELS_DIR / "feature_list.json"
METRICS_JSON    = MODELS_DIR / "metrics.json"
CUTOFF_YAML     = CONFIG_DIR / "scoring_cutoff.yaml"

# ── Run log ─────────────────────────────────────────────────────
RUN_LOG = []

def log_result(step, name, status, duration, detail=""):
    RUN_LOG.append({
        "step": step, "name": name, "status": status,
        "duration_s": round(duration, 2), "detail": detail,
    })


# ════════════════════════════════════════════════════════════════
# STEP 1 — Data Ingestion & Schema Validation
# ════════════════════════════════════════════════════════════════
def step1_ingest():
    header("STEP 1 — Data Ingestion & Schema Validation")
    t0 = time.time()

    SOURCE_MAP = {
        "customer":       "CUSTOMER_MASTER.csv",
        "loan":           "LOAN_MASTER_DAILY.csv",
        "application":    "APPLICATION_FORM_DATA.csv",
        "bureau":         "CIBIL_RAW_PULL.csv",
        "bureau_refresh": "BUREAU_REFRESH_6M.csv",
        "bank_statement": "BANK_STATEMENT_SUMMARY.csv",
        "income":         "INCOME_DOCUMENT_PARSED.csv",
        "dpd_history":    "DPD_HISTORY_MONTHLY.csv",
        "portfolio":      "ACCOUNT_PORTFOLIO_MONTHLY.csv",
        "repayment":      "REPAYMENT_TRANSACTIONS.csv",
        "settlement":     "SETTLEMENT_CASES.csv",
        "writeoff":       "WRITE_OFF_DATA.csv",
        "disbursement":   "DISBURSEMENT_DETAILS.csv",
    }

    SCHEMAS = {
        "customer":       ["customer_id", "age", "gender", "annual_income"],
        "loan":           ["loan_id", "customer_id", "sanction_amount", "loan_status"],
        "bureau":         ["customer_id", "bureau_score", "max_dpd_12m"],
        "application":    ["customer_id", "declared_income", "foir", "ltv_ratio"],
        "bank_statement": ["customer_id", "avg_monthly_credit", "emi_bounce_count"],
        "dpd_history":    ["loan_id", "dpd", "mob"],
    }

    dfs = {}
    missing_files = []

    for key, fname in SOURCE_MAP.items():
        fpath = DATA_RAW / fname
        if fpath.exists():
            dfs[key] = pd.read_csv(fpath, low_memory=False)
            ok(f"{key:18s} {dfs[key].shape[0]:>6,} rows × {dfs[key].shape[1]} cols")
        else:
            warn(f"{key:18s} NOT FOUND — {fname}")
            missing_files.append(fname)

    hr()
    # Schema validation
    schema_ok = True
    for name, required_cols in SCHEMAS.items():
        if name not in dfs:
            continue
        missing_cols = set(required_cols) - set(dfs[name].columns)
        if missing_cols:
            err(f"Schema FAIL [{name}]: missing columns {missing_cols}")
            schema_ok = False
        else:
            ok(f"Schema OK   : {name}")

    if missing_files:
        warn(f"{len(missing_files)} source file(s) missing — place CSVs in data/raw/")

    duration = time.time() - t0
    status = "OK" if schema_ok and not missing_files else "PARTIAL"
    info(f"Loaded {len(dfs)}/13 sources in {duration:.1f}s")
    log_result(1, "Data Ingestion", status, duration,
               f"{len(dfs)} files loaded, {len(missing_files)} missing")
    return dfs


# ════════════════════════════════════════════════════════════════
# STEP 2 — Feature Engineering
# ════════════════════════════════════════════════════════════════
def step2_features(dfs):
    header("STEP 2 — Feature Engineering")
    t0 = time.time()

    # ── Bureau features ───────────────────────────────────────
    _b = dfs["bureau"].copy()
    for col in ["suit_filed_flag", "wilful_default_flag"]:
        if col in _b.columns:
            _b[col] = _b[col].fillna(0).astype(int)

    _b["ever_dpd90_12m"]    = (_b["max_dpd_12m"] >= 90).astype(int)
    _b["ever_dpd90_24m"]    = (_b["max_dpd_24m"] >= 90).astype(int)
    _b["has_writeoff"]      = (_b.get("written_off_accounts", 0) > 0).astype(int)
    _b["high_enquiry_flag"] = (_b["recent_enquiries_3m"] >= 3).astype(int)
    _b["unsecured_mix_ratio"] = np.where(
        _b.get("total_tradelines", 0) > 0,
        _b.get("unsecured_tradelines", 0) / _b.get("total_tradelines", 1), 0
    )
    _score_map = {750: 5, 700: 4, 650: 3, 600: 2}
    _b["bureau_score_band_num"] = 1
    for thresh, val in _score_map.items():
        _b.loc[_b["bureau_score"] >= thresh, "bureau_score_band_num"] = val
    bureau_feats = _b
    ok(f"Bureau features    : {bureau_feats.shape[0]:,} rows, {bureau_feats.shape[1]} cols")

    # ── Behavioral / DPD features ─────────────────────────────
    _d = dfs["dpd_history"].copy()
    _d["bounce_flag"] = _d["bounce_flag"].astype(int)
    _agg = _d.groupby("loan_id").agg(
        max_dpd_ever         =("dpd",          "max"),
        max_overdue_amount   =("overdue_amount","max"),
        total_overdue_amount =("overdue_amount","sum"),
        total_bounces        =("bounce_flag",   "sum"),
        total_mob            =("mob",           "count"),
        max_mob              =("mob",           "max"),
    ).reset_index()
    _agg["bounce_rate"] = (_agg["total_bounces"] / _agg["total_mob"].clip(1)).round(4)
    _agg["max_dpd_12m_mob"] = _d[_d["mob"] <= 12].groupby("loan_id")["dpd"].max().reindex(_agg["loan_id"]).values
    _agg["max_dpd_6m_mob"]  = _d[_d["mob"] <= 6 ].groupby("loan_id")["dpd"].max().reindex(_agg["loan_id"]).values
    _last_delinq = (_d[_d["dpd"] > 0].groupby("loan_id")["mob"].max()
                    .reindex(_agg["loan_id"]).values)
    _agg["last_delinq_mob"]              = _last_delinq
    _agg["months_since_last_delinquency"]= _agg["max_mob"] - np.nan_to_num(_last_delinq)
    _agg["ever_npa_flag"] = (
        _d[_d["asset_class"].isin(["NPA","D1","D2","D3","LOSS"])]
        .groupby("loan_id").size().reindex(_agg["loan_id"]).fillna(0) > 0
    ).astype(int).values
    _agg["chronic_delinquent"] = (_agg["max_dpd_ever"] >= 60).astype(int)
    _agg["recent_stress_flag"] = ((_agg["max_dpd_6m_mob"].fillna(0)) >= 30).astype(int)
    behav_feats = _agg.merge(dfs["loan"][["loan_id","customer_id"]], on="loan_id", how="left")
    ok(f"Behavioral features: {behav_feats.shape[0]:,} rows, {behav_feats.shape[1]} cols")

    # ── Application features ──────────────────────────────────
    EMP_RISK = {
        "Salaried - Government":1,"Salaried - PSU":1,
        "Salaried - MNC":2,"Salaried - Private":2,
        "Self Employed - Professional":3,"Business - Proprietorship":3,
        "Business - Partnership":3,"Business - Private Limited":3,
        "Contract Employee":4,"Freelancer":5,
    }
    _af = dfs["application"].copy()
    _af["employment_risk_rank"] = _af.get("employment_type", pd.Series()).map(EMP_RISK).fillna(3)
    _af["high_foir_flag"] = (_af["foir"] > 0.60).astype(int)
    _af["high_ltv_flag"]  = (_af["ltv_ratio"] > 0.85).astype(int)
    _af["co_applicant_flag"] = _af.get("co_applicant_flag", 0).astype(int)
    _income = dfs["income"].copy()
    _income["income_deviation_pct"] = (
        (_income["declared_income"] - _income["verified_income"])
        / _income["verified_income"].clip(1) * 100
    ).round(2)
    _income["income_mismatch_flag"] = _income.get("mismatch_flag", 0).astype(int)
    _af = _af.merge(_income[["customer_id","verified_income","income_deviation_pct",
                              "income_mismatch_flag"]],
                    on="customer_id", how="left")
    _af["declared_to_verified_ratio"] = (
        _af["declared_income"] / _af["verified_income"].clip(1)
    ).round(4)
    app_feats = _af
    ok(f"Application features: {app_feats.shape[0]:,} rows, {app_feats.shape[1]} cols")

    # ── Bank/cashflow features ────────────────────────────────
    _bs = dfs["bank_statement"].copy()
    for col in ["salary_flag","gaming_txn_flag","casino_txn_flag"]:
        if col in _bs.columns:
            _bs[col] = _bs[col].fillna(0).astype(int)
    _bs["net_cashflow_ratio"]      = np.where(_bs["avg_monthly_credit"]>0,
        (_bs["avg_monthly_credit"]-_bs["avg_monthly_debit"])/_bs["avg_monthly_credit"], 0)
    _bs["emi_to_income_ratio"]     = np.where(_bs["avg_monthly_credit"]>0,
        _bs.get("avg_monthly_emi_outflow",0)/_bs["avg_monthly_credit"], 0)
    _bs["balance_to_income_ratio"] = np.where(_bs["avg_monthly_credit"]>0,
        _bs["avg_eod_balance"]/_bs["avg_monthly_credit"], 0)
    _tot_bounce = (_bs["emi_bounce_count"] +
                   _bs.get("inward_cheque_bounce_count",0) +
                   _bs.get("outward_cheque_bounce_count",0))
    _bs["high_stress_flag"] = (_tot_bounce >= 3).astype(int)
    _bs["high_cash_flag"]   = (_bs.get("cash_withdrawal_pct",0) > 40).astype(int)
    bank_feats = _bs
    ok(f"Bank/cashflow feat : {bank_feats.shape[0]:,} rows, {bank_feats.shape[1]} cols")

    # ── Target variable ───────────────────────────────────────
    _perf = dfs["dpd_history"]
    _perf = _perf[(_perf["mob"] >= 7) & (_perf["mob"] <= 18)]
    _target = (_perf.groupby("loan_id")
               .agg(target_default=("dpd", lambda x: int((x>=90).any())))
               .reset_index())
    _settled  = set(dfs["settlement"]["loan_id"]) if "settlement" in dfs else set()
    _writeoff = set(dfs["writeoff"]["loan_id"])   if "writeoff"   in dfs else set()
    _target["target_default"] = _target.apply(
        lambda r: 1 if r["target_default"]==1
                      or r["loan_id"] in _settled
                      or r["loan_id"] in _writeoff else 0, axis=1)
    ok(f"Target built       : default rate = {_target['target_default'].mean()*100:.1f}%  |  N={len(_target):,}")

    # ── Master join ───────────────────────────────────────────
    _loan_cols = ["loan_id","customer_id","product_code","sanction_amount",
                  "interest_rate","tenure_months","sourcing_channel"]
    _loan = dfs["loan"][[c for c in _loan_cols if c in dfs["loan"].columns]].copy()

    master = (_loan
              .merge(_target,     on="loan_id",     how="inner")
              .merge(behav_feats, on="loan_id",     how="left")
              .merge(bureau_feats,on="customer_id", how="left")
              .merge(bank_feats,  on="customer_id", how="left")
              .merge(app_feats,   on="customer_id", how="left", suffixes=("","_app")))
    ok(f"After join         : {master.shape[0]:,} rows × {master.shape[1]} cols")

    # ── Impute + winsorise ────────────────────────────────────
    OUTLIER_COLS = ["bureau_score","credit_utilisation_pct","total_outstanding",
                    "avg_monthly_credit","avg_eod_balance","declared_income",
                    "sanction_amount","max_overdue_amount"]
    for col in master.select_dtypes(include=[np.number]).columns:
        if master[col].isnull().any():
            master[col] = master[col].fillna(master[col].median())
    for col in master.select_dtypes(include=["object","category"]).columns:
        if master[col].isnull().any():
            master[col] = master[col].fillna(master[col].mode().iloc[0])
    for col in OUTLIER_COLS:
        if col in master.columns:
            lo, hi = master[col].quantile(0.01), master[col].quantile(0.99)
            master[col] = master[col].clip(lo, hi)

    DATA_PROC.mkdir(parents=True, exist_ok=True)
    master.to_csv(MODEL_DATASET, index=False)
    ok(f"Saved              → {MODEL_DATASET}")

    duration = time.time() - t0
    info(f"Feature engineering complete in {duration:.1f}s")
    log_result(2, "Feature Engineering", "OK", duration,
               f"{master.shape[0]} rows, {master.shape[1]} cols")
    return master


# ════════════════════════════════════════════════════════════════
# STEP 3 — Model Training & Validation
# ════════════════════════════════════════════════════════════════
def step3_train(master=None):
    header("STEP 3 — Model Training & Validation")
    t0 = time.time()

    from sklearn.model_selection import train_test_split, StratifiedKFold, cross_val_score
    from sklearn.ensemble import GradientBoostingClassifier
    from sklearn.linear_model import LogisticRegression
    from sklearn.preprocessing import StandardScaler
    from sklearn.metrics import roc_auc_score
    import joblib

    if master is None:
        if not MODEL_DATASET.exists():
            err("model_dataset.csv not found. Run step 2 first.")
            log_result(3, "Model Training", "SKIPPED", 0, "Dataset missing")
            return None, None
        master = pd.read_csv(MODEL_DATASET)
        info(f"Loaded from disk: {master.shape}")

    TARGET_COL = "target_default"
    EXCL = {TARGET_COL,"loan_id","customer_id","application_id",
            "observation_date","load_date","disbursement_date",
            "application_date","final_bad_flag","dpd30_flag","dpd60_flag",
            "settlement_flag","writeoff_flag"}

    features = [c for c in master.select_dtypes(include=[np.number]).columns
                if c not in EXCL]
    X = master[features].values
    y = master[TARGET_COL].values

    X_tr, X_te, y_tr, y_te = train_test_split(
        X, y, test_size=0.20, stratify=y, random_state=42)
    ok(f"Train: {len(X_tr):,}  |  Test: {len(X_te):,}  |  Default rate: {y.mean()*100:.1f}%")

    # GBM
    info("Training GradientBoostingClassifier (300 trees)...")
    gbm = GradientBoostingClassifier(
        n_estimators=300, max_depth=5, learning_rate=0.05,
        subsample=0.8, min_samples_leaf=15, random_state=42,
        validation_fraction=0.1, n_iter_no_change=20, tol=1e-4)
    cv = StratifiedKFold(5, shuffle=True, random_state=42)
    cv_s = cross_val_score(gbm, X_tr, y_tr, cv=cv, scoring="roc_auc")
    gbm.fit(X_tr, y_tr)
    gbm_auc = roc_auc_score(y_te, gbm.predict_proba(X_te)[:,1])
    gbm_gini = 2*gbm_auc - 1
    ok(f"GBM   AUC={gbm_auc:.4f}  Gini={gbm_gini:.4f}  CV={cv_s.mean():.4f}±{cv_s.std():.4f}")

    # Logistic
    info("Training Logistic Regression (baseline)...")
    sc = StandardScaler()
    lr = LogisticRegression(C=0.1, penalty="l2", solver="lbfgs",
                            max_iter=1000, class_weight="balanced", random_state=42)
    lr.fit(sc.fit_transform(X_tr), y_tr)
    lr_auc = roc_auc_score(y_te, lr.predict_proba(sc.transform(X_te))[:,1])
    ok(f"LR    AUC={lr_auc:.4f}  Gini={2*lr_auc-1:.4f}")

    # AUC gate
    if gbm_auc >= 0.70:
        ok(f"AUC gate PASSED ({gbm_auc:.4f} ≥ 0.70)")
    else:
        warn(f"AUC gate FAILED ({gbm_auc:.4f} < 0.70) — check features")

    # Save artifacts
    MODELS_DIR.mkdir(parents=True, exist_ok=True)
    joblib.dump(gbm, GBM_PKL)
    joblib.dump(lr,  MODELS_DIR/"logistic_model.pkl")
    joblib.dump(sc,  SCALER_PKL)
    with open(FEATURE_JSON, "w") as f:
        json.dump(features, f, indent=2)

    metrics = {
        "run": datetime.now().isoformat(),
        "train_size": len(X_tr), "test_size": len(X_te),
        "default_rate_pct": round(float(y.mean()*100), 2),
        "features": len(features),
        "gbm":     {"auc":round(gbm_auc,4),"gini":round(gbm_gini,4),"cv_mean":round(float(cv_s.mean()),4)},
        "logistic":{"auc":round(lr_auc,4), "gini":round(2*lr_auc-1,4)},
    }
    with open(METRICS_JSON, "w") as f:
        json.dump(metrics, f, indent=2)

    ok(f"Artifacts saved → models/")
    duration = time.time() - t0
    info(f"Training complete in {duration:.1f}s")
    log_result(3, "Model Training", "OK", duration,
               f"GBM AUC={gbm_auc:.4f}, Gini={gbm_gini:.4f}")
    return gbm, features


# ════════════════════════════════════════════════════════════════
# STEP 4 — Scoring Engine
# ════════════════════════════════════════════════════════════════
def step4_score(master=None, gbm=None, features=None):
    header("STEP 4 — Scoring Engine")
    t0 = time.time()

    import joblib, yaml

    # Load artifacts if not passed in
    if gbm is None:
        if not GBM_PKL.exists():
            err("GBM model not found. Run step 3 first.")
            log_result(4, "Scoring", "SKIPPED", 0, "Model missing")
            return None
        gbm = joblib.load(GBM_PKL)
    if features is None:
        with open(FEATURE_JSON) as f:
            features = json.load(f)
    if master is None:
        master = pd.read_csv(MODEL_DATASET)
        info(f"Loaded dataset: {master.shape}")

    with open(CUTOFF_YAML) as f:
        cutoffs = yaml.safe_load(f)

    _cfg = cutoffs["pd_to_score"]
    BASE_SCORE = _cfg["base_score"]
    PDO        = _cfg["pdo"]
    BASE_ODDS  = _cfg["base_odds"]
    BANDS      = cutoffs["score_bands"]

    def pd_to_score(pd_val):
        pd_val = max(1e-6, min(1-1e-6, pd_val))
        score  = BASE_SCORE + (PDO/math.log(2))*(math.log(BASE_ODDS)+math.log((1-pd_val)/pd_val))
        return round(max(200.0, min(900.0, score)), 1)

    def get_band(score):
        for b in BANDS:
            if b["min_score"] <= score <= b["max_score"]:
                return b
        return {"band":"D","risk_category":"Very High Risk",
                "recommended_action":"Decline","max_ltv":0.0,"max_foir":0.0}

    X    = master.reindex(columns=features, fill_value=0).values
    pds  = gbm.predict_proba(X)[:,1]

    scored = master.copy()
    scored["pd"]             = np.round(pds, 6)
    scored["score"]          = [pd_to_score(p) for p in pds]
    _bands                   = [get_band(s) for s in scored["score"]]
    scored["band"]           = [b["band"]               for b in _bands]
    scored["risk_category"]  = [b["risk_category"]      for b in _bands]
    scored["recommendation"] = [b["recommended_action"] for b in _bands]
    scored["max_ltv"]        = [b["max_ltv"]             for b in _bands]
    scored["max_foir"]       = [b["max_foir"]            for b in _bands]

    scored.to_csv(SCORED_FILE, index=False)
    ok(f"Scored {len(scored):,} records → {SCORED_FILE}")

    _dist = (scored.groupby("band")
             .agg(count=("loan_id","count"), avg_pd=("pd","mean"), avg_score=("score","mean"))
             .reset_index())
    _dist["pct"] = (_dist["count"]/len(scored)*100).round(1)
    hr()
    print(f"  {'Band':<6} {'Count':>6} {'Pct':>6}  {'Avg Score':>9}  {'Avg PD':>8}")
    for _, row in _dist.iterrows():
        print(f"  {row['band']:<6} {int(row['count']):>6} {row['pct']:>5.1f}%  {row['avg_score']:>9.1f}  {row['avg_pd']:>8.4f}")

    duration = time.time() - t0
    info(f"Scoring complete in {duration:.1f}s")
    log_result(4, "Scoring Engine", "OK", duration, f"{len(scored)} records scored")
    return scored


# ════════════════════════════════════════════════════════════════
# STEP 5 — Monthly Monitoring
# ════════════════════════════════════════════════════════════════
def step5_monitor(master=None, gbm=None, features=None):
    header("STEP 5 — Monthly Monitoring Pipeline")
    t0 = time.time()

    import joblib
    from scipy import stats
    from sklearn.metrics import roc_curve
    import matplotlib
    import sys
    # Only force Agg backend when NOT in Jupyter (avoids suppressing inline plots)
    if "ipykernel" not in sys.modules:
        matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    if gbm is None:
        gbm = joblib.load(GBM_PKL)
    if features is None:
        with open(FEATURE_JSON) as f:
            features = json.load(f)
    if master is None:
        master = pd.read_csv(MODEL_DATASET)

    RUN_LABEL = datetime.now().strftime("%Y%m")
    TARGET_COL = "target_default"

    # Score baseline and current (same data here — in production swap current)
    X_b = master.reindex(columns=features, fill_value=0).values
    p_b = gbm.predict_proba(X_b)[:,1]
    p_c = p_b.copy()   # same month — PSI expected ≈ 0

    # PSI
    def _psi(expected, actual, n_bins=10):
        eps  = 1e-4
        bins = np.unique(np.percentile(expected, np.linspace(0,100,n_bins+1)))
        if len(bins) < 3: return 0.0
        ep = np.histogram(expected, bins=bins)[0]
        ap = np.histogram(actual,   bins=bins)[0]
        ep_pct = np.where(ep==0, eps, ep/len(expected))
        ap_pct = np.where(ap==0, eps, ap/len(actual))
        return float(np.sum((ap_pct-ep_pct)*np.log(ap_pct/ep_pct)))

    def _psi_status(v):
        return "STABLE" if v<0.10 else "MONITOR" if v<0.20 else "RETRAIN"

    score_psi = _psi(p_b, p_c)
    ok(f"Score PSI     : {score_psi:.4f}  →  {_psi_status(score_psi)}")

    # KS
    y = master[TARGET_COL].values
    fpr, tpr, _ = roc_curve(y, p_c)
    ks_val = float(np.max(tpr-fpr))
    ks_st  = "EXCELLENT" if ks_val>=0.40 else "GOOD" if ks_val>=0.30 else "ACCEPTABLE" if ks_val>=0.20 else "POOR"
    ok(f"KS statistic  : {ks_val:.4f}  →  {ks_st}")

    # Default rate
    dr = float(y.mean()*100)
    ok(f"Default rate  : {dr:.2f}%")

    # Feature drift (top 10)
    num_feats = [f for f in features if f in master.columns and
                 pd.api.types.is_numeric_dtype(master[f])]
    drift_rows = []
    for col in num_feats[:30]:  # check first 30 features
        b = master[col].dropna().values
        c = b   # same data in demo
        if len(b) < 10: continue
        psi_v = _psi(b, c)
        ks_s, ks_p = stats.ks_2samp(b, c)
        drift_rows.append({"feature": col, "psi": round(psi_v,4),
                           "status": _psi_status(psi_v),
                           "ks_pval": round(ks_p,4),
                           "alert": psi_v>0.20 or ks_p<0.05})
    drift_df = pd.DataFrame(drift_rows).sort_values("psi", ascending=False)
    n_alerts = int(drift_df["alert"].sum())
    ok(f"Drift alerts  : {n_alerts} of {len(drift_rows)} features checked")

    # Action
    action = ("RETRAIN" if score_psi>0.20 else "MONITOR" if score_psi>0.10 else "NO_ACTION")
    ok(f"Action        : {action}")

    # Chart
    MODELS_DIR.mkdir(parents=True, exist_ok=True)
    fig, axes = plt.subplots(1, 2, figsize=(14, 5))
    fig.suptitle(f"Monitoring Report — {RUN_LABEL}", fontsize=14, fontweight="bold")
    axes[0].hist(p_b, bins=30, alpha=0.6, color="steelblue", label="Baseline", density=True)
    axes[0].hist(p_c, bins=30, alpha=0.6, color="coral",     label="Current",  density=True)
    axes[0].set_title("PD Distribution"); axes[0].legend(); axes[0].grid(alpha=0.3)
    axes[1].plot(range(len(tpr)), tpr, color="coral",     label="TPR (Bads)")
    axes[1].plot(range(len(fpr)), fpr, color="steelblue", label="FPR (Goods)")
    axes[1].set_title(f"KS = {ks_val:.4f}"); axes[1].legend(); axes[1].grid(alpha=0.3)
    plt.tight_layout()
    chart_path = MODELS_DIR/f"monitoring_chart_{RUN_LABEL}.png"
    plt.savefig(chart_path, dpi=150, bbox_inches="tight")
    plt.close()

    # Save report
    report = {
        "run_date": datetime.now().isoformat(), "run_label": RUN_LABEL,
        "baseline_rows": len(master), "current_rows": len(master),
        "score_psi": round(score_psi,4), "score_psi_status": _psi_status(score_psi),
        "ks": round(ks_val,4), "ks_status": ks_st,
        "default_rate_pct": round(dr,2), "drift_alerts": n_alerts,
        "features_checked": len(drift_rows), "action_required": action,
        "top_drifting": drift_df.head(10).to_dict(orient="records"),
    }
    report_path = MODELS_DIR/f"monitoring_report_{RUN_LABEL}.json"
    with open(report_path,"w") as f:
        json.dump(report, f, indent=2)
    with open(MODELS_DIR/"monitoring_report_latest.json","w") as f:
        json.dump(report, f, indent=2)
    drift_df.to_csv(MODELS_DIR/f"drift_report_{RUN_LABEL}.csv", index=False)

    ok(f"Report saved  → {report_path}")
    ok(f"Chart saved   → {chart_path}")

    duration = time.time() - t0
    info(f"Monitoring complete in {duration:.1f}s")
    log_result(5, "Monitoring", "OK", duration,
               f"PSI={score_psi:.4f}, KS={ks_val:.4f}, Action={action}")


# ════════════════════════════════════════════════════════════════
# SUMMARY
# ════════════════════════════════════════════════════════════════
def print_summary(total_time):
    header("PIPELINE SUMMARY")
    print(f"  {'Step':<4} {'Name':<25} {'Status':<10} {'Time':>7}  Detail")
    hr()
    for r in RUN_LOG:
        status_col = GREEN if r["status"]=="OK" else YELLOW if r["status"]=="PARTIAL" else RED
        print(f"  {r['step']:<4} {r['name']:<25} {status_col}{r['status']:<10}{RESET} {r['duration_s']:>6.1f}s  {r['detail'][:45]}")
    hr()
    print(f"  Total elapsed : {total_time:.1f}s")
    print(f"  Run timestamp : {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")


# ════════════════════════════════════════════════════════════════
# MAIN
# ════════════════════════════════════════════════════════════════
def main(start_step=1, only_step=None):
    """
    Run the full pipeline.

    Parameters (use when calling from a Jupyter notebook):
        start_step : int — run from this step onwards (default: 1 = all steps)
        only_step  : int — run only this single step (overrides start_step)

    From terminal:
        python run_pipeline.py              # all steps
        python run_pipeline.py --step 3    # from step 3 onwards
        python run_pipeline.py --only 4    # only step 4

    From Jupyter notebook cell:
        run_pipeline.main()                 # all steps
        run_pipeline.main(start_step=3)     # from step 3 onwards
        run_pipeline.main(only_step=4)      # only step 4
    """
    # ── Argument parsing — safe in both terminal and Jupyter ──────
    # argparse.parse_args() breaks in Jupyter because Jupyter passes
    # its own kernel arguments (-f kernel-xxx.json) to the process.
    # We detect the environment and skip argparse inside Jupyter.
    import sys
    _in_jupyter = "ipykernel" in sys.modules

    if not _in_jupyter:
        parser = argparse.ArgumentParser(
            description="Credit Risk Engine — Full Pipeline Automation")
        parser.add_argument("--step", type=int, default=1,
                            help="Run from this step onwards (1-5)")
        parser.add_argument("--only", type=int, default=None,
                            help="Run only this single step (1-5)")
        args = parser.parse_args()
        start_step = args.step
        only_step  = args.only

    print(f"\n{BOLD}{'═'*60}")
    print(f"  CREDIT RISK ENGINE v2.0 — PIPELINE RUNNER")
    print(f"  Started : {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    if _in_jupyter:
        print(f"  Mode    : Jupyter notebook")
    print(f"{'═'*60}{RESET}")

    start = time.time()
    dfs = master = gbm = features = scored = None

    steps_to_run = [only_step] if only_step else range(start_step, 6)

    try:
        if 1 in steps_to_run:
            dfs = step1_ingest()
        if 2 in steps_to_run:
            if dfs is None and 1 not in steps_to_run:
                warn("Step 1 not run — loading CSVs now for step 2")
                dfs = step1_ingest()
            master = step2_features(dfs)
        if 3 in steps_to_run:
            gbm, features = step3_train(master)
        if 4 in steps_to_run:
            scored = step4_score(master, gbm, features)
        if 5 in steps_to_run:
            step5_monitor(master, gbm, features)
    except KeyboardInterrupt:
        warn("Pipeline interrupted by user")
    except Exception as e:
        err(f"Pipeline failed: {e}")
        traceback.print_exc()

    print_summary(time.time() - start)


if __name__ == "__main__":
    main()
