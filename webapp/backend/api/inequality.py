"""
API routes for the inequality metrics engine.
Serves pre-computed inequality measures and cross-country comparisons.
"""

from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, text
from typing import Optional

from backend.database import get_db
from backend.models import InequalityMetric, Indicator, Region

router = APIRouter(tags=["inequality"])


@router.get("/inequality/{code}/map")
async def inequality_map(
    code: str,
    year: int = Query(2024, ge=1985, le=2024),
    metric: str = Query("gini", description="gini|cv|theil|ratio_max_min|ratio_p90_p10"),
    db: AsyncSession = Depends(get_db),
):
    """
    Get country-level inequality metric for one indicator.
    Used for the inequality choropleth (country-level shading).
    """
    ind = await db.execute(select(Indicator).where(Indicator.code == code))
    indicator = ind.scalar_one_or_none()
    if not indicator:
        raise HTTPException(404, f"Indicator '{code}' not found")

    valid_metrics = ["gini", "cv", "theil", "ratio_max_min", "ratio_p90_p10", "iqr", "range_abs"]
    if metric not in valid_metrics:
        raise HTTPException(400, f"Invalid metric. Choose from: {valid_metrics}")

    result = await db.execute(
        select(InequalityMetric)
        .where(
            InequalityMetric.indicator_id == indicator.id,
            InequalityMetric.year == year,
        )
        .order_by(InequalityMetric.admin0)
    )
    rows = result.scalars().all()

    return {
        "indicator": code,
        "label": indicator.label,
        "metric": metric,
        "year": year,
        "countries": {
            r.admin0: {
                "value": round(getattr(r, metric), 4) if getattr(r, metric) is not None else None,
                "mean": round(r.mean_value, 3) if r.mean_value else None,
                "n_regions": r.n_regions,
                "best_region": r.best_region,
                "worst_region": r.worst_region,
                "gini": round(r.gini, 4) if r.gini else None,
                "cv": round(r.cv, 4) if r.cv else None,
                "ratio_p90_p10": round(r.ratio_p90_p10, 2) if r.ratio_p90_p10 else None,
            }
            for r in rows
        },
    }


@router.get("/inequality/{code}/ranking")
async def inequality_ranking(
    code: str,
    year: int = Query(2024, ge=1985, le=2024),
    metric: str = Query("gini"),
    db: AsyncSession = Depends(get_db),
):
    """Rank countries by inequality in a given indicator."""
    valid_metrics = ["gini", "cv", "theil", "ratio_max_min", "ratio_p90_p10", "iqr", "range_abs"]
    if metric not in valid_metrics:
        raise HTTPException(400, f"Invalid metric. Choose from: {valid_metrics}")

    ind = await db.execute(select(Indicator).where(Indicator.code == code))
    indicator = ind.scalar_one_or_none()
    if not indicator:
        raise HTTPException(404, f"Indicator '{code}' not found")

    # Safe: `metric` is validated against whitelist above
    col = metric  # guaranteed to be one of the valid column names
    result = await db.execute(
        text(f"""
            SELECT im.admin0, r_best.name as best_name, r_worst.name as worst_name,
                   im.{col} as metric_value, im.mean_value, im.n_regions,
                   im.best_region, im.worst_region, im.gini, im.cv
            FROM inequality_metrics im
            LEFT JOIN regions r_best ON r_best.geo = im.best_region
            LEFT JOIN regions r_worst ON r_worst.geo = im.worst_region
            WHERE im.indicator_id = :ind_id AND im.year = :year
                  AND im.{col} IS NOT NULL
            ORDER BY im.{col} DESC
        """),
        {"ind_id": indicator.id, "year": year},
    )
    rows = result.all()

    return {
        "indicator": code,
        "metric": metric,
        "year": year,
        "ranking": [
            {
                "rank": i + 1,
                "admin0": r.admin0,
                "value": round(r.metric_value, 4),
                "mean": round(r.mean_value, 3) if r.mean_value else None,
                "n_regions": r.n_regions,
                "best_region": r.best_name,
                "worst_region": r.worst_name,
            }
            for i, r in enumerate(rows)
        ],
    }


