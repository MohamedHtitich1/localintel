# LocalIntel — SSA Inequality Mapping Engine

Self-hosted web application for interactive subnational inequality mapping across Sub-Saharan Africa.

## Architecture

```
┌─────────┐     ┌──────────┐     ┌──────────────┐
│  Nginx  │────▶│ FastAPI   │────▶│  PostgreSQL   │
│  :80    │     │  :8000    │     │  + PostGIS    │
│ (static)│     │ (REST API)│     │  :5432        │
└─────────┘     └──────────┘     └──────────────┘
     │
     ▼
 frontend/
 index.html
```

- **Frontend**: Single-file HTML + vanilla JS with SVG choropleth, glassmorphism design
- **Backend**: FastAPI (Python) serving REST API for indicators, regions, and inequality metrics
- **Database**: PostgreSQL 16 + PostGIS 3.4 for spatial data storage
- **Orchestration**: Docker Compose

## Quick Start

### 1. Export data from R

In the `localintel` R package directory:

```r
source("webapp/scripts/export_data.R")
```

This copies the balanced panel and exports geometries to `webapp/data/`.

### 2. Start the stack

```bash
cd webapp
docker compose up -d
```

### 3. Ingest data

```bash
docker compose exec api python -m backend.ingest \
  --panel /app/data/dhs_panel_admin1_balanced.rds \
  --geo /app/data/gadm_combined_geo.rds \
  --drop
```

### 4. Open the dashboard

Navigate to http://localhost

## API Endpoints

### Indicators
- `GET /api/indicators` — List all indicators (filterable by `?domain=`)
- `GET /api/indicators/domains` — List domains with counts
- `GET /api/indicators/{code}/map?year=2020` — Choropleth data
- `GET /api/indicators/{code}/timeseries/{geo}` — Region time series
- `GET /api/indicators/{code}/years` — Available years with coverage stats

### Regions
- `GET /api/regions` — List regions (no geometry)
- `GET /api/regions/geojson?simplify=0.02` — GeoJSON FeatureCollection
- `GET /api/regions/countries` — Country list with region counts
- `GET /api/regions/{geo}/profile?year=2020` — Full indicator profile for a region

### Inequality
- `GET /api/inequality/{code}/map?year=2020&metric=gini` — Country-level inequality
- `GET /api/inequality/{code}/ranking?year=2020&metric=gini` — Country ranking
- `GET /api/inequality/{code}/trend?admin0=KE&metric=gini` — Inequality over time
- `GET /api/inequality/dashboard?year=2020` — Domain-level inequality summary

## Inequality Metrics

For each country x indicator x year, the following measures are pre-computed:

| Metric | Description |
|--------|-------------|
| Gini coefficient | 0 = perfect equality, 1 = maximum inequality |
| Coefficient of variation | Std dev / mean |
| Theil index | Generalized entropy GE(1) |
| Max/Min ratio | Highest / lowest region value |
| P90/P10 ratio | 90th / 10th percentile ratio |
| IQR | Interquartile range |

## Data Scale

- 35 countries, 652 Admin 1 regions
- 62 indicators across 8 domains
- 39 years (1985-2024)
- ~1.5M observation rows
- ~85K pre-computed inequality metrics
