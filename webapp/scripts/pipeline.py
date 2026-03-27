#!/usr/bin/env python3
"""
LocalIntel — Full Pipeline Orchestrator

Automates the end-to-end data refresh cycle:
  1. (Optional) Run R script to fetch fresh DHS data and export panel CSV
  2. Ingest panel data into PostgreSQL
  3. Recompute all inequality metrics
  4. Regenerate the self-contained dashboard HTML
  5. Report results

Usage inside Docker:
    # Full pipeline (skip R step — assumes panel.csv.gz is already updated)
    python scripts/pipeline.py --ingest --metrics --dashboard

    # Metrics-only refresh (e.g., after algorithm change)
    python scripts/pipeline.py --metrics

    # Full pipeline with R data fetch (requires R + packages on host)
    python scripts/pipeline.py --r-fetch --ingest --metrics --dashboard

    # Selective metric refresh for one country
    python scripts/pipeline.py --metrics --admin0 KE

    # Scheduled mode (runs everything, logs to file)
    python scripts/pipeline.py --all --log /app/data/pipeline.log

Can also be triggered via the admin API:
    POST /api/admin/ingest
    POST /api/admin/refresh-metrics
    POST /api/admin/refresh-dashboard
"""

import argparse
import json
import logging
import os
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

# Ensure /app is on the Python path so `backend.*` imports resolve
# when this script is invoked as `python scripts/pipeline.py` from /app
APP_DIR = Path(__file__).resolve().parent.parent
if str(APP_DIR) not in sys.path:
    sys.path.insert(0, str(APP_DIR))

# ── Logging ──────────────────────────────────────────────────────────────────

def setup_logging(log_file=None):
    handlers = [logging.StreamHandler(sys.stdout)]
    if log_file:
        handlers.append(logging.FileHandler(log_file, mode="a"))

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
        handlers=handlers,
    )
    return logging.getLogger("pipeline")


# ── Step 1: R Data Fetch ─────────────────────────────────────────────────────

def run_r_fetch(logger, r_script_path="/app/scripts/r_pipeline.R"):
    """
    Execute the R pipeline script that:
    - Fetches latest DHS data via API
    - Runs gap-filling and forecasting
    - Exports panel.csv.gz to /app/data/
    """
    logger.info("=" * 60)
    logger.info("STEP 1: R Data Fetch & Export")
    logger.info("=" * 60)

    if not os.path.exists(r_script_path):
        logger.warning(f"R script not found at {r_script_path}")
        logger.info("Skipping R fetch — using existing panel data")
        return False

    try:
        result = subprocess.run(
            ["Rscript", r_script_path],
            capture_output=True, text=True, timeout=1800,  # 30 min
            cwd="/app",
        )

        if result.returncode == 0:
            logger.info("R data fetch completed successfully")
            if result.stdout:
                # Log last 20 lines of R output
                for line in result.stdout.strip().split("\n")[-20:]:
                    logger.info(f"  R: {line}")
            return True
        else:
            logger.error(f"R script failed (exit {result.returncode})")
            if result.stderr:
                for line in result.stderr.strip().split("\n")[-10:]:
                    logger.error(f"  R: {line}")
            return False

    except subprocess.TimeoutExpired:
        logger.error("R script timed out after 30 minutes")
        return False
    except FileNotFoundError:
        logger.error("Rscript not found — is R installed?")
        return False


# ── Step 2: Ingest ───────────────────────────────────────────────────────────

def run_ingest(logger, panel_path="/app/data/panel.csv.gz", drop=True):
    """Run the Python ingestion pipeline."""
    logger.info("=" * 60)
    logger.info("STEP 2: Data Ingestion")
    logger.info("=" * 60)

    if not os.path.exists(panel_path):
        logger.error(f"Panel file not found: {panel_path}")
        return False

    file_size = os.path.getsize(panel_path) / (1024 * 1024)
    logger.info(f"Panel file: {panel_path} ({file_size:.1f} MB)")

    cmd = [sys.executable, "-m", "backend.ingest", "--panel", panel_path]
    if drop:
        cmd.append("--drop")

    try:
        t0 = time.time()
        result = subprocess.run(
            cmd, capture_output=True, text=True, timeout=600,
            cwd="/app",
        )

        elapsed = time.time() - t0

        if result.returncode == 0:
            logger.info(f"Ingestion completed in {elapsed:.0f}s")
            # Log summary lines
            for line in result.stdout.strip().split("\n"):
                if any(kw in line.lower() for kw in ["inserted", "computed", "complete", "regions", "indicators"]):
                    logger.info(f"  {line.strip()}")
            return True
        else:
            logger.error(f"Ingestion failed (exit {result.returncode})")
            if result.stderr:
                logger.error(result.stderr[-500:])
            return False

    except subprocess.TimeoutExpired:
        logger.error("Ingestion timed out after 10 minutes")
        return False


# ── Step 3: Recompute Metrics ────────────────────────────────────────────────

def run_metrics_refresh(logger, admin0=None, indicator=None):
    """
    Recompute inequality metrics using the metrics module directly.
    More efficient than the admin API for batch operations.
    """
    logger.info("=" * 60)
    logger.info("STEP 3: Inequality Metrics Refresh")
    logger.info("=" * 60)

    scope = []
    if admin0:
        scope.append(f"country={admin0}")
    if indicator:
        scope.append(f"indicator={indicator}")
    logger.info(f"Scope: {', '.join(scope) if scope else 'FULL (all countries × all indicators)'}")

    try:
        import asyncio
        from backend.database import async_session
        from backend.metrics import recompute_all_inequality

        async def _run():
            async with async_session() as db:
                return await recompute_all_inequality(
                    db, admin0=admin0, indicator_code=indicator,
                )

        t0 = time.time()
        result = asyncio.run(_run())
        elapsed = time.time() - t0

        logger.info(f"Metrics refresh completed in {elapsed:.0f}s")
        logger.info(f"  Total metrics: {result['total_metrics']:,}")
        logger.info(f"  Indicators: {result['n_indicators']}")
        logger.info(f"  Countries: {result['n_countries']}")
        logger.info(f"  Years: {result['n_years']}")
        return True

    except Exception as e:
        logger.exception(f"Metrics refresh failed: {e}")
        return False