@router.get("/inequality/{code}/trend")
async def inequality_trend(
    code: str,
    admin0: Optional[str] = None,
    metric: str = Query("gini"),
    db: AsyncSession = Depends(get_db),
):
    """
    Get inequality trend over time for an indicator.
    Optionally filter by country. Returns continental aggregate if no country specified.
    """
    ind = await db.execute(select(Indicator).where(Indicator.code == code))
    indicator = ind.scalar_one_or_none()
    if not indicator:
        raise HTTPException(404, f"Indicator '{code}' not found")

    valid_metrics = ["gini", "cv", "theil", "ratio_max_min", "ratio_p90_p10"]
    if metric not in valid_metrics:
        raise HTTPException(400, f"Invalid metric.")

    if admin0:
        result = await db.execute(
            select(InequalityMetric)
            .where(
                InequalityMetric.indicator_id == indicator.id,
                InequalityMetric.admin0 == admin0,
            )
            .order_by(InequalityMetric.year)
        )
        rows = result.scalars().all()
        return {
            "indicator": code, "admin0": admin0, "metric": metric,
            "trend": [
                {"year": r.year, "value": round(getattr(r, metric), 4) if getattr(r, metric) else None}
                for r in rows
            ],
        }
    else:
        # Continental average — `metric` is validated against whitelist above
        col = metric
        result = await db.execute(
            text(f"""
                SELECT year, AVG({col}) as avg_value,
                       MIN({col}) as min_value, MAX({col}) as max_value,
                       COUNT(*) as n_countries
                FROM inequality_metrics
                WHERE indicator_id = :ind_id AND {col} IS NOT NULL
                GROUP BY year ORDER BY year
            """),
            {"ind_id": indicator.id},
        )
        rows = result.all()
        return {
            "indicator": code, "metric": metric, "scope": "continental",
            "trend": [
                {
                    "year": r.year,
                    "mean": round(r.avg_value, 4),
                    "min": round(r.min_value, 4),
                    "max": round(r.max_value, 4),
                    "n_countries": r.n_countries,
                }
                for r in rows
            ],
        }


@router.get("/inequality/dashboard")
async def inequality_dashboard(
    year: int = Query(2024, ge=1985, le=2024),
    db: AsyncSession = Depends(get_db),
):
    """
    Dashboard summary: for each domain, return the flagship indicator's
    inequality ranking across countries.
    """
    # Flagship indicators per domain (best coverage)
    flagships = {
        "Maternal & Child Health": "anc_4plus",
        "Mortality": "u5_mortality",
        "Nutrition": "stunting",
        "HIV/AIDS": "hiv_prevalence",
        "Education": "literacy_women",
        "Water & Sanitation": "improved_water",
        "Wealth & Assets": "electricity",
        "Gender": "dv_attitude_women",
    }

    dashboard = {}
    for domain, code in flagships.items():
        ind_result = await db.execute(select(Indicator).where(Indicator.code == code))
        indicator = ind_result.scalar_one_or_none()
        if not indicator:
            continue

        result = await db.execute(
            select(
                func.avg(InequalityMetric.gini).label("avg_gini"),
                func.max(InequalityMetric.gini).label("max_gini"),
                func.min(InequalityMetric.gini).label("min_gini"),
                func.count(InequalityMetric.id).label("n_countries"),
            )
            .where(
                InequalityMetric.indicator_id == indicator.id,
                InequalityMetric.year == year,
                InequalityMetric.gini.isnot(None),
            )
        )
        row = result.one()

        dashboard[domain] = {
            "indicator": code,
            "label": indicator.label,
            "avg_gini": round(row.avg_gini, 4) if row.avg_gini else None,
            "max_gini": round(row.max_gini, 4) if row.max_gini else None,
            "min_gini": round(row.min_gini, 4) if row.min_gini else None,
            "n_countries": row.n_countries,
        }

    return {"year": year, "domains": dashboard}


