"""
API routes for structured insight reports and data exports.

Produces:
- JSON summary reports per country or indicator
- CSV data exports for downstream analysis
- Report metadata for scheduling and automation
"""

import csv
import io
import json
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, Query, HTTPException
from fastapi.responses import StreamingResponse, JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, text
from typing import Optional

from backend.database import get_db
from backend.models import Indicator, Observation, Region, InequalityMetric

router = APIRouter(tags=["reports"])


# ── Country Report ───────────────────────────────────────────────────────────

@router.get("/reports/country/{admin0}")
async def country_report(
    admin0: str,
    year: int = Query(2024, ge=1985, le=2030),
    db: AsyncSession = Depends(get_db),
):
    """
    Comprehensive structured report for one country.
    Designed for automated report pipelines and dashboard consumption.

    Returns:
    - Country metadata
    - Domain-level inequality summary
    - Indicator-level detail with trends
    - Regional rankings
    - Convergence/divergence signals
    """
    # Country info
    region_result = await db.execute(
        select(Region.country_name, func.count(Region.id).label("n"))
        .where(Region.admin0 == admin0)
        .group_by(Region.country_name)
    )
    country_row = region_result.one_or_none()
    if not country_row:
        raise HTTPException(404, f"Country '{admin0}' not found")

    country_name = country_row[0]
    n_regions = country_row[1]

    # All inequality metrics for this country/year
    metrics_result = await db.execute(
        text("""
            SELECT i.code, i.label, i.domain, i.unit, i.higher_is,
                   im.gini, im.cv, im.theil, im.ratio_p90_p10, im.ratio_max_min,
                   im.mean_value, im.median_value, im.std_dev, im.iqr, im.range_abs,
                   im.n_regions, im.best_region, im.worst_region
            FROM inequality_metrics im
            JOIN indicators i ON im.indicator_id = i.id
            WHERE im.admin0 = :admin0 AND im.year = :year
            ORDER BY i.domain, im.gini DESC
        """),
        {"admin0": admin0, "year": year},
    )
    metrics = metrics_result.all()

    # Build domain sections
    domains = {}
    for m in metrics:
        if m.domain not in domains:
            domains[m.domain] = {"indicators": [], "ginis": []}
        if m.gini is not None:
            domains[m.domain]["ginis"].append(m.gini)
        domains[m.domain]["indicators"].append({
            "code": m.code,
            "label": m.label,
            "unit": m.unit,
            "higher_is": m.higher_is,
            "gini": round(m.gini, 4) if m.gini else None,
            "cv": round(m.cv, 4) if m.cv else None,
            "theil": round(m.theil, 4) if m.theil else None,
            "p90_p10": round(m.ratio_p90_p10, 2) if m.ratio_p90_p10 else None,
            "max_min": round(m.ratio_max_min, 2) if m.ratio_max_min else None,
            "mean": round(m.mean_value, 2) if m.mean_value else None,
            "median": round(m.median_value, 2) if m.median_value else None,
            "std": round(m.std_dev, 2) if m.std_dev else None,
            "iqr": round(m.iqr, 2) if m.iqr else None,
            "range": round(m.range_abs, 2) if m.range_abs else None,
            "n_regions": m.n_regions,
            "best_region": m.best_region,
            "worst_region": m.worst_region,
        })

    domain_summary = []
    for domain, data in sorted(domains.items()):
        ginis = data["ginis"]
        domain_summary.append({
            "domain": domain,
            "n_indicators": len(data["indicators"]),
            "avg_gini": round(sum(ginis) / len(ginis), 4) if ginis else None,
            "max_gini": round(max(ginis), 4) if ginis else None,
            "indicators": data["indicators"],
        })

    # Trend data — Gini trajectory per indicator
    trends = []
    for m in metrics:
        if m.gini is None:
            continue
        trend_result = await db.execute(
            text("""
                SELECT im.year, im.gini, im.mean_value
                FROM inequality_metrics im
                JOIN indicators i ON im.indicator_id = i.id
                WHERE im.admin0 = :admin0 AND i.code = :code AND im.gini IS NOT NULL
                ORDER BY im.year
            """),
            {"admin0": admin0, "code": m.code},
        )
        t_rows = trend_result.all()
        if len(t_rows) >= 2:
            first_g = t_rows[0].gini
            last_g = t_rows[-1].gini
            pct = ((last_g - first_g) / abs(first_g)) * 100 if first_g != 0 else 0
            trends.append({
                "indicator": m.code,
                "label": m.label,
                "from_year": t_rows[0].year,
                "to_year": t_rows[-1].year,
                "gini_change_pct": round(pct, 1),
                "trajectory": "widening" if pct > 5 else "narrowing" if pct < -5 else "stable",
                "series": [
                    {"year": t.year, "gini": round(t.gini, 4), "mean": round(t.mean_value, 2) if t.mean_value else None}
                    for t in t_rows
                ],
            })

    trends.sort(key=lambda x: abs(x["gini_change_pct"]), reverse=True)

    return {
        "report_type": "country",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "admin0": admin0,
        "country": country_name,
        "year": year,
        "n_regions": n_regions,
        "n_indicators": len(metrics),
        "overall_avg_gini": round(
            sum(m.gini for m in metrics if m.gini) / max(1, sum(1 for m in metrics if m.gini)), 4
        ),
        "domain_summary": domain_summary,
        "gini_trends": trends[:20],
    }


