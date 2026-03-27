"""
API routes for indicator data — the core data layer.
Serves choropleth values, time series, and metadata.
"""

from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, text
from typing import Optional

from backend.database import get_db
from backend.models import Indicator, Observation, Region

router = APIRouter(tags=["indicators"])


@router.get("/indicators")
async def list_indicators(
    domain: Optional[str] = None,
    db: AsyncSession = Depends(get_db),
):
    """List all indicators, optionally filtered by domain."""
    q = select(Indicator).order_by(Indicator.domain, Indicator.code)
    if domain:
        q = q.where(Indicator.domain == domain)
    result = await db.execute(q)
    indicators = result.scalars().all()
    return [
        {
            "code": ind.code,
            "label": ind.label,
            "domain": ind.domain,
            "unit": ind.unit,
            "transform": ind.transform,
            "higher_is": ind.higher_is,
            "coverage_regions": ind.coverage_regions,
            "coverage_countries": ind.coverage_countries,
        }
        for ind in indicators
    ]


@router.get("/indicators/domains")
async def list_domains(db: AsyncSession = Depends(get_db)):
    """List all domains with indicator counts."""
    result = await db.execute(
        select(Indicator.domain, func.count(Indicator.id))
        .group_by(Indicator.domain)
        .order_by(Indicator.domain)
    )
    return [{"domain": row[0], "count": row[1]} for row in result.all()]


@router.get("/indicators/{code}/map")
async def get_map_data(
    code: str,
    year: int = Query(..., ge=1985, le=2024),
    db: AsyncSession = Depends(get_db),
):
    """
    Get choropleth data for a single indicator + year.
    Returns {geo: value, ci_lo, ci_hi, imp_flag} for all regions.
    """
    ind = await db.execute(select(Indicator).where(Indicator.code == code))
    indicator = ind.scalar_one_or_none()
    if not indicator:
        raise HTTPException(404, f"Indicator '{code}' not found")

    result = await db.execute(
        select(
            Region.geo,
            Region.name,
            Region.admin0,
            Region.country_name,
            Observation.value,
            Observation.ci_lo,
            Observation.ci_hi,
            Observation.imp_flag,
        )
        .join(Region, Observation.region_id == Region.id)
        .where(Observation.indicator_id == indicator.id, Observation.year == year)
        .where(Observation.value.isnot(None))
    )
    rows = result.all()

    values = [r.value for r in rows if r.value is not None]
    vmin = min(values) if values else 0
    vmax = max(values) if values else 1

    return {
        "indicator": code,
        "label": indicator.label,
        "unit": indicator.unit,
        "higher_is": indicator.higher_is,
        "year": year,
        "range": {"min": round(vmin, 3), "max": round(vmax, 3)},
        "n_regions": len(rows),
        "regions": {
            r.geo: {
                "v": round(r.value, 3) if r.value is not None else None,
                "lo": round(r.ci_lo, 3) if r.ci_lo is not None else None,
                "hi": round(r.ci_hi, 3) if r.ci_hi is not None else None,
                "flag": r.imp_flag,
                "name": r.name,
                "admin0": r.admin0,
                "country": r.country_name,
            }
            for r in rows
        },
    }


@router.get("/indicators/{code}/timeseries/{geo}")
async def get_timeseries(
    code: str,
    geo: str,
    db: AsyncSession = Depends(get_db),
):
    """Get full time series for a specific region + indicator."""
    ind = await db.execute(select(Indicator).where(Indicator.code == code))
    indicator = ind.scalar_one_or_none()
    if not indicator:
        raise HTTPException(404, f"Indicator '{code}' not found")

    rgn = await db.execute(select(Region).where(Region.geo == geo))
    region = rgn.scalar_one_or_none()
    if not region:
        raise HTTPException(404, f"Region '{geo}' not found")

    result = await db.execute(
        select(Observation)
        .where(Observation.region_id == region.id, Observation.indicator_id == indicator.id)
        .order_by(Observation.year)
    )
    obs = result.scalars().all()

    return {
        "indicator": code,
        "label": indicator.label,
        "geo": geo,
        "region_name": region.name,
        "country": region.country_name,
        "series": [
            {
                "year": o.year,
                "value": round(o.value, 3) if o.value is not None else None,
                "ci_lo": round(o.ci_lo, 3) if o.ci_lo is not None else None,
                "ci_hi": round(o.ci_hi, 3) if o.ci_hi is not None else None,
                "flag": o.imp_flag,
            }
            for o in obs
        ],
    }


@router.get("/indicators/{code}/years")
async def get_available_years(
    code: str,
    db: AsyncSession = Depends(get_db),
):
    """Get available years for an indicator with coverage stats per year."""
    ind = await db.execute(select(Indicator).where(Indicator.code == code))
    indicator = ind.scalar_one_or_none()
    if not indicator:
        raise HTTPException(404, f"Indicator '{code}' not found")

    result = await db.execute(
        select(
            Observation.year,
            func.count(Observation.id).label("n_regions"),
            func.avg(Observation.value).label("mean_value"),
        )
        .where(Observation.indicator_id == indicator.id, Observation.value.isnot(None))
        .group_by(Observation.year)
        .order_by(Observation.year)
    )
    rows = result.all()
    return {
        "indicator": code,
        "years": [
            {"year": r.year, "n_regions": r.n_regions, "mean": round(r.mean_value, 3)}
            for r in rows
        ],
    }
