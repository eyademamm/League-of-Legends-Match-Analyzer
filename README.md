# League of Legends Meta Analysis Pipeline (Data Engineering Zoomcamp)

**Author:** Eyad Emam

---

## Problem Description

This project builds an end-to-end Data Engineering ELT pipeline analyzing **League of Legends match data** to track champion win rates and meta-shifts across patches.

The goal is to answer questions like:
- Which champions dominate each lane in the current meta?
- How did a champion's win rate change after a balance patch?
- Which items correlate with winning for a specific champion?
- How do player performance metrics differ across rank tiers?

The pipeline ingests raw match data, loads it into a Google Cloud Storage Data Lake, transfers it to BigQuery, transforms it through a multi-layer dbt pipeline, and surfaces insights through an interactive Looker Studio dashboard.

> **Dashboard:** [(https://lookerstudio.google.com/s/hVu31zLivdo)]

---

## Tech Stack

| Layer | Tool |
|---|---|
| **Cloud Platform** | Google Cloud Platform (GCP) |
| **Infrastructure as Code** | Terraform |
| **Orchestration** | Kestra |
| **Data Lake** | Google Cloud Storage (GCS) |
| **Data Warehouse** | Google BigQuery |
| **Transformation** | dbt (dbt-fusion 2.0) |
| **Dashboard** | Google Looker Studio |
| **Containerization** | Docker / Docker Compose |
| **Development Environment** | GitHub Codespaces |

---

## Dataset

- **Source:** Riot Games API (Exported to CSV)
- **Period:** February 2024 – January 2025 (Patch 14.3 → 15.1)
- **Size:** 40,410 participant records across 4,044 unique games
- **Champions:** 169 unique champions
- **Players:** 28,098 unique players
- **Queue Focus:** Ranked Solo/Duo (Queue ID 420)
- **Structure:** One row per participant per game (10 rows per game). 94 columns covering combat stats, items, rank, vision, and champion mastery.

---

## Pipeline Architecture

```
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
```

---

## Orchestration (Kestra)

Kestra is used as the workflow orchestrator, running inside Docker via Docker Compose alongside its own dedicated Postgres backend. The pipeline is triggered through the Kestra UI accessible at port 8080.

The flow (`league_data_pipeline.yaml`) handles the **Extract and Load (EL)** phase:

1. **Extract** — Downloads the raw CSV dataset via an HTTP Download task
2. **Load to Data Lake** — Uploads the raw data into a Google Cloud Storage bucket using GCP credentials stored in Kestra's secure `.env` file
3. **Load to Data Warehouse** — Executes BigQuery SQL to create an `EXTERNAL TABLE` pointing to the GCS bucket, then creates the final native raw BigQuery table from that external source
4. **Cleanup** — Purges local Kestra runner memory

---

## Data Warehouse (BigQuery)

### Raw Table Optimization

The raw `matches` table was recreated in BigQuery with specific optimizations:

- **Partitioned by** `DATE(game_start_utc)` — Queries filtering by patch periods scan only relevant day partitions instead of the full 40,410-row table, reducing both query time and cost
- **Clustered by** `champion_name`, `queue_id`, `team_position` — The three most common filter columns in the transformation layer, allowing BigQuery to skip irrelevant data blocks on disk

### Mart Table Optimization (dbt config)

All final production tables are materialized as clustered tables using dbt `{{ config() }}` blocks:

| Table | Clustered By | Reasoning |
|---|---|---|
| `mart_champion_win_rates` | `champion_name`, `position`, `patch` | Dashboard always filters by these three together |
| `mart_meta_shifts` | `champion_name`, `position`, `patch` | Same query pattern as win rates |
| `mart_player_profiles` | `solo_tier`, `most_played_position`, `most_played_champion` | Player lookup queries filter by rank tier and role |
| `mart_item_win_rates` | `champion_name`, `position`, `patch` | Item analysis always scoped to a specific champion and role |

---

## Transformations (dbt)

All transformations are defined using **dbt-fusion 2.0** connected to BigQuery, following the classic **Staging → Intermediate → Marts** pattern where each layer has a single responsibility.

### Staging — `stg_lol__matches`

A 1:1 mapping of the raw `matches` table with no business logic — purely cleaning and standardizing:

- **Type casting** — `game_start_utc` cast to `TIMESTAMP`, `win` cast to `BOOL` using `SAFE_CAST` to avoid errors on nulls
- **Patch normalization** — Raw version string (e.g. `15.1.649.4112`) parsed using BigQuery's `SPLIT()[OFFSET()]` syntax to extract only the major.minor patch (e.g. `15.1`), enabling correct patch ordering in downstream models
- **Null handling** — `NULLIF` applied to `summoner_name` and `team_position` to convert empty strings to proper nulls
- **Column renaming** — `win` renamed to `is_winner`, `item6` aliased as `trinket_item` to distinguish it from core items

### Intermediate Layer

| Model | Description |
|---|---|
| `int_matches__with_kda` | Adds KDA, Gold Per Minute (GPM), and Damage Per Minute (DPM) using `SAFE_DIVIDE()` to handle zero-death games without errors. Also adds a categorical KDA tier label |
| `int_matches__team_context` | Joins each participant with their team's aggregated totals to compute Kill Participation %, Damage Share %, and Gold Share % |
| `int_matches__ranked_only` | Filters to Ranked Solo (queue 420) with non-null positions only |
| `int_champions__patch_stats` | Aggregates all participant metrics to champion level grouped by patch, position, and queue — foundation for all mart models |

### Marts Layer

| Model | Description |
|---|---|
| `mart_champion_win_rates` | Champion win rates with win rate rank and popularity rank per patch and position. Filtered to Ranked Solo with minimum 10 games sample threshold to avoid statistical noise |
| `mart_meta_shifts` | Patch-over-patch win rate delta and pick rate changes using BigQuery `LAG()` window functions. Classifies champions as `Buffed / Rising`, `Nerfed / Falling`, or `Stable` |
| `mart_player_profiles` | Per-player aggregated stats using `puuid` as the stable player key. Uses `APPROX_TOP_COUNT()` as BigQuery's equivalent of `MODE()` for most played champion and position |
| `mart_item_win_rates` | Unpivots 6 item columns using BigQuery's `UNNEST([col1, col2, ...])` lateral join to compute win rates per item per champion per patch |

### Key BigQuery-Specific Implementations

- `SAFE_DIVIDE()` used throughout instead of `/ NULLIF()` for division safety
- `SPLIT(col, '.')[OFFSET(n)]` for patch version string parsing
- `UNNEST([col1, col2, ...])` lateral join for item column unpivoting
- `APPROX_TOP_COUNT()` as BigQuery's equivalent of `MODE()`
- `IF(condition, true, false)` instead of `CASE WHEN` for simple boolean aggregations
- `ORDER BY` removed from `mart_item_win_rates` as BigQuery does not allow ordering on clustered tables

### Data Quality Tests

A custom generic test `is_between` was written in `tests/generic/is_between.sql` to replace `dbt_utils.accepted_range` which is incompatible with dbt-fusion 2.0:

| Test | Applied To |
|---|---|
| `not_null` | All ID and metric columns across all layers |
| `unique` | `puuid` in `mart_player_profiles` |
| `accepted_values` | `position`, `kda_tier`, `meta_shift_label` |
| `is_between` | All `win_rate_pct` columns (validated between 0 and 100) |

Tests on `position` and `most_played_position` are set to `severity: warn` because a small number of rows legitimately have null positions (remakes and bot games).

---

## Dashboard (Looker Studio)

<img width="1200" height="730" alt="Screenshot 2026-03-30 062738" src="https://github.com/user-attachments/assets/fa746cf9-438e-4c90-af33-325f0f7e3deb" />


The dashboard is built in **Looker Studio** connected directly to BigQuery's `mart_champion_win_rates` table. It features an interactive `champion_name` dropdown that dynamically filters both visual tiles simultaneously:

**Tile 1 — Win Rate by Position (Bar Chart)**
A categorical distribution showing the average win rate per lane (UTILITY, TOP, JUNGLE, BOTTOM, MIDDLE) across all champions in Ranked Solo. Demonstrates that win rates are tightly balanced between 48–51% across all positions, reflecting Riot Games' balancing philosophy.

**Tile 2 — Champion Win Rate Trend Across Patches (Line Chart)**
A temporal chart tracking how individual champion win rates evolve chronologically across patches. Use the champion name filter to track any of the 169 champions in the dataset across patches.

---

## Project Structure

```
├── .devcontainer/
│   └── devcontainer.json        # Codespaces port forwarding config
├── docker-compose.yml           # Kestra + Postgres + pgAdmin services
├── terraform/
│   └── main.tf                  # GCS bucket + BigQuery dataset provisioning
├── models/
│   ├── staging/
│   │   ├── stg_lol__matches.sql
│   │   └── schema.yml
│   ├── intermediate/
│   │   ├── int_matches__with_kda.sql
│   │   ├── int_matches__team_context.sql
│   │   ├── int_matches__ranked_only.sql
│   │   ├── int_champions__patch_stats.sql
│   │   └── schema.yml
│   └── marts/
│       ├── mart_champion_win_rates.sql
│       ├── mart_meta_shifts.sql
│       ├── mart_player_profiles.sql
│       ├── mart_item_win_rates.sql
│       └── schema.yml
└── tests/
    └── generic/
        └── is_between.sql       # Custom range test (dbt-fusion compatible)
```

---

## How to Reproduce

### Prerequisites

- A Google Cloud Platform (GCP) account
- Google Cloud SDK and Terraform installed
- Docker and Docker Compose installed (or GitHub Codespaces)
- dbt-fusion installed

### 1. Set up GCP with Terraform

Create a GCP Project and a Service Account with `Viewer`, `BigQuery Admin`, and `Storage Admin` roles. Download the Service Account JSON key. Then:

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

This provisions the GCS bucket and BigQuery dataset.

### 2. Start Orchestration (Kestra)

Store your GCP JSON credentials in a `.env` file, then start the stack:

```bash
docker compose up -d
```

Open Kestra UI at `http://localhost:8080`, import the flow YAML, and click **Execute** to run the full EL pipeline and load data into BigQuery.

> If using GitHub Codespaces, port 8080 is automatically forwarded and set to public visibility via `.devcontainer/devcontainer.json`.

> **Note:** If it didn't work, change the port visibility to public.

### 3. Run dbt Transformations

```bash
# Install dependencies
dbt deps

# Run all models
dbt run

# Run tests
dbt test

# Or build everything at once (run + test)
dbt build
```

### 4. Run a specific layer only

```bash
dbt run --select staging
dbt run --select intermediate
dbt run --select marts
```

### 5. View dbt documentation

```bash
dbt docs generate
dbt docs serve
```