# ── Indicator Report ─────────────────────────────────────────────────────────

@router.get("/reports/indicator/{code}")
async def indicator_report(
    code: str,
    year: int = Query(2024, ge=1985, le=2030),
    db: AsyncSession = Depends(get_db),
):
    """
    Cross-country report for one indicator.
    Full inequality comparison with rankings, trends, and convergence signals.
    """
    ind = await db.execute(select(Indicator).where(Indicator.code == code))
    indicator = ind.scalar_one_or_none()
    if not indicator:
        raise HTTPException(404, f"Indicator '{code}' not found")

    # All country metrics
    result = await db.execute(
        text("""
            SELECT im.admin0,
                   im.gini, im.cv, im.theil, im.ratio_p90_p10, im.ratio_max_min,
                   im.mean_value, im.median_value, im.std_dev, im.iqr, im.range_abs,
                   im.n_regions, im.best_region, im.worst_region,
                   r_best.name as best_name, r_worst.name as worst_name
            FROM inequality_metrics im
            LEFT JOIN regions r_best ON r_best.geo = im.best_region
            LEFT JOIN regions r_worst ON r_worst.geo = im.worst_region
            WHERE im.indicator_id = :ind_id AND im.year = :year AND im.gini IS NOT NULL
            ORDER BY im.gini DESC
        """),
        {"ind_id": indicator.id, "year": year},
    )
    rows = result.all()

    if not rows:
        raise HTTPException(404, f"No data for {code} in {year}")

    ginis = [r.gini for r in rows]

    countries = [
        {
            "rank": i + 1,
            "admin0": r.admin0,
            "gini": round(r.gini, 4),
            "cv": round(r.cv, 4) if r.cv else None,
            "theil": round(r.theil, 4) if r.theil else None,
            "p90_p10": round(r.ratio_p90_p10, 2) if r.ratio_p90_p10 else None,
            "max_min": round(r.ratio_max_min, 2) if r.ratio_max_min else None,
            "mean": round(r.mean_value, 2) if r.mean_value else None,
            "median": round(r.median_value, 2) if r.median_value else None,
            "iqr": round(r.iqr, 2) if r.iqr else None,
            "range": round(r.range_abs, 2) if r.range_abs else None,
            "n_regions": r.n_regions,
            "best_region": r.best_name,
            "worst_region": r.worst_name,
        }
        for i, r in enumerate(rows)
    ]

    return {
        "report_type": "indicator",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "indicator": code,
        "label": indicator.label,
        "domain": indicator.domain,
        "unit": indicator.unit,
        "higher_is": indicator.higher_is,
        "year": year,
        "n_countries": len(rows),
        "continent_avg_gini": round(sum(ginis) / len(ginis), 4),
        "continent_max_gini": round(max(ginis), 4),
        "continent_min_gini": round(min(ginis), 4),
        "countries": countries,
    }


# ── CSV Export ───────────────────────────────────────────────────────────────

