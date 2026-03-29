# 🏦 Credit Risk Engine v2.0

<p align="center">
  <img src="https://img.shields.io/badge/Python-3.10%2B-blue?logo=python&logoColor=white" />
  <img src="https://img.shields.io/badge/scikit--learn-1.4.0-orange?logo=scikitlearn&logoColor=white" />
  <img src="https://img.shields.io/badge/XGBoost-2.0.3-red" />
  <img src="https://img.shields.io/badge/Optuna-3.5.0-blueviolet" />
  <img src="https://img.shields.io/badge/PostgreSQL-Optional-336791?logo=postgresql&logoColor=white" />
  <img src="https://img.shields.io/badge/Status-Production--Grade-brightgreen" />
</p>

<p align="center">
  <b>End-to-end credit scoring system built on real NBFC/banking data.</b><br/>
  Raw loan applications → Feature engineering → GBM model → 200–900 credit score → Monthly drift monitoring
</p>

---

## 📊 Model Performance

| Metric | GBM (Primary) | Logistic (Benchmark) |
|--------|:---:|:---:|
| **AUC** | **0.7887** | 0.6863 |
| **Gini** | **0.5773** | 0.3726 |
| **KS** | **0.5306** | — |
| **CV Mean AUC** | **0.8049** | — |
| Features used | 86 | 86 |
| Train / Test split | 240 / 60 | — |

> **Target definition:** Bad flag = DPD ≥ 90 within months 7–18, OR Settlement, OR Write-Off  
> Observation window: 6 months · Performance window: 12 months

---

## 🗂️ Project Structure

```
credit-risk-engine/
├── run_pipeline.py                 ← One-command end-to-end automation
├── requirements.txt
├── .gitignore
│
├── notebooks/                      ← Step-by-step Jupyter workflow
│   ├── 1_EDA.ipynb                 ← Exploratory data analysis
│   ├── 2_Load_raw_data_and_Feature_Engineering.ipynb
│   ├── 3_Validate_Model_Performance.ipynb
│   ├── 4_Scoring_engine.ipynb      ← Log-odds PDO score scaling (200–900)
│   └── 5_Monitoring.ipynb          ← PSI / KS / AUC monthly drift checks
│
├── sql/                            ← PostgreSQL DDL + feature views
│   ├── 01_create_base_tables.sql
│   ├── 02_feature_views.sql
│   ├── 03_target_definition.sql
│   └── 04_monitoring_queries.sql
│
├── config/
│   ├── config.yaml                 ← Data paths, target definition, thresholds
│   ├── model_config.yaml           ← GBM / XGBoost / LR hyperparameters
│   └── scoring_cutoff.yaml         ← A1–D score bands, LTV & FOIR limits
│
├── data/
│   ├── raw/                        ← 13 source CSVs (place here)
│   ├── interim/
│   └── processed/                  ← model_dataset.csv produced here
│
├── models/                         ← Serialised artifacts
│   ├── gbm_model.pkl
│   ├── logistic_model.pkl
│   ├── scaler.pkl
│   ├── feature_list.json
│   ├── metrics.json
│   └── model_metadata.json
│
├── dashboards/
│   └── credit_risk_dashboard.html  ← Browser-based KPI dashboard
│
└── logs/
```

---

## ⚙️ Pipeline Architecture

```
 13 Raw Source Tables
        │
        ▼
 [Notebook 1] EDA
   Vintage analysis · Bureau distributions · Target rate
        │
        ▼
 [Notebook 2] Feature Engineering          ← 86 features engineered
   DPD roll-rates · Bureau WOE · FOIR · Repayment ratios
        │
        ▼
 [Notebook 3] Model Training & Validation
   GBM (primary)  ←→  Logistic (benchmark)
   AUC · Gini · KS · Lift table · Confusion matrix
        │
        ▼
 [Notebook 4] Score Scaling
   PD → Log-odds → PDO scaling → 200–900 score → A1–D band
        │
        ▼
 [Notebook 5] Monthly Monitoring
   PSI · KS drift · AUC drift · Retrain trigger alerts
```

---

## 🚀 Quick Start

### 1. Clone & install dependencies

```bash
git clone https://github.com/Somulio/credit-risk-engine.git
cd credit-risk-engine
pip install -r requirements.txt
```

### 2. Place source CSVs in `data/raw/`

The pipeline expects these 13 files:

| File | Description |
|------|-------------|
| `CUSTOMER_MASTER.csv` | Demographics, KYC |
| `LOAN_MASTER_DAILY.csv` | Loan-level master data |
| `APPLICATION_FORM_DATA.csv` | Application attributes |
| `CIBIL_RAW_PULL.csv` | CIBIL bureau pull |
| `BUREAU_REFRESH_6M.csv` | 6-month bureau refresh |
| `BANK_STATEMENT_SUMMARY.csv` | Bank statement analytics |
| `INCOME_DOCUMENT_PARSED.csv` | Parsed income documents |
| `DPD_HISTORY_MONTHLY.csv` | Monthly DPD history |
| `ACCOUNT_PORTFOLIO_MONTHLY.csv` | Portfolio snapshots |
| `REPAYMENT_TRANSACTIONS.csv` | Transaction-level repayments |
| `SETTLEMENT_CASES.csv` | Settlement records |
| `WRITE_OFF_DATA.csv` | Write-off records |
| `DISBURSEMENT_DETAILS.csv` | Disbursement details |

