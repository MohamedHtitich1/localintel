"""
Inequality metrics computation engine.

Extracted from ingest.py for reuse by:
- Initial ingestion pipeline
- Selective metric refresh via admin API
- Scheduled cron refresh

Computes: Gini, Theil, CV, P90/P10, max/min ratio, IQR, range, mean, median, std.
"""

import logging
import numpy as np
from sqlalchemy import select, func, text, delete
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Optional

from backend.models import Indicator, Observation, Region, InequalityMetric

logger = logging.getLogger("localintel.metrics")

# Indicators where higher value = worse outcome
HIGHER_IS_WORSE = {
    "u5_mortality", "infant_mortality", "neonatal_mortality", "perinatal_mortality",
    "child_mortality", "stunting", "wasting", "underweight", "anemia_children",
    "anemia_women", "low_bmi_women", "hiv_prevalence", "unmet_need_fp",
    "no_education_women", "no_education_men", "surface_water", "open_defecation",
    "dv_physical", "dv_sexual", "dv_emotional", "dv_attitude_women", "dv_attitude_men",
    "wealth_lowest",
}


def compute_gini(values: np.ndarray) -> Optional[float]:
    """Compute Gini coefficient from an array of positive values."""
    if len(values) < 2:
        return None
    values = np.sort(values)
    n = len(values)
    indices = np.arange(1, n + 1)
    total = np.sum(values)
    if total == 0:
        return None
    return float((2 * np.sum(indices * values) - (n + 1) * total) / (n * total))


def compute_theil(values: np.ndarray) -> Optional[float]:
    """Compute Theil index (GE(1)) — generalized entropy."""
    if len(values) < 2:
        return None
    mu = np.mean(values)
    if mu <= 0:
        return None
    ratios = values / mu
    ratios = ratios[ratios > 0]
    if len(ratios) < 2:
        return None
    return float(np.mean(ratios * np.log(ratios)))


def compute_inequality_metrics(
    values: np.ndarray,
    geo_codes: list,
    higher_is_worse: bool,
) -> Optional[dict]:
    """
    Compute full inequality metrics suite for an array of region values.
    Returns dict of all metrics or None if insufficient data.
    """
    clean = values[~np.isnan(values)]
    if len(clean) < 2:
        return None

    valid_mask = ~np.isnan(values)
    valid_vals = values[valid_mask]
    valid_geos = [g for g, m in zip(geo_codes, valid_mask) if m]

    if higher_is_worse:
        best_idx = int(np.argmin(valid_vals))
        worst_idx = int(np.argmax(valid_vals))
    else:
        best_idx = int(np.argmax(valid_vals))
        worst_idx = int(np.argmin(valid_vals))

    # Shift for Gini/Theil (need positive values)
    shifted = clean.copy()
    if np.any(shifted <= 0):
        shifted = shifted - shifted.min() + 0.01

    sorted_vals = np.sort(clean)
    n = len(clean)
    p10_idx = max(0, int(n * 0.1))
    p90_idx = min(n - 1, int(n * 0.9))
    p10 = sorted_vals[p10_idx]
    p90 = sorted_vals[p90_idx]
    q1 = float(np.percentile(clean, 25))
    q3 = float(np.percentile(clean, 75))

    mean_val = float(np.mean(clean))

    return {
        "gini": compute_gini(shifted),
        "cv": float(np.std(clean) / mean_val) if mean_val != 0 else None,
        "theil": compute_theil(shifted),
        "ratio_max_min": float(np.max(clean) / np.min(clean)) if np.min(clean) > 0 else None,
        "ratio_p90_p10": float(p90 / p10) if p10 > 0 else None,
        "range_abs": float(np.max(clean) - np.min(clean)),
        "iqr": float(q3 - q1),
        "mean_value": mean_val,
        "median_value": float(np.median(clean)),
        "std_dev": float(np.std(clean)),
        "n_regions": int(n),
        "best_region": valid_geos[best_idx],
        "worst_region": valid_geos[worst_idx],
    }


async def recompute_inequality_for_country(
    db: AsyncSession,
    admin0: str,
    indicator_id: int,
    indicator_code: str,
    years: list[int],
) -> int:
    """
    Recompute inequality metrics for one country x indicator across given years.
    Deletes old metrics and inserts fresh ones.
    Returns count of metrics inserted.
    """
    is_worse = indicator_code in HIGHER_IS_WORSE
    n_inserted = 0

    for year in years:
        # Fetch region values for this country/indicator/year
        result = await db.execute(
            text("""
                SELECT r.geo, o.value
                FROM observations o
                JOIN regions r ON o.region_id = r.id
                WHERE r.admin0 = :admin0
                  AND o.indicator_id = :ind_id
                  AND o.year = :year
                  AND o.value IS NOT NULL
                ORDER BY r.geo
            """),
            {"admin0": admin0, "ind_id": indicator_id, "year": year},
        )
        rows = result.all()

        if len(rows) < 2:
            continue

        geos = [r.geo for r in rows]
        vals = np.array([r.value for r in rows], dtype=float)

        metrics = compute_inequality_metrics(vals, geos, is_worse)
        if metrics is None:
            continue

        # Delete existing metric for this combo
        await db.execute(
            delete(InequalityMetric).where(
                InequalityMetric.admin0 == admin0,
                InequalityMetric.indicator_id == indicator_id,
                InequalityMetric.year == year,
            )
        )

        db.add(InequalityMetric(
            admin0=admin0,
            indicator_id=indicator_id,
            year=year,
            **metrics,
        ))
        n_inserted += 1

    await db.commit()
    return n_inserted


async def recompute_all_inequality(
    db: AsyncSession,
    admin0: Optional[str] = None,
    indicator_code: Optional[str] = None,
    year_from: Optional[int] = None,
    year_to: Optional[int] = None,
) -> dict:
    """
    Recompute inequality metrics with optional filtering.
    Returns summary of what was computed.
    """
    import time
    t0 = time.time()

    # Get indicators
    q = select(Indicator)
    if indicator_code:
        q = q.where(Indicator.code == indicator_code)
    ind_result = await db.execute(q)
    indicators = ind_result.scalars().all()

    if not indicators:
        return {"error": f"No indicators found matching '{indicator_code}'"}

    # Get countries
    if admin0:
        countries = [admin0]
    else:
        ctry_result = await db.execute(
            select(func.distinct(Region.admin0)).order_by(Region.admin0)
        )
        countries = [r[0] for r in ctry_result.all()]

    # Get year range
    year_result = await db.execute(
        select(func.distinct(Observation.year)).order_by(Observation.year)
    )
    all_years = [r[0] for r in year_result.all()]

    if year_from:
        all_years = [y for y in all_years if y >= year_from]
    if year_to:
        all_years = [y for y in all_years if y <= year_to]

    total_metrics = 0
    processed = []

    for ind in indicators:
        ind_metrics = 0
        for ctry in countries:
            n = await recompute_inequality_for_country(
                db, ctry, ind.id, ind.code, all_years
            )
            ind_metrics += n

        total_metrics += ind_metrics
        processed.append({
            "indicator": ind.code,
            "metrics_computed": ind_metrics,
        })
        logger.info(f"  {ind.code}: {ind_metrics} metrics")

    elapsed = time.time() - t0

    return {
        "total_metrics": total_metrics,
        "n_indicators": len(indicators),
        "n_countries": len(countries),
        "n_years": len(all_years),
        "elapsed_seconds": round(elapsed, 1),
        "indicators": processed,
    }
