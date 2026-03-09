# 🏦 Credit Risk Engine

<p align="center">
  <img src="https://img.shields.io/badge/Python-3.10%2B-3776AB?style=for-the-badge&logo=python&logoColor=white" />
  <img src="https://img.shields.io/badge/scikit--learn-GBM%20%7C%20LR-F7931E?style=for-the-badge&logo=scikitlearn&logoColor=white" />
  <img src="https://img.shields.io/badge/Flask-REST%20API-000000?style=for-the-badge&logo=flask&logoColor=white" />
  <img src="https://img.shields.io/badge/Docker-Containerised-2496ED?style=for-the-badge&logo=docker&logoColor=white" />
  <img src="https://img.shields.io/badge/CI-GitHub%20Actions-2088FF?style=for-the-badge&logo=githubactions&logoColor=white" />
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" />
</p>

<p align="center">
  <strong>Production-grade credit risk scoring system built on real NBFC/banking data.</strong><br/>
  13 source tables · 86 engineered features · GBM primary model · AUC 0.81 · Gini 0.58 · KS 0.53
</p>

---

## 📊 Model Performance

| Metric | GBM (Primary) | Logistic (Challenger) | Gate |
|--------|:---:|:---:|:---:|
| **AUC** | **0.8049** *(5-fold CV)* | 0.6863 | ≥ 0.70 ✅ |
| **Gini** | **0.5773** | 0.3726 | ≥ 0.40 ✅ |
| **KS** | **0.5306** | 0.3215 | ≥ 0.30 ✅ |
| **PSI** | 1.28 | — | < 0.20 ⚠️ retrain |
| Features | 86 | 86 | — |
| Train / Test | 240 / 60 | 240 / 60 | — |

> **Target definition:** DPD ≥ 90 in months on book 7–18 **∪** Settlement **∪** Write-off

<p align="center">
  <img src="docs/images/roc_and_score_dist.png" width="49%" alt="ROC and Score Distribution" />
  <img src="docs/images/feature_importance_top25.png" width="49%" alt="Top 25 Feature Importance" />
</p>