### 3. Run the full pipeline

```bash
python run_pipeline.py
```

### 4. Run individual steps

```bash
python run_pipeline.py --only 2   # Feature engineering only
python run_pipeline.py --step 3   # From training onwards
python run_pipeline.py --only 5   # Monitoring only
```

### 5. Run notebooks interactively (Jupyter)

```bash
jupyter notebook
```

Open in sequence: `1_EDA` → `2_Feature_Engineering` → `3_Validate` → `4_Score` → `5_Monitor`

---

## 🎯 Score Bands & Credit Policy

Score is scaled using **PDO = 20**, base score = 800, base odds = 50:1.

| Band | Score Range | Risk Category | Decision | Max LTV | Max FOIR |
|------|:-----------:|---------------|----------|:-------:|:--------:|
| **A1** | 750 – 900 | Very Low | Auto Approve | 90% | 65% |
| **A2** | 700 – 749 | Low | Approve — Standard Terms | 85% | 60% |
| **B1** | 650 – 699 | Moderate | Approve — Enhanced Scrutiny | 80% | 55% |
| **B2** | 600 – 649 | Elevated | Credit Committee Review | 75% | 50% |
| **C**  | 550 – 599 | High | Reject / Additional Collateral | 65% | 45% |
| **D**  | 200 – 549 | Very High | Decline | 0% | 0% |

---

## 🔍 Monitoring Thresholds

| Metric | Threshold | Action |
|--------|-----------|--------|
| PSI | > 0.20 | Trigger retrain |
| KS | < 0.30 | Review model |
| AUC | < 0.70 | Escalate to model risk |
| Drift check | Every 30 days | Automated via Notebook 5 |

---

## 🗄️ PostgreSQL Path (Optional)

If using an existing PostgreSQL database, run the SQL scripts in order before the Python pipeline:

```bash
psql -U postgres -d credit_risk_db -f sql/01_create_base_tables.sql
psql -U postgres -d credit_risk_db -f sql/02_feature_views.sql
psql -U postgres -d credit_risk_db -f sql/03_target_definition.sql
psql -U postgres -d credit_risk_db -f sql/04_monitoring_queries.sql
```

Then query `credit_risk.v_modelling_dataset` directly instead of running the Python feature pipeline. SQLAlchemy + psycopg2 are included in `requirements.txt`.

---

## 📈 Dashboard

Open `dashboards/credit_risk_dashboard.html` in any browser for the Power BI–style KPI dashboard.

**Covers:**
- Portfolio overview & delinquency trends
- Collections performance & roll-rate analysis
- Model score distribution & Gini curves
- Monthly PSI / drift monitoring
- Geographic risk breakdown

---

## 🛠️ Technology Stack

| Layer | Technology |
|-------|------------|
| Language | Python 3.10+ |
| Primary ML | GradientBoostingClassifier (scikit-learn) + XGBoost |
| Benchmark | Logistic Regression |
| Hyperparameter tuning | Optuna |
| Data processing | pandas · numpy · scipy |
| Visualisation | matplotlib · seaborn · plotly |
| Config management | PyYAML · python-dotenv |
| Database (optional) | PostgreSQL · SQLAlchemy · psycopg2 |
| Notebooks | Jupyter |
| Dashboard | HTML / CSS / JavaScript |
| Automation | `run_pipeline.py` |

---

## 💡 Key Features

- **Production-ready ML pipeline** — 13 source tables, 86 engineered features, configurable target definition
- **Dual-model architecture** — GBM as primary scorer with Logistic Regression as interpretable challenger
- **Industry-standard score scaling** — Log-odds PDO methodology matching RBI / Basel II conventions
- **Automated monitoring** — PSI, KS, and AUC drift checks with configurable retrain triggers
- **Reproducible** — All hyperparameters, thresholds, and data paths in versioned YAML configs
- **SQL-first option** — Full PostgreSQL DDL + view layer for teams preferring a database-first workflow
- **Zero-dependency dashboard** — Single HTML file, no server required

---

## 📁 Key Output Artifacts

| Artifact | Path | Description |
|----------|------|-------------|
| Trained model | `models/gbm_model.pkl` | Serialised GBM scorer |
| Scaler | `models/scaler.pkl` | StandardScaler for numeric features |
| Feature list | `models/feature_list.json` | 86 features used at inference |
| Metrics | `models/metrics.json` | AUC, Gini, KS, PSI, lift table |
| Model metadata | `models/model_metadata.json` | Run timestamp, train/test sizes |
| Dashboard | `dashboards/credit_risk_dashboard.html` | Standalone KPI dashboard |
| Processed dataset | `data/processed/model_dataset.csv` | Final modelling dataset |

---

## 👤 Author

**Sudipto Bhattacharya**  
Data / Credit Risk Analyst  
📍 Kolkata, India  
🔗 [GitHub](https://github.com/Somulio)

---

## 📄 License

This project is for portfolio and educational purposes. All data used is synthetic or anonymised.

---

*Built on real NBFC organisational data patterns · 13 source tables · 86 engineered features · Full ML lifecycle*
