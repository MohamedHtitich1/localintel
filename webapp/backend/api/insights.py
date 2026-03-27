"""
API routes for automated narrative insight generation.

Generates structured, data-driven insight narratives from the inequality database.
No LLM required — insights are computed algorithmically from the data patterns.

Insight types:
1. Country spotlight — full inequality profile for one country
2. Indicator spotlight — cross-country comparison for one indicator
3. Convergence/divergence alerts — countries where inequality is changing fast
4. Domain summary — cross-indicator overview for a domain
5. Regional outliers — regions significantly above/below country average
"""

import math
from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, text
from typing import Optional

from backend.database import get_db
from backend.models import Indicator, Observation, Region, InequalityMetric

router = APIRouter(tags=["insights"])


# ── Helpers ──────────────────────────────────────────────────────────────────

def _direction_word(higher_is: str, change: float) -> str:
    """Convert numeric change to 'improving'/'worsening' given indicator direction."""
    if higher_is == "better":
        return "improving" if change > 0 else "worsening"
    else:
        return "improving" if change < 0 else "worsening"


def _severity(gini: float) -> str:
    """Classify inequality severity from Gini coefficient."""
    if gini < 0.10:
        return "low"
    elif gini < 0.20:
        return "moderate"
    elif gini < 0.30:
        return "high"
    else:
        return "very high"


def _format_val(val, unit: str = "%") -> str:
    """Format a value with its unit."""
    if val is None:
        return "N/A"
    if unit == "per 1,000":
        return f"{val:.0f} per 1,000"
    elif unit == "years":
        return f"{val:.1f} years"
    else:
        return f"{val:.1f}%"


# ── 1. Country Spotlight ─────────────────────────────────────────────────────

