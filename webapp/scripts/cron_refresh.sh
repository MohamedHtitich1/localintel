#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# LocalIntel — Cron Metric Refresh
#
# Designed to be called by the scheduler container or host crontab.
# Triggers a metrics-only refresh via the admin API.
#
# Usage (from host):
#   docker compose exec api python scripts/pipeline.py --metrics
#
# Or via API:
#   curl -X POST http://localhost:8001/api/admin/refresh-metrics
#
# Crontab example (weekly Sunday 3am):
#   0 3 * * 0 cd /path/to/webapp && docker compose exec -T api python scripts/pipeline.py --metrics >> /var/log/localintel-cron.log 2>&1
#
# Full pipeline (monthly, 1st of month, 2am):
#   0 2 1 * * cd /path/to/webapp && docker compose exec -T api python scripts/pipeline.py --all >> /var/log/localintel-pipeline.log 2>&1
# ──────────────────────────────────────────────────────────────────────────────

set -euo pipefail

WEBAPP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$WEBAPP_DIR"

echo "[$(date -Iseconds)] LocalIntel cron refresh starting..."

# Check if containers are running
if ! docker compose ps --services --filter "status=running" | grep -q "api"; then
    echo "[$(date -Iseconds)] ERROR: API container not running. Starting stack..."
    docker compose up -d
    sleep 10
fi

# Run metrics refresh
docker compose exec -T api python scripts/pipeline.py --metrics --log /app/data/pipeline.log

echo "[$(date -Iseconds)] Cron refresh complete."