@router.get("/inequality/{code}/insights/{admin0}")
async def country_indicator_insights(
    code: str,
    admin0: str,
    year: int = Query(2024, ge=1985, le=2024),
    db: AsyncSession = Depends(get_db),
):
    """
    Generate live indicator-focused insights for a country.
    Computes from the database: overview, regional disparities, convergence trajectory.
    No cross-indicator context or data quality — purely about this indicator.
    Returns structured insight cards for the frontend to render.
    """
    # Resolve indicator
    ind = await db.execute(select(Indicator).where(Indicator.code == code))
    indicator = ind.scalar_one_or_none()
    if not indicator:
        raise HTTPException(404, f"Indicator '{code}' not found")

    # --- 1. Current year inequality metrics for this country ---
    ineq_result = await db.execute(
        select(InequalityMetric).where(
            InequalityMetric.indicator_id == indicator.id,
            InequalityMetric.admin0 == admin0,
            InequalityMetric.year == year,
        )
    )
    ineq = ineq_result.scalar_one_or_none()

    # --- 2. All region values for this country/indicator/year ---
    regions_result = await db.execute(
        text("""
            SELECT r.geo, r.name, o.value, o.ci_lo, o.ci_hi, o.imp_flag
            FROM observations o
            JOIN regions r ON o.region_id = r.id
            WHERE r.admin0 = :admin0 AND o.indicator_id = :ind_id AND o.year = :year
                  AND o.value IS NOT NULL
            ORDER BY o.value ASC
        """),
        {"admin0": admin0, "ind_id": indicator.id, "year": year},
    )
    regions = regions_result.all()

    if not regions:
        raise HTTPException(404, f"No data for {admin0} / {code} / {year}")

    values = [r.value for r in regions]
    n_regions = len(values)
    country_mean = sum(values) / n_regions
    country_min = min(values)
    country_max = max(values)
    country_range = country_max - country_min

    # Best/worst depend on higher_is
    if indicator.higher_is == "better":
        best = regions[-1]  # highest value
        worst = regions[0]   # lowest value
    else:
        best = regions[0]    # lowest value
        worst = regions[-1]  # highest value

    # --- 3. SSA average for this indicator/year ---
    ssa_result = await db.execute(
        text("""
            SELECT AVG(o.value) as ssa_mean, COUNT(DISTINCT r.admin0) as n_countries
            FROM observations o
            JOIN regions r ON o.region_id = r.id
            WHERE o.indicator_id = :ind_id AND o.year = :year AND o.value IS NOT NULL
        """),
        {"ind_id": indicator.id, "year": year},
    )
    ssa_row = ssa_result.one()
    ssa_mean = round(ssa_row.ssa_mean, 1) if ssa_row.ssa_mean else None

    # --- 4. Gini ranking among all countries ---
    gini_rank = None
    total_countries = 0
    if ineq and ineq.gini is not None:
        rank_result = await db.execute(
            text("""
                SELECT COUNT(*) + 1 as rank
                FROM inequality_metrics
                WHERE indicator_id = :ind_id AND year = :year AND gini IS NOT NULL
                      AND gini > :gini
            """),
            {"ind_id": indicator.id, "year": year, "gini": ineq.gini},
        )
        gini_rank = rank_result.scalar()

        total_result = await db.execute(
            text("""
                SELECT COUNT(*) FROM inequality_metrics
                WHERE indicator_id = :ind_id AND year = :year AND gini IS NOT NULL
            """),
            {"ind_id": indicator.id, "year": year},
        )
        total_countries = total_result.scalar()

    # --- 5. Trend: compare earliest and latest available years ---
    trend_result = await db.execute(
        text("""
            SELECT year, AVG(o.value) as mean_val
            FROM observations o
            JOIN regions r ON o.region_id = r.id
            WHERE r.admin0 = :admin0 AND o.indicator_id = :ind_id AND o.value IS NOT NULL
            GROUP BY year ORDER BY year
        """),
        {"admin0": admin0, "ind_id": indicator.id},
    )
    trend_rows = trend_result.all()

    trend_direction = None
    trend_pct = None
    first_year = None
    last_year = None
    if len(trend_rows) >= 2:
        first_year = trend_rows[0].year
        last_year = trend_rows[-1].year
        first_val = trend_rows[0].mean_val
        last_val = trend_rows[-1].mean_val
        if first_val and first_val != 0:
            trend_pct = round(((last_val - first_val) / abs(first_val)) * 100, 1)
            if indicator.higher_is == "better":
                trend_direction = "improving" if last_val > first_val else "worsening"
            else:
                trend_direction = "improving" if last_val < first_val else "worsening"

    # --- 6. Gini trend over time ---
    gini_trend_result = await db.execute(
        select(InequalityMetric.year, InequalityMetric.gini)
        .where(
            InequalityMetric.indicator_id == indicator.id,
            InequalityMetric.admin0 == admin0,
            InequalityMetric.gini.isnot(None),
        )
        .order_by(InequalityMetric.year)
    )
    gini_trend = gini_trend_result.all()
    gini_trajectory = None
    if len(gini_trend) >= 2:
        first_gini = gini_trend[0].gini
        last_gini = gini_trend[-1].gini
        if first_gini and first_gini != 0:
            gini_change = ((last_gini - first_gini) / abs(first_gini)) * 100
            if abs(gini_change) < 5:
                gini_trajectory = "stable"
            elif gini_change > 0:
                gini_trajectory = "widening"
            else:
                gini_trajectory = "narrowing"

    # --- 7. Percentile distribution ---
    sorted_vals = sorted(values)
    p10 = sorted_vals[max(0, int(n_regions * 0.1))]
    p25 = sorted_vals[max(0, int(n_regions * 0.25))]
    p50 = sorted_vals[max(0, int(n_regions * 0.5))]
    p75 = sorted_vals[max(0, int(n_regions * 0.75))]
    p90 = sorted_vals[max(0, min(int(n_regions * 0.9), n_regions - 1))]

    return {
        "admin0": admin0,
        "indicator": code,
        "label": indicator.label,
        "unit": indicator.unit,
        "higher_is": indicator.higher_is,
        "year": year,
        "n_regions": n_regions,
        "country_mean": round(country_mean, 1),
        "ssa_mean": ssa_mean,
        "best_region": {"name": best.name, "value": round(best.value, 1)},
        "worst_region": {"name": worst.name, "value": round(worst.value, 1)},
        "range": round(country_range, 1),
        "ratio": round(country_max / country_min, 1) if country_min > 0 else None,
        "gini": round(ineq.gini, 4) if ineq and ineq.gini else None,
        "gini_rank": gini_rank,
        "total_countries": total_countries,
        "trend": {
            "direction": trend_direction,
            "pct_change": trend_pct,
            "from_year": first_year,
            "to_year": last_year,
        },
        "gini_trajectory": gini_trajectory,
        "distribution": {
            "p10": round(p10, 1),
            "p25": round(p25, 1),
            "p50": round(p50, 1),
            "p75": round(p75, 1),
            "p90": round(p90, 1),
            "min": round(country_min, 1),
            "max": round(country_max, 1),
        },
        "regions": [
            {"name": r.name, "value": round(r.value, 1), "flag": r.imp_flag}
            for r in regions
        ],
    }