@router.get("/insights/country/{admin0}")
async def country_spotlight(
    admin0: str,
    year: int = Query(2024, ge=1985, le=2030),
    db: AsyncSession = Depends(get_db),
):
    """
    Full inequality spotlight for a country: which domains have the highest
    disparities, which regions are outliers, how inequality has changed over time.
    Returns structured insight cards for rendering.
    """
    # Verify country exists
    region_check = await db.execute(
        select(Region.country_name).where(Region.admin0 == admin0).limit(1)
    )
    row = region_check.scalar_one_or_none()
    if not row:
        raise HTTPException(404, f"Country '{admin0}' not found")
    country_name = row

    # Get all inequality metrics for this country/year
    result = await db.execute(
        text("""
            SELECT i.code, i.label, i.domain, i.unit, i.higher_is,
                   im.gini, im.cv, im.theil, im.ratio_p90_p10,
                   im.mean_value, im.n_regions, im.best_region, im.worst_region,
                   im.range_abs
            FROM inequality_metrics im
            JOIN indicators i ON im.indicator_id = i.id
            WHERE im.admin0 = :admin0 AND im.year = :year AND im.gini IS NOT NULL
            ORDER BY im.gini DESC
        """),
        {"admin0": admin0, "year": year},
    )
    rows = result.all()

    if not rows:
        raise HTTPException(404, f"No inequality data for {admin0} in {year}")

    # Build domain-level summary
    domain_ginis = {}
    for r in rows:
        if r.domain not in domain_ginis:
            domain_ginis[r.domain] = []
        domain_ginis[r.domain].append({
            "code": r.code, "label": r.label, "gini": r.gini,
            "cv": r.cv, "mean": r.mean_value,
        })

    domain_summary = []
    for domain, indicators in sorted(domain_ginis.items(), key=lambda x: -max(i["gini"] for i in x[1])):
        avg_gini = sum(i["gini"] for i in indicators) / len(indicators)
        worst = max(indicators, key=lambda x: x["gini"])
        domain_summary.append({
            "domain": domain,
            "avg_gini": round(avg_gini, 4),
            "severity": _severity(avg_gini),
            "n_indicators": len(indicators),
            "most_unequal_indicator": worst["label"],
            "most_unequal_gini": round(worst["gini"], 4),
        })

    # Top 5 most unequal indicators
    top_unequal = [
        {
            "indicator": r.label,
            "code": r.code,
            "gini": round(r.gini, 4),
            "severity": _severity(r.gini),
            "p90_p10": round(r.ratio_p90_p10, 1) if r.ratio_p90_p10 else None,
            "range": round(r.range_abs, 1),
            "mean": round(r.mean_value, 1),
            "best_region": r.best_region,
            "worst_region": r.worst_region,
        }
        for r in rows[:5]
    ]

    # Narrative headline
    most_unequal_domain = domain_summary[0] if domain_summary else None
    headline = (
        f"{country_name}'s sharpest subnational disparities are in "
        f"{most_unequal_domain['domain']} (avg Gini {most_unequal_domain['avg_gini']:.3f}), "
        f"driven by {most_unequal_domain['most_unequal_indicator']} "
        f"(Gini {most_unequal_domain['most_unequal_gini']:.3f})."
    ) if most_unequal_domain else ""

    # Gini trend for top indicator
    gini_trend = None
    if rows:
        top_code = rows[0].code
        trend_result = await db.execute(
            text("""
                SELECT im.year, im.gini
                FROM inequality_metrics im
                JOIN indicators i ON im.indicator_id = i.id
                WHERE im.admin0 = :admin0 AND i.code = :code AND im.gini IS NOT NULL
                ORDER BY im.year
            """),
            {"admin0": admin0, "code": top_code},
        )
        trend_rows = trend_result.all()
        if len(trend_rows) >= 2:
            first_g = trend_rows[0].gini
            last_g = trend_rows[-1].gini
            pct_change = ((last_g - first_g) / abs(first_g)) * 100 if first_g != 0 else 0
            gini_trend = {
                "indicator": top_code,
                "from_year": trend_rows[0].year,
                "to_year": trend_rows[-1].year,
                "from_gini": round(first_g, 4),
                "to_gini": round(last_g, 4),
                "pct_change": round(pct_change, 1),
                "trajectory": "widening" if pct_change > 5 else "narrowing" if pct_change < -5 else "stable",
                "series": [{"year": r.year, "gini": round(r.gini, 4)} for r in trend_rows],
            }

    return {
        "admin0": admin0,
        "country": country_name,
        "year": year,
        "headline": headline,
        "n_indicators_assessed": len(rows),
        "overall_avg_gini": round(sum(r.gini for r in rows) / len(rows), 4),
        "domain_summary": domain_summary,
        "top_unequal_indicators": top_unequal,
        "gini_trend": gini_trend,
    }


# ── 2. Indicator Spotlight ───────────────────────────────────────────────────