📌 To enable these charts: run python -m src.model.evaluate, copy the generated PNGs from models/ into docs/images/, and commit them. The docs/images/ folder is safe to commit (only models/*.pkl is gitignored).

---

## 🏗️ Architecture

```
13 CSV Sources  (raw/)
      │
      ▼
┌──────────────────────────────────────────────────────┐
│  STEP 1 — Ingestion & Schema Validation              │
│  src/ingestion/  ·  load_raw_data.py + validate.py   │
└─────────────────────────┬────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────┐
│  STEP 2 — SQL Feature Engineering (4 SQL files)      │
│  PostgreSQL views: bureau + behavioural + cashflow   │
│  Point-in-time safe  ·  sql/01 → 04                  │
└─────────────────────────┬────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────┐
│  STEP 3 — Python Feature Pipeline                    │
│  src/feature_engineering/  ·  86 features            │
│  Imputation · Winsorisation · Bureau + Behavioural   │
└─────────────────────────┬────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────┐
│  STEP 4 — Model Training  (src/model/train.py)       │
│  Primary  : GradientBoostingClassifier (300 trees)   │
│  Challenger: Logistic Regression (IRB-interpretable) │
│  5-fold stratified CV · Optuna-ready                 │
└─────────────────────────┬────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────┐
│  STEP 5 — Validation  (src/model/evaluate.py)        │
│  KS · Gini · PSI · AUC · Lift table · ROC chart     │
└─────────────────────────┬────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────┐
│  STEP 6 — Credit Scoring  (src/model/score.py)       │
│  PD → Credit Score via log-odds PDO scaling          │
│  Bands: A1 (750+) → A2 → B1 → B2 → C → D (< 550)   │
└──────────────────┬───────────────────────────────────┘
                   │
        ┌──────────┴──────────┐
        ▼                     ▼
┌────────────────┐   ┌──────────────────────┐
│  STEP 7        │   │  STEP 8              │
│  Monitoring    │   │  REST API            │
│  PSI · KS      │   │  Flask · /score      │
│  Drift reports │   │  /batch · Docker     │
└────────┬───────┘   └──────────┬───────────┘
         └──────────┬───────────┘
                    ▼
        ┌─────────────────────────┐
        │  STEP 9 / 10            │
        │  Dashboards             │
        │  Streamlit (5 tabs)     │
        │  Power BI (10 exports   │
        │  + DAX + layout)        │
        └─────────────────────────┘
```

---

## 📁 Project Structure

```
credit-risk-engine/
├── README.md
├── requirements.txt
├── .env.example                    ← copy → .env, fill DB credentials
├── .gitignore
│
├── config/
│   ├── config.yaml                 ← paths, target definition, thresholds
│   ├── model_config.yaml           ← GBM / LR hyperparameters
│   └── scoring_cutoff.yaml         ← score bands A1 → D, LTV / FOIR limits
│
├── sql/                            ← STEP 2: PostgreSQL DDL + views
│   ├── 01_create_base_tables.sql
│   ├── 02_feature_views.sql
│   ├── 03_target_definition.sql
│   └── 04_monitoring_queries.sql
│
├── src/
│   ├── ingestion/                  ← STEP 1: load + validate 13 CSVs
│   ├── feature_engineering/        ← STEP 3: bureau, behavioural, application
│   ├── model/                      ← STEP 4–6: train, evaluate, score, utils
│   ├── monitoring/                 ← STEP 7: PSI, KS, drift, monthly pipeline
│   ├── api/                        ← STEP 8: Flask REST API + Pydantic schemas
│   └── utils/                      ← logger, helpers, DB connection
│
├── models/                         ← trained artifacts (gitignored)
│   ├── gbm_model.pkl
│   ├── logistic_model.pkl
│   ├── scaler.pkl
│   ├── feature_list.json
│   ├── metrics.json
│   └── validation_report_GBM.json
│
├── data/
│   ├── raw/                        ← 13 source CSVs (gitignored)
│   ├── processed/                  ← model_dataset.csv (gitignored)
│   └── external/                   ← 10 Power BI export CSVs
│
├── notebooks/
│   ├── eda.ipynb                   ← Exploratory data analysis
│   └── model_experiments.ipynb     ← Model comparison & tuning
│
├── dashboards/
│   ├── streamlit_app.py            ← STEP 9: 5-tab live dashboard
│   ├── powerbi_data_prep.sql       ← STEP 10: 8 Power BI SQL queries
│   └── powerbi_dax_measures.md     ← DAX measures + page layout guide
│
├── tests/
│   ├── test_features.py            ← Feature engineering unit tests
│   ├── test_model.py               ← AUC gate, PSI, KS, scoring logic
│   └── test_api.py                 ← Flask endpoint integration tests
│
└── deployment/
    ├── Dockerfile
    ├── docker-compose.yml          ← API + PostgreSQL services
    └── gunicorn_config.py          ← Production WSGI config
```

---

## 🗄️ Data Sources (13 tables)

| Table | Rows | Description |
|-------|-----:|-------------|
| `CUSTOMER_MASTER` | 400 | Demographics, KYC, occupation |
| `LOAN_MASTER_DAILY` | 500 | Product, amount, rate, status |
| `APPLICATION_FORM_DATA` | 400 | FOIR, LTV, employment, income |
| `CIBIL_RAW_PULL` | 400 | Bureau score, DPD, tradelines |
| `BUREAU_REFRESH_6M` | 1,600 | Periodic bureau refresh |
| `BANK_STATEMENT_SUMMARY` | 400 | Cash flow, bounces, salary |
| `INCOME_DOCUMENT_PARSED` | 400 | Verified vs declared income |
| `DPD_HISTORY_MONTHLY` | 10,800 | Monthly payment behaviour |
| `ACCOUNT_PORTFOLIO_MONTHLY` | 2,400 | Asset class, provision |
| `REPAYMENT_TRANSACTIONS` | 4,578 | Payment ledger |
| `SETTLEMENT_CASES` | 30 | OTS / NCLT settlements |
| `WRITE_OFF_DATA` | 40 | NPA write-offs, recovery |
| `DISBURSEMENT_DETAILS` | 700 | Disbursement log |

---

## 🚀 Quick Start

### 1. Clone & install

```bash
git clone https://github.com/YOUR_USERNAME/credit-risk-engine.git
cd credit-risk-engine
pip install -r requirements.txt
```

### 2. Configure environment

```bash
cp .env.example .env
# Edit .env with your database credentials
```

### 3. Run the full pipeline

```bash
# Feature engineering → data/processed/model_dataset.csv
python -m src.feature_engineering.create_features

# Model training → models/gbm_model.pkl + metrics.json
python -m src.model.train

# Validate model (AUC / KS / PSI gates)
python -m src.model.evaluate

# Monthly monitoring run
python -m src.monitoring.monitoring_pipeline
```

### 4. Launch the Streamlit dashboard

```bash
streamlit run dashboards/streamlit_app.py
# → http://localhost:8501
```

### 5. Start the REST API

```bash
# Development
python -m src.api.app

# Production (Gunicorn)
gunicorn "src.api.app:create_app()" \
  --config deployment/gunicorn_config.py
```

### 6. Docker (API + PostgreSQL)

```bash
cd deployment
docker-compose up --build
# API → http://localhost:8000
```

### 7. Run tests

```bash
pytest tests/ -v --tb=short --cov=src
```

---

## 🔌 API Reference

### `POST /score` — Single record

```bash
curl -X POST http://localhost:8000/score \
  -H "Content-Type: application/json" \
  -d '{"bureau_score": 720, "max_dpd_12m": 0, "foir": 0.45, "ltv_ratio": 0.75}'
```

```json
{
  "pd": 0.1235,
  "score": 712.5,
  "band": "A2",
  "risk_category": "Low Risk",
  "recommendation": "Approve — Standard Terms",
  "model_version": "2.0"
}
```

### `POST /score/batch` — Bulk scoring

```bash
curl -X POST http://localhost:8000/score/batch \
  -H "Content-Type: application/json" \
  -d '[{"bureau_score": 750}, {"bureau_score": 580}]'
```

### `GET /health` — Liveness probe

```bash
curl http://localhost:8000/health
```

### `GET /model/info` — Metadata + metrics

```bash
curl http://localhost:8000/model/info
```

---

## 🎯 Score Bands

| Band | Score Range | Risk Level | Decision | Max LTV | Max FOIR |
|------|:-----------:|:----------:|----------|:-------:|:--------:|
| **A1** | 750 – 900 | Very Low | ✅ Auto Approve | 90% | 65% |
| **A2** | 700 – 749 | Low | ✅ Approve Standard | 85% | 60% |
| **B1** | 650 – 699 | Moderate | 🔍 Enhanced Scrutiny | 80% | 55% |
| **B2** | 600 – 649 | Elevated | 🏛️ Credit Committee | 75% | 50% |
| **C** | 550 – 599 | High | ⚠️ Reject / Collateral | 65% | 45% |
| **D** | 200 – 549 | Very High | ❌ Decline | 0% | 0% |

> Scoring methodology: PDO = 20 · Base score = 800 · Base odds = 50:1

---

## 📈 Power BI Setup

1. Open **Power BI Desktop**
2. **Get Data → CSV** → import all `data/external/pbi_*.csv` files
   *— or —*
   **Get Data → PostgreSQL** → run queries in `dashboards/powerbi_data_prep.sql`
3. Copy DAX measures from `dashboards/powerbi_dax_measures.md`
4. Build the 5-page report:

| Page | Visuals |
|------|---------|
| **Executive Summary** | KPI cards · AUM trend line |
| **Credit Quality** | Vintage heatmap · Bureau distribution |
| **Collections** | Waterfall · Recovery channel breakdown |
| **Geographic Risk** | Filled map by state |
| **Model Monitoring** | PSI trend · Score band distribution |

---

## ⚙️ CI/CD

Every push to `main` runs the GitHub Actions pipeline (`.github/workflows/ci.yml`):

1. **Lint** — `flake8` code quality check
2. **Test** — `pytest` with AUC gate enforced
3. **Build** — Docker image build
4. **Artifact upload** — model artifacts stored

---

## 🛠️ Technology Stack

| Layer | Technology |
|-------|-----------|
| **Language** | Python 3.10+ |
| **ML — Primary** | `GradientBoostingClassifier` (sklearn) |
| **ML — Challenger** | `LogisticRegression` |
| **Hyperparameter Tuning** | Optuna (XGBoost / LightGBM ready) |
| **Explainability** | SHAP |
| **API** | Flask + Gunicorn |
| **Database** | PostgreSQL + SQLAlchemy |
| **Dashboard** | Streamlit |
| **BI** | Power BI Desktop |
| **Containerisation** | Docker + docker-compose |
| **CI/CD** | GitHub Actions |
| **Testing** | pytest + pytest-cov |

---

## 🤝 Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a PR.

1. Fork the repository
2. Create a feature branch: `git checkout -b feat/your-feature`
3. Commit using conventional commits: `git commit -m "feat: add XGBoost challenger"`
4. Push and open a Pull Request

---

## 📄 License

This project is licensed under the MIT License — see [LICENSE](LICENSE) for details.

---

<p align="center">
  <em>Built on real NBFC organisational data · 13 source tables · 86 engineered features</em>
</p>