# ── Step 4: Dashboard Regeneration ───────────────────────────────────────────

def run_dashboard_gen(logger, script_path="/app/scripts/generate_dashboard.py"):
    """Regenerate the self-contained HTML dashboard."""
    logger.info("=" * 60)
    logger.info("STEP 4: Dashboard Regeneration")
    logger.info("=" * 60)

    if not os.path.exists(script_path):
        # Try alternate location
        alt = "/app/backend/generate_dashboard.py"
        if os.path.exists(alt):
            script_path = alt
        else:
            logger.warning("Dashboard generator not found — skipping")
            return False

    try:
        t0 = time.time()
        result = subprocess.run(
            [sys.executable, script_path],
            capture_output=True, text=True, timeout=300,
            cwd="/app",
        )
        elapsed = time.time() - t0

        if result.returncode == 0:
            logger.info(f"Dashboard generated in {elapsed:.0f}s")
            # Check output file
            html_path = "/app/frontend/index.html"
            if os.path.exists(html_path):
                size = os.path.getsize(html_path) / (1024 * 1024)
                logger.info(f"  Output: {html_path} ({size:.1f} MB)")
            return True
        else:
            logger.error(f"Dashboard generation failed (exit {result.returncode})")
            if result.stderr:
                logger.error(result.stderr[-300:])
            return False

    except subprocess.TimeoutExpired:
        logger.error("Dashboard generation timed out")
        return False


# ── Main ─────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="LocalIntel Pipeline Orchestrator",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python scripts/pipeline.py --all                         # Full pipeline
  python scripts/pipeline.py --metrics                     # Metrics only
  python scripts/pipeline.py --metrics --admin0 KE         # Metrics for Kenya
  python scripts/pipeline.py --ingest --metrics            # Re-ingest + metrics
  python scripts/pipeline.py --all --log pipeline.log      # With log file
        """,
    )

    parser.add_argument("--all", action="store_true", help="Run full pipeline (ingest + metrics + dashboard)")
    parser.add_argument("--r-fetch", action="store_true", help="Step 1: Run R data fetch script")
    parser.add_argument("--ingest", action="store_true", help="Step 2: Ingest panel data into PostgreSQL")
    parser.add_argument("--metrics", action="store_true", help="Step 3: Recompute inequality metrics")
    parser.add_argument("--dashboard", action="store_true", help="Step 4: Regenerate dashboard HTML")

    parser.add_argument("--admin0", type=str, help="Filter metrics refresh to one country (e.g., KE)")
    parser.add_argument("--indicator", type=str, help="Filter metrics refresh to one indicator (e.g., u5_mortality)")
    parser.add_argument("--panel", type=str, default="/app/data/panel.csv.gz", help="Path to panel data")
    parser.add_argument("--no-drop", action="store_true", help="Don't drop tables before ingest (append mode)")
    parser.add_argument("--log", type=str, help="Log file path")

    args = parser.parse_args()

    if args.all:
        args.ingest = True
        args.metrics = True
        args.dashboard = True

    if not any([args.r_fetch, args.ingest, args.metrics, args.dashboard]):
        parser.print_help()
        sys.exit(1)

    logger = setup_logging(args.log)
    logger.info("╔══════════════════════════════════════╗")
    logger.info("║  LocalIntel Pipeline Orchestrator     ║")
    logger.info("╚══════════════════════════════════════╝")
    logger.info(f"Started: {datetime.now(timezone.utc).isoformat()}")

    results = {}
    overall_t0 = time.time()

    # Step 1
    if args.r_fetch:
        results["r_fetch"] = run_r_fetch(logger)
        if not results["r_fetch"]:
            logger.warning("R fetch failed — continuing with existing data")

    # Step 2
    if args.ingest:
        results["ingest"] = run_ingest(
            logger, panel_path=args.panel, drop=not args.no_drop
        )
        if not results["ingest"]:
            logger.error("Ingestion failed — aborting pipeline")
            sys.exit(1)

    # Step 3
    if args.metrics:
        results["metrics"] = run_metrics_refresh(
            logger, admin0=args.admin0, indicator=args.indicator
        )

    # Step 4
    if args.dashboard:
        results["dashboard"] = run_dashboard_gen(logger)

    # Summary
    elapsed = time.time() - overall_t0
    logger.info("")
    logger.info("═" * 50)
    logger.info("PIPELINE SUMMARY")
    logger.info("═" * 50)
    for step, success in results.items():
        status = "✓" if success else "✗"
        logger.info(f"  {status} {step}")
    logger.info(f"  Total time: {elapsed:.0f}s")
    logger.info(f"  Completed: {datetime.now(timezone.utc).isoformat()}")

    # Write result to JSON for the cron service to read
    result_path = "/app/data/pipeline_last_run.json"
    try:
        with open(result_path, "w") as f:
            json.dump({
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "elapsed_seconds": round(elapsed, 1),
                "steps": {k: v for k, v in results.items()},
                "success": all(results.values()),
            }, f, indent=2)
    except Exception:
        pass

    if not all(results.values()):
        sys.exit(1)


if __name__ == "__main__":
    main()
