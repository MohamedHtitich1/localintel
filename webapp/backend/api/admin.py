"""
Admin API routes — pipeline orchestration, refresh, and status.

These endpoints control the data pipeline:
- Trigger re-ingestion from updated panel data
- Recompute inequality metrics selectively (by country, indicator, or year range)
- Check pipeline status and data freshness
- Trigger dashboard regeneration
"""

import os
import time
import subprocess
import logging
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, Query, HTTPException, BackgroundTasks
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, text, delete
from typing import Optional

from backend.database import get_db, engine
from backend.models import Indicator, Observation, Region, InequalityMetric
from backend.metrics import recompute_inequality_for_country, recompute_all_inequality

logger = logging.getLogger("localintel.admin")

router = APIRouter(tags=["admin"], prefix="/admin")

# Simple in-memory state for pipeline runs
_pipeline_state = {
    "status": "idle",        # idle | running | completed | failed
    "started_at": None,
    "completed_at": None,
    "last_error": None,
    "last_result": None,
}


@router.get("/status")
async def pipeline_status(db: AsyncSession = Depends(get_db)):
    """
    Full system status: data freshness, row counts, pipeline state.
    """
    counts = {}

    for model_name, model in [
        ("regions", Region),
        ("indicators", Indicator),
        ("observations", Observation),
        ("inequality_metrics", InequalityMetric),
    ]:
        result = await db.execute(select(func.count(model.id)))
        counts[model_name] = result.scalar()

    # Year range
    year_result = await db.execute(
        select(func.min(Observation.year), func.max(Observation.year))
    )
    yr = year_result.one()

    # Country count
    country_result = await db.execute(
        select(func.count(func.distinct(Region.admin0)))
    )
    n_countries = country_result.scalar()

    # Observation breakdown by imp_flag
    flag_result = await db.execute(
        select(Observation.imp_flag, func.count(Observation.id))
        .group_by(Observation.imp_flag)
        .order_by(Observation.imp_flag)
    )
    flag_counts = {
        {0: "observed", 1: "interpolated", 2: "forecasted"}.get(r[0], f"flag_{r[0]}"): r[1]
        for r in flag_result.all()
    }

    return {
        "pipeline": _pipeline_state,
        "database": {
            "counts": counts,
            "year_range": {"min": yr[0], "max": yr[1]} if yr[0] else None,
            "n_countries": n_countries,
            "observation_types": flag_counts,
        },
        "server_time": datetime.now(timezone.utc).isoformat(),
    }


@router.post("/refresh-metrics")
async def refresh_metrics(
    background_tasks: BackgroundTasks,
    admin0: Optional[str] = None,
    indicator: Optional[str] = None,
    year_from: Optional[int] = Query(None, ge=1985, le=2030),
    year_to: Optional[int] = Query(None, ge=1985, le=2030),
    db: AsyncSession = Depends(get_db),
):
    """
    Recompute inequality metrics. Options:
    - No params: recompute ALL metrics (full refresh)
    - admin0: recompute for one country
    - indicator: recompute for one indicator
    - year_from/year_to: limit to year range

    Runs in background; check /api/admin/status for progress.
    """
    if _pipeline_state["status"] == "running":
        raise HTTPException(409, "Pipeline is already running. Check /api/admin/status")

    _pipeline_state["status"] = "running"
    _pipeline_state["started_at"] = datetime.now(timezone.utc).isoformat()
    _pipeline_state["last_error"] = None

    background_tasks.add_task(
        _run_metric_refresh,
        admin0=admin0,
        indicator_code=indicator,
        year_from=year_from,
        year_to=year_to,
    )

    return {
        "status": "started",
        "scope": {
            "admin0": admin0 or "all",
            "indicator": indicator or "all",
            "year_range": f"{year_from or 'min'}-{year_to or 'max'}",
        },
        "message": "Metric refresh started in background. Poll /api/admin/status for progress.",
    }


async def _run_metric_refresh(
    admin0: Optional[str],
    indicator_code: Optional[str],
    year_from: Optional[int],
    year_to: Optional[int],
):
    """Background task: recompute inequality metrics."""
    try:
        from backend.database import async_session
        async with async_session() as db:
            result = await recompute_all_inequality(
                db,
                admin0=admin0,
                indicator_code=indicator_code,
                year_from=year_from,
                year_to=year_to,
            )
            _pipeline_state["status"] = "completed"
            _pipeline_state["completed_at"] = datetime.now(timezone.utc).isoformat()
            _pipeline_state["last_result"] = result
    except Exception as e:
        logger.exception("Metric refresh failed")
        _pipeline_state["status"] = "failed"
        _pipeline_state["completed_at"] = datetime.now(timezone.utc).isoformat()
        _pipeline_state["last_error"] = str(e)