@router.get("/insights/indicator/{code}")
async def indicator_spotlight(
    code: str,
    year: int = Query(2024, ge=1985, le=2030),
    db: AsyncSession = Depends(get_db),
):
    """
    Cross-country inequality comparison for a single indicator.
    Which countries have the highest disparities? Which are converging/diverging?
    """
    ind = await db.execute(select(Indicator).where(Indicator.code == code))
    indicator = ind.scalar_one_or_none()
    if not indicator:
        raise HTTPException(404, f"Indicator '{code}' not found")

    # Get all countries' inequality for this indicator/year
    result = await db.execute(
        text("""
            SELECT im.admin0, r_best.name as best_name, r_worst.name as worst_name,
                   im.gini, im.cv, im.theil, im.ratio_p90_p10,
                   im.mean_value, im.n_regions, im.range_abs,
                   im.best_region, im.worst_region
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
        raise HTTPException(404, f"No inequality data for {code} in {year}")

    ginis = [r.gini for r in rows]
    continent_avg_gini = sum(ginis) / len(ginis)

    # Classify countries
    high_ineq = [r for r in rows if r.gini > continent_avg_gini * 1.3]
    low_ineq = [r for r in rows if r.gini < continent_avg_gini * 0.7]

    # Build convergence analysis — fetch multi-year Gini for each country
    convergence = []
    for r in rows:
        trend_result = await db.execute(
            text("""
                SELECT year, gini FROM inequality_metrics
                WHERE indicator_id = :ind_id AND admin0 = :admin0 AND gini IS NOT NULL
                ORDER BY year
            """),
            {"ind_id": indicator.id, "admin0": r.admin0},
        )
        trend = trend_result.all()
        if len(trend) >= 3:
            first_g = trend[0].gini
            last_g = trend[-1].gini
            pct = ((last_g - first_g) / abs(first_g)) * 100 if first_g != 0 else 0
            if abs(pct) > 10:
                convergence.append({
                    "admin0": r.admin0,
                    "from_year": trend[0].year,
                    "to_year": trend[-1].year,
                    "from_gini": round(first_g, 4),
                    "to_gini": round(last_g, 4),
                    "pct_change": round(pct, 1),
                    "trajectory": "diverging" if pct > 0 else "converging",
                })

    # Sort convergence: biggest movers first
    convergence.sort(key=lambda x: abs(x["pct_change"]), reverse=True)

    headline = (
        f"Across {len(rows)} SSA countries, subnational inequality in "
        f"{indicator.label.lower()} ranges from Gini {min(ginis):.3f} to {max(ginis):.3f} "
        f"(continental average: {continent_avg_gini:.3f})."
    )

    return {
        "indicator": code,
        "label": indicator.label,
        "unit": indicator.unit,
        "higher_is": indicator.higher_is,
        "year": year,
        "headline": headline,
        "n_countries": len(rows),
        "continent_avg_gini": round(continent_avg_gini, 4),
        "ranking": [
            {
                "rank": i + 1,
                "admin0": r.admin0,
                "gini": round(r.gini, 4),
                "severity": _severity(r.gini),
                "mean": round(r.mean_value, 1) if r.mean_value else None,
                "p90_p10": round(r.ratio_p90_p10, 1) if r.ratio_p90_p10 else None,
                "best_region": r.best_name,
                "worst_region": r.worst_name,
                "n_regions": r.n_regions,
            }
            for i, r in enumerate(rows)
        ],
        "high_inequality_countries": [r.admin0 for r in high_ineq],
        "low_inequality_countries": [r.admin0 for r in low_ineq],
        "convergence_alerts": convergence[:10],
    }


# ── 3. Convergence/Divergence Alerts ────────────────────────────────────────

@router.get("/insights/alerts")
async def inequality_alerts(
    year: int = Query(2024, ge=1985, le=2030),
    min_change_pct: float = Query(15.0, description="Minimum Gini % change to flag"),
    db: AsyncSession = Depends(get_db),
):
    """
    Surface countries x indicators where inequality is changing rapidly.
    Returns alerts sorted by magnitude of change.

    Optimised: single SQL query with window functions instead of N+1 loop.
    """
    result = await db.execute(
        text("""
            WITH per_indicator AS (
                SELECT
                    im.indicator_id,
                    im.admin0,
                    im.year,
                    im.gini,
                    MIN(im.year)  OVER (PARTITION BY im.indicator_id, im.admin0) AS first_year,
                    MAX(im.year)  OVER (PARTITION BY im.indicator_id, im.admin0) AS last_year,
                    FIRST_VALUE(im.gini) OVER (
                        PARTITION BY im.indicator_id, im.admin0
                        ORDER BY im.year
                        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
                    ) AS first_gini,
                    COUNT(*) OVER (PARTITION BY im.indicator_id, im.admin0) AS n_years
                FROM inequality_metrics im
                WHERE im.gini IS NOT NULL
            ),
            current AS (
                SELECT DISTINCT ON (indicator_id, admin0)
                    indicator_id, admin0, first_year, last_year, first_gini, n_years,
                    gini AS current_gini
                FROM per_indicator
                WHERE year = :year
                  AND n_years >= 3
                  AND first_gini > 0.005
            )
            SELECT
                c.admin0,
                i.code   AS indicator,
                i.label  AS indicator_label,
                i.domain,
                c.first_year,
                c.last_year,
                c.first_gini,
                c.current_gini,
                c.n_years,
                ROUND(((c.current_gini - c.first_gini) / ABS(c.first_gini) * 100)::numeric, 1) AS pct_change
            FROM current c
            JOIN indicators i ON i.id = c.indicator_id
            WHERE ABS((c.current_gini - c.first_gini) / ABS(c.first_gini) * 100) >= :min_change
              AND ABS((c.current_gini - c.first_gini) / ABS(c.first_gini) * 100) < 10000
            ORDER BY ABS((c.current_gini - c.first_gini) / ABS(c.first_gini) * 100) DESC
        """),
        {"year": year, "min_change": min_change_pct},
    )

    alerts = []
    for r in result.all():
        pct = float(r.pct_change)
        alerts.append({
            "admin0": r.admin0,
            "indicator": r.indicator,
            "indicator_label": r.indicator_label,
            "domain": r.domain,
            "from_year": r.first_year,
            "to_year": r.last_year,
            "from_gini": round(float(r.first_gini), 4),
            "current_gini": round(float(r.current_gini), 4),
            "pct_change": pct,
            "trajectory": "diverging" if pct > 0 else "converging",
            "severity": _severity(float(r.current_gini)),
            "n_data_years": r.n_years,
        })

    # Summary
    diverging = [a for a in alerts if a["trajectory"] == "diverging"]
    converging = [a for a in alerts if a["trajectory"] == "converging"]

    return {
        "year": year,
        "threshold_pct": min_change_pct,
        "total_alerts": len(alerts),
        "diverging_count": len(diverging),
        "converging_count": len(converging),
        "alerts": alerts[:50],
        "top_diverging": diverging[:10],
        "top_converging": converging[:10],
    }


# ── 4. Domain Summary ───────────────────────────────────────────────────────

@router.get("/insights/domain/{domain}")
async def domain_summary(
    domain: str,
    year: int = Query(2024, ge=1985, le=2030),
    db: AsyncSession = Depends(get_db),
):
    """
    Cross-indicator summary for a thematic domain.
    Which indicators in this domain have the most inequality? Which countries are worst?
    """
    # Get indicators in this domain
    ind_result = await db.execute(
        select(Indicator).where(Indicator.domain == domain)
    )
    indicators = ind_result.scalars().all()

    if not indicators:
        # Try case-insensitive match
        ind_result = await db.execute(
            select(Indicator).where(func.lower(Indicator.domain) == domain.lower())
        )
        indicators = ind_result.scalars().all()
        if not indicators:
            raise HTTPException(404, f"Domain '{domain}' not found")

    indicator_profiles = []
    all_country_ginis = {}  # admin0 -> list of ginis across indicators

    for ind in indicators:
        result = await db.execute(
            text("""
                SELECT admin0, gini, mean_value, n_regions
                FROM inequality_metrics
                WHERE indicator_id = :ind_id AND year = :year AND gini IS NOT NULL
                ORDER BY gini DESC
            """),
            {"ind_id": ind.id, "year": year},
        )
        rows = result.all()

        if not rows:
            continue

        ginis = [r.gini for r in rows]
        avg_gini = sum(ginis) / len(ginis)

        for r in rows:
            if r.admin0 not in all_country_ginis:
                all_country_ginis[r.admin0] = []
            all_country_ginis[r.admin0].append(r.gini)

        indicator_profiles.append({
            "code": ind.code,
            "label": ind.label,
            "avg_gini": round(avg_gini, 4),
            "max_gini": round(max(ginis), 4),
            "min_gini": round(min(ginis), 4),
            "n_countries": len(rows),
            "most_unequal_country": rows[0].admin0,
            "least_unequal_country": rows[-1].admin0,
        })

    # Country rankings across the domain
    country_rankings = []
    for admin0, ginis in sorted(all_country_ginis.items(), key=lambda x: -sum(x[1]) / len(x[1])):
        country_rankings.append({
            "admin0": admin0,
            "avg_gini": round(sum(ginis) / len(ginis), 4),
            "n_indicators": len(ginis),
            "max_gini": round(max(ginis), 4),
        })

    # Sort indicators by inequality
    indicator_profiles.sort(key=lambda x: -x["avg_gini"])

    return {
        "domain": domain,
        "year": year,
        "n_indicators": len(indicator_profiles),
        "n_countries": len(country_rankings),
        "domain_avg_gini": round(
            sum(ip["avg_gini"] for ip in indicator_profiles) / len(indicator_profiles), 4
        ) if indicator_profiles else None,
        "most_unequal_indicator": indicator_profiles[0] if indicator_profiles else None,
        "least_unequal_indicator": indicator_profiles[-1] if indicator_profiles else None,
        "indicators": indicator_profiles,
        "country_rankings": country_rankings[:15],
    }


# ── 5. Regional Outliers ────────────────────────────────────────────────────

@router.get("/insights/outliers/{admin0}")
async def regional_outliers(
    admin0: str,
    year: int = Query(2024, ge=1985, le=2030),
    threshold_sd: float = Query(1.5, description="Standard deviations from mean to flag"),
    db: AsyncSession = Depends(get_db),
):
    """
    Find regions significantly above or below the country average across indicators.
    Identifies persistently disadvantaged or advantaged regions.
    """
    # Get all observations for this country/year
    result = await db.execute(
        text("""
            SELECT r.geo, r.name, i.code, i.label, i.domain, i.unit, i.higher_is,
                   o.value, o.imp_flag
            FROM observations o
            JOIN regions r ON o.region_id = r.id
            JOIN indicators i ON o.indicator_id = i.id
            WHERE r.admin0 = :admin0 AND o.year = :year AND o.value IS NOT NULL
            ORDER BY r.name, i.domain
        """),
        {"admin0": admin0, "year": year},
    )
    rows = result.all()

    if not rows:
        raise HTTPException(404, f"No data for {admin0} in {year}")

    # Compute per-indicator stats
    indicator_stats = {}
    for r in rows:
        if r.code not in indicator_stats:
            indicator_stats[r.code] = {
                "label": r.label, "domain": r.domain, "unit": r.unit,
                "higher_is": r.higher_is, "values": [],
            }
        indicator_stats[r.code]["values"].append({"geo": r.geo, "name": r.name, "value": r.value})

    for code, stats in indicator_stats.items():
        vals = [v["value"] for v in stats["values"]]
        stats["mean"] = sum(vals) / len(vals)
        stats["std"] = (sum((v - stats["mean"]) ** 2 for v in vals) / len(vals)) ** 0.5

    # Find outlier regions
    region_outliers = {}  # geo -> list of outlier indicators

    for code, stats in indicator_stats.items():
        if stats["std"] == 0:
            continue
        for entry in stats["values"]:
            z = (entry["value"] - stats["mean"]) / stats["std"]
            if abs(z) >= threshold_sd:
                geo = entry["geo"]
                if geo not in region_outliers:
                    region_outliers[geo] = {"name": entry["name"], "above": [], "below": []}

                outlier_info = {
                    "indicator": code,
                    "label": stats["label"],
                    "domain": stats["domain"],
                    "value": round(entry["value"], 1),
                    "country_mean": round(stats["mean"], 1),
                    "z_score": round(z, 2),
                    "unit": stats["unit"],
                }

                is_advantaged = (z > 0 and stats["higher_is"] == "better") or \
                                (z < 0 and stats["higher_is"] == "worse")

                if is_advantaged:
                    region_outliers[geo]["above"].append(outlier_info)
                else:
                    region_outliers[geo]["below"].append(outlier_info)

    # Build output — most disadvantaged regions first
    outlier_list = []
    for geo, data in region_outliers.items():
        n_disadvantaged = len(data["below"])
        n_advantaged = len(data["above"])
        outlier_list.append({
            "geo": geo,
            "name": data["name"],
            "n_disadvantaged": n_disadvantaged,
            "n_advantaged": n_advantaged,
            "net_score": n_advantaged - n_disadvantaged,
            "disadvantaged_in": data["below"][:5],
            "advantaged_in": data["above"][:5],
        })

    outlier_list.sort(key=lambda x: x["net_score"])

    return {
        "admin0": admin0,
        "year": year,
        "threshold_sd": threshold_sd,
        "n_regions_flagged": len(outlier_list),
        "n_indicators_assessed": len(indicator_stats),
        "most_disadvantaged": outlier_list[:10],
        "most_advantaged": outlier_list[-10:][::-1] if len(outlier_list) > 10 else [],
    }
