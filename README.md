# League of Legends Meta Analysis Pipeline (Data Engineering Zoomcamp)

**Author:** Eyad Emam

## 📌 Project Description

This project builds an end-to-end Data Engineering ELT pipeline analyzing **League of Legends match data** to track champion win rates and meta-shifts across patches.

The goal is to answer questions like:
- Which champions dominate each lane in the current meta?
- How did a champion's win rate change after a balance patch?
- Which items correlate with winning for a specific champion?
- How do player performance metrics differ across rank tiers?

The pipeline ingests raw match data, loads it into a Google Cloud Storage Data Lake, transfers it to BigQuery, transforms it through a multi-layer dbt pipeline, and surfaces insights through an interactive Looker Studio dashboard.

*(Link to interactive dashboard: [Insert Public Looker Studio Link Here])*

---

## 🛠️ Tech Stack

| Layer | Tool |
|---|---|
| **Cloud Platform** | Google Cloud Platform (GCP) |
| **Infrastructure as Code** | Terraform |
| **Orchestration** | Kestra |
| **Data Lake** | Google Cloud Storage (GCS) |
| **Data Warehouse** | Google BigQuery |
| **Transformation** | dbt (dbt Cloud / dbt Core) |
| **Dashboard** | Google Looker Studio |
| **Containerization** | Docker / Docker Compose |
| **Development Environment** | GitHub Codespaces |

---

## 📊 Dataset

- **Source:** Riot Games API (Exported to CSV)
- **Period:** February 2024 – January 2025 (Patch 14.3 → 15.1)
- **Size:** 40,410 participant records across 4,044 unique games
- **Champions:** 169 unique champions
- **Players:** 28,098 unique players
- **Queue Focus:** Ranked Solo/Duo (Queue ID 420)
- **Structure:** One row per participant per game (10 rows per game). 94 columns covering combat stats, items, rank, vision, and champion mastery.

---

## 🏗️ Pipeline Architecture

```text
Raw CSV (GitHub) 
      │
      ▼
   Kestra (Orchestration)
      ├── 1. Download File
      ├── 2. Upload to GCS (Data Lake)
      ├── 3. Create BigQuery External Table
      └── 4. Create BigQuery Native Table (Raw Layer)
      │
      ▼
dbt Transformations
      ├── Staging        → Clean & type-cast raw data
      ├── Intermediate   → Business logic & enrichment
      └── Marts          → Analytics-ready tables (Partitioned & Clustered)
      │
      ▼
Looker Studio Dashboard