@router.get("/reports/export/inequality.csv")
async def export_inequality_csv(
    year: Optional[int] = None,
    admin0: Optional[str] = None,
    db: AsyncSession = Depends(get_db),
):
    """
    Export inequality metrics as CSV for downstream analysis.
    Filterable by year and/or country.
    """
    conditions = ["im.gini IS NOT NULL"]
    params = {}

    if year:
        conditions.append("im.year = :year")
        params["year"] = year
    if admin0:
        conditions.append("im.admin0 = :admin0")
        params["admin0"] = admin0

    where_clause = " AND ".join(conditions)

    result = await db.execute(
        text(f"""
            SELECT im.admin0, i.code, i.label, i.domain, im.year,
                   im.gini, im.cv, im.theil, im.ratio_p90_p10, im.ratio_max_min,
                   im.mean_value, im.median_value, im.std_dev, im.iqr, im.range_abs,
                   im.n_regions, im.best_region, im.worst_region
            FROM inequality_metrics im
            JOIN indicators i ON im.indicator_id = i.id
            WHERE {where_clause}
            ORDER BY im.admin0, i.domain, i.code, im.year
        """),
        params,
    )
    rows = result.all()

    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow([
        "admin0", "indicator", "label", "domain", "year",
        "gini", "cv", "theil", "p90_p10", "max_min",
        "mean", "median", "std", "iqr", "range",
        "n_regions", "best_region", "worst_region",
    ])

    for r in rows:
        writer.writerow([
            r.admin0, r.code, r.label, r.domain, r.year,
            round(r.gini, 4) if r.gini else "",
            round(r.cv, 4) if r.cv else "",
            round(r.theil, 4) if r.theil else "",
            round(r.ratio_p90_p10, 2) if r.ratio_p90_p10 else "",
            round(r.ratio_max_min, 2) if r.ratio_max_min else "",
            round(r.mean_value, 2) if r.mean_value else "",
            round(r.median_value, 2) if r.median_value else "",
            round(r.std_dev, 2) if r.std_dev else "",
            round(r.iqr, 2) if r.iqr else "",
            round(r.range_abs, 2) if r.range_abs else "",
            r.n_regions, r.best_region or "", r.worst_region or "",
        ])

    output.seek(0)
    filename = f"localintel_inequality_{admin0 or 'all'}_{year or 'all'}.csv"

    return StreamingResponse(
        output,
        media_type="text/csv",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


# ── Observations CSV Export ──────────────────────────────────────────────────

@router.get("/reports/export/observations.csv")
async def export_observations_csv(
    indicator: str = Query(..., description="Indicator code"),
    admin0: Optional[str] = None,
    year: Optional[int] = None,
    db: AsyncSession = Depends(get_db),
):
    """Export raw observation data as CSV for one indicator."""
    ind = await db.execute(select(Indicator).where(Indicator.code == indicator))
    ind_obj = ind.scalar_one_or_none()
    if not ind_obj:
        raise HTTPException(404, f"Indicator '{indicator}' not found")

    conditions = ["o.indicator_id = :ind_id", "o.value IS NOT NULL"]
    params = {"ind_id": ind_obj.id}

    if admin0:
        conditions.append("r.admin0 = :admin0")
        params["admin0"] = admin0
    if year:
        conditions.append("o.year = :year")
        params["year"] = year

    where_clause = " AND ".join(conditions)

    result = await db.execute(
        text(f"""
            SELECT r.geo, r.name, r.admin0, r.country_name,
                   o.year, o.value, o.ci_lo, o.ci_hi, o.imp_flag
            FROM observations o
            JOIN regions r ON o.region_id = r.id
            WHERE {where_clause}
            ORDER BY r.admin0, r.name, o.year
        """),
        params,
    )
    rows = result.all()

    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(["geo", "region", "admin0", "country", "year", "value", "ci_lo", "ci_hi", "imp_flag"])

    for r in rows:
        writer.writerow([
            r.geo, r.name, r.admin0, r.country_name, r.year,
            round(r.value, 3) if r.value else "",
            round(r.ci_lo, 3) if r.ci_lo else "",
            round(r.ci_hi, 3) if r.ci_hi else "",
            r.imp_flag,
        ])

    output.seek(0)
    filename = f"localintel_{indicator}_{admin0 or 'all'}_{year or 'all'}.csv"

    return StreamingResponse(
        output,
        media_type="text/csv",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )
