# Credit Risk Engine v2.0

> Production-grade credit scoring system built on real NBFC/banking data.  
> GBM primary model · AUC 0.81 · Gini 0.61 · KS 0.51

---

## Project Overview

This project builds an end-to-end credit risk scoring engine that takes raw loan application data, engineers predictive features, trains a Gradient Boosting model, converts predicted default probabilities into a 200–900 credit score, and monitors the model monthly for drift.

**Data**: 13 source tables · 77+ engineered features · ~300 loan accounts  
**Target**: Bad flag = DPD ≥ 90 within months 7–18 OR Settlement OR Write-Off

---

## Model Performance

| Metric | GBM (Primary) | Logistic (Benchmark) |
|--------|:---:|:---:|
| **AUC** | **0.8065** | 0.6652 |
| **Gini** | **0.6129** | 0.3304 |
| **KS** | **0.5095** | 0.3215 |
| Features | 77 | 77 |

---

## Project Structure

```
credit-risk-engine/
├── run_pipeline.py              ← Automation: runs all 5 steps end-to-end
├── requirements.txt
├── .gitignore
│
├── sql/                         ← PostgreSQL DDL + feature views
│   ├── 01_create_base_tables.sql
│   ├── 02_feature_views.sql
│   ├── 03_target_definition.sql
│   └── 04_monitoring_queries.sql
│
├── config/
│   ├── config.yaml              ← data paths, target definition, thresholds
│   ├── model_config.yaml        ← GBM/LR hyperparameters
│   └── scoring_cutoff.yaml      ← A1–D score bands + LTV/FOIR limits
│
├── notebooks/                   ← Step-by-step Jupyter workflow
│   ├── 1_EDA.ipynb
│   ├── 2_Load_raw_data_and_Feature_Engineering.ipynb
│   ├── 3_Validate_Model_Performance.ipynb
│   ├── 4_Scoring_engine.ipynb
│   └── 5_Monitoring.ipynb
│
├── dashboards/
│   └── credit_risk_dashboard.html   ← Power BI–style KPI dashboard
│
├── data/
│   ├── raw/                     ← Place all 13 source CSVs here
│   └── processed/               ← model_dataset.csv produced here
│
├── models/                      ← Trained artifacts
│   ├── gbm_model.pkl
│   ├── logistic_model.pkl
│   ├── scaler.pkl
│   ├── feature_list.json
│   └── metrics.json
│
└── logs/
```

---

## Quick Start

### 1. Install dependencies
```bash
pip install -r requirements.txt
```

### 2. Place source CSVs in `data/raw/`
The pipeline expects these 13 files:
- CUSTOMER_MASTER.csv, LOAN_MASTER_DAILY.csv, APPLICATION_FORM_DATA.csv
- CIBIL_RAW_PULL.csv, BUREAU_REFRESH_6M.csv, BANK_STATEMENT_SUMMARY.csv
- INCOME_DOCUMENT_PARSED.csv, DPD_HISTORY_MONTHLY.csv
- ACCOUNT_PORTFOLIO_MONTHLY.csv, REPAYMENT_TRANSACTIONS.csv
- SETTLEMENT_CASES.csv, WRITE_OFF_DATA.csv, DISBURSEMENT_DETAILS.csv

### 3. Run the full pipeline (automated)
```bash
python run_pipeline.py
```

### 4. Run individual steps
```bash
python run_pipeline.py --only 2   # feature engineering only
python run_pipeline.py --step 3   # from training onwards
python run_pipeline.py --only 5   # monitoring only
```

### 5. Or run notebooks interactively (Jupyter)
```bash
jupyter notebook
```
Open notebooks in order: `1_EDA` → `2_Feature_Engineering` → `3_Validate` → `4_Score` → `5_Monitor`

---

## Score Bands

| Band | Score | Risk | Decision | Max LTV | Max FOIR |
|------|-------|------|----------|---------|---------|
| **A1** | 750–900 | Very Low | Auto Approve | 90% | 65% |
| **A2** | 700–749 | Low | Approve Standard | 85% | 60% |
| **B1** | 650–699 | Moderate | Enhanced Scrutiny | 80% | 55% |
| **B2** | 600–649 | Elevated | Credit Committee | 75% | 50% |
| **C** | 550–599 | High | Reject / Collateral | 65% | 45% |
| **D** | 200–549 | Very High | Decline | 0% | 0% |

---

## Dashboard

Open `dashboards/credit_risk_dashboard.html` in any browser for the Power BI–style KPI dashboard covering portfolio overview, delinquency trends, collections, model monitoring, and geographic risk.

---

## SQL Path (PostgreSQL)

If using PostgreSQL, run the SQL files in order before the Python pipeline:
```bash
psql -U postgres -d credit_risk_db -f sql/01_create_base_tables.sql
psql -U postgres -d credit_risk_db -f sql/02_feature_views.sql
psql -U postgres -d credit_risk_db -f sql/03_target_definition.sql
psql -U postgres -d credit_risk_db -f sql/04_monitoring_queries.sql
```
Then query `credit_risk.v_modelling_dataset` directly instead of running the Python feature pipeline.

---

## Technology Stack

| Component | Technology |
|-----------|-----------|
| Language | Python 3.10+ |
| ML Primary | GradientBoostingClassifier (scikit-learn) |
| ML Benchmark | Logistic Regression |
| Database | PostgreSQL (optional) |
| Notebooks | Jupyter |
| Dashboard | HTML / Power BI Desktop |
| Automation | run_pipeline.py |

---

*Built on real NBFC organisational data · 13 source tables · 77+ engineered features*