@router.post("/ingest")
async def trigger_ingest(
    background_tasks: BackgroundTasks,
    panel_path: str = Query("/app/data/panel.csv.gz", description="Path to panel CSV inside container"),
    drop: bool = Query(False, description="Drop and recreate all tables first"),
):
    """
    Trigger a full data ingestion from panel CSV.
    Runs the same pipeline as `python -m backend.ingest` but via API.
    """
    if _pipeline_state["status"] == "running":
        raise HTTPException(409, "Pipeline is already running")

    if not os.path.exists(panel_path):
        raise HTTPException(404, f"Panel file not found: {panel_path}")

    _pipeline_state["status"] = "running"
    _pipeline_state["started_at"] = datetime.now(timezone.utc).isoformat()
    _pipeline_state["last_error"] = None

    background_tasks.add_task(_run_ingest, panel_path=panel_path, drop=drop)

    return {
        "status": "started",
        "panel_path": panel_path,
        "drop": drop,
        "message": "Ingestion started. Poll /api/admin/status for progress.",
    }


async def _run_ingest(panel_path: str, drop: bool):
    """Background task: run the ingest pipeline as subprocess."""
    try:
        cmd = ["python", "-m", "backend.ingest", "--panel", panel_path]
        if drop:
            cmd.append("--drop")

        result = subprocess.run(
            cmd, capture_output=True, text=True, timeout=600, cwd="/app"
        )

        if result.returncode == 0:
            _pipeline_state["status"] = "completed"
            _pipeline_state["last_result"] = {
                "stdout_tail": result.stdout[-500:] if result.stdout else "",
                "return_code": 0,
            }
        else:
            _pipeline_state["status"] = "failed"
            _pipeline_state["last_error"] = result.stderr[-500:] if result.stderr else "Unknown error"

        _pipeline_state["completed_at"] = datetime.now(timezone.utc).isoformat()

    except Exception as e:
        logger.exception("Ingest failed")
        _pipeline_state["status"] = "failed"
        _pipeline_state["completed_at"] = datetime.now(timezone.utc).isoformat()
        _pipeline_state["last_error"] = str(e)


@router.post("/refresh-dashboard")
async def refresh_dashboard(background_tasks: BackgroundTasks):
    """
    Regenerate the self-contained frontend/index.html from current DB data.
    Runs generate_dashboard.py in background.
    """
    script = "/app/scripts/generate_dashboard.py"
    if not os.path.exists(script):
        # Try alternate location
        script = "/app/backend/generate_dashboard.py"
        if not os.path.exists(script):
            raise HTTPException(404, "Dashboard generator script not found")

    background_tasks.add_task(_run_dashboard_gen, script)
    return {"status": "started", "message": "Dashboard regeneration started."}


async def _run_dashboard_gen(script: str):
    """Background task: regenerate dashboard HTML."""
    try:
        result = subprocess.run(
            ["python", script], capture_output=True, text=True, timeout=300, cwd="/app"
        )
        if result.returncode != 0:
            logger.error(f"Dashboard gen failed: {result.stderr[:500]}")
    except Exception as e:
        logger.exception("Dashboard gen failed")


@router.get("/data-freshness")
async def data_freshness(db: AsyncSession = Depends(get_db)):
    """
    Per-country data freshness: latest observed survey year and total coverage.
    Useful for deciding which countries need a DHS data refresh.
    """
    result = await db.execute(text("""
        SELECT r.admin0, r.country_name,
               COUNT(DISTINCT r.id) as n_regions,
               COUNT(DISTINCT o.indicator_id) as n_indicators,
               MAX(CASE WHEN o.imp_flag = 0 THEN o.year END) as last_observed_year,
               MAX(o.year) as last_any_year,
               COUNT(CASE WHEN o.imp_flag = 0 THEN 1 END) as n_observed,
               COUNT(CASE WHEN o.imp_flag = 1 THEN 1 END) as n_interpolated,
               COUNT(CASE WHEN o.imp_flag = 2 THEN 1 END) as n_forecasted
        FROM regions r
        JOIN observations o ON o.region_id = r.id
        WHERE o.value IS NOT NULL
        GROUP BY r.admin0, r.country_name
        ORDER BY last_observed_year ASC
    """))
    rows = result.all()

    return {
        "countries": [
            {
                "admin0": r.admin0,
                "country": r.country_name,
                "n_regions": r.n_regions,
                "n_indicators": r.n_indicators,
                "last_observed_year": r.last_observed_year,
                "last_any_year": r.last_any_year,
                "observations": {
                    "observed": r.n_observed,
                    "interpolated": r.n_interpolated,
                    "forecasted": r.n_forecasted,
                },
                "freshness": "current" if r.last_observed_year and r.last_observed_year >= 2020
                    else "aging" if r.last_observed_year and r.last_observed_year >= 2015
                    else "stale",
            }
            for r in rows
        ],
    }
