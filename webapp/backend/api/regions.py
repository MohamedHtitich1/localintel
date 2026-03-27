"""
API routes for region geometries and metadata.
Serves GeoJSON for the SVG choropleth renderer.
"""

from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, text
from typing import Optional

from backend.database import get_db
from backend.models import Region, Observation

router = APIRouter(tags=["regions"])


@router.get("/regions")
async def list_regions(
    admin0: Optional[str] = None,
    db: AsyncSession = Depends(get_db),
):
    """List all regions with metadata (no geometry for speed)."""
    q = select(
        Region.geo, Region.name, Region.admin0, Region.country_name,
        Region.centroid_lon, Region.centroid_lat,
    )
    if admin0:
        q = q.where(Region.admin0 == admin0)
    q = q.order_by(Region.admin0, Region.name)
    result = await db.execute(q)
    return [
        {
            "geo": r.geo, "name": r.name, "admin0": r.admin0,
            "country": r.country_name,
            "centroid": [r.centroid_lon, r.centroid_lat] if r.centroid_lon else None,
        }
        for r in result.all()
    ]


@router.get("/regions/geojson")
async def get_geojson(
    admin0: Optional[str] = None,
    simplify: float = Query(0.01, ge=0, le=0.1, description="Geometry simplification tolerance"),
    db: AsyncSession = Depends(get_db),
):
    """
    Get all regions as GeoJSON FeatureCollection.
    Uses ST_SimplifyPreserveTopology for efficient transfer.
    """
    simplify_expr = f"ST_AsGeoJSON(ST_SimplifyPreserveTopology(geom, {simplify}))" if simplify > 0 else "ST_AsGeoJSON(geom)"

    admin0_filter = "AND admin0 = :admin0" if admin0 else ""

    sql = text(f"""
        SELECT geo, name, admin0, country_name,
               {simplify_expr} as geojson
        FROM regions
        WHERE geom IS NOT NULL {admin0_filter}
        ORDER BY admin0, name
    """)
    params = {"admin0": admin0} if admin0 else {}
    result = await db.execute(sql, params)
    rows = result.all()

    features = []
    for r in rows:
        if r.geojson:
            import json
            features.append({
                "type": "Feature",
                "id": r.geo,
                "properties": {
                    "geo": r.geo,
                    "name": r.name,
                    "admin0": r.admin0,
                    "country": r.country_name,
                },
                "geometry": json.loads(r.geojson),
            })

    return {
        "type": "FeatureCollection",
        "features": features,
    }


@router.get("/regions/countries")
async def list_countries(db: AsyncSession = Depends(get_db)):
    """List all countries with region counts."""
    result = await db.execute(
        select(
            Region.admin0,
            Region.country_name,
            func.count(Region.id).label("n_regions"),
        )
        .group_by(Region.admin0, Region.country_name)
        .order_by(Region.country_name)
    )
    return [
        {"admin0": r.admin0, "country": r.country_name, "n_regions": r.n_regions}
        for r in result.all()
    ]


@router.get("/regions/{geo}/profile")
async def region_profile(
    geo: str,
    year: int = Query(2024, ge=1985, le=2024),
    db: AsyncSession = Depends(get_db),
):
    """
    Get full indicator profile for a region in a given year.
    Returns all available indicator values.
    """
    rgn = await db.execute(select(Region).where(Region.geo == geo))
    region = rgn.scalar_one_or_none()
    if not region:
        raise HTTPException(404, f"Region '{geo}' not found")

    result = await db.execute(
        text("""
            SELECT i.code, i.label, i.domain, i.unit, i.higher_is,
                   o.value, o.ci_lo, o.ci_hi, o.imp_flag
            FROM observations o
            JOIN indicators i ON o.indicator_id = i.id
            WHERE o.region_id = :rid AND o.year = :year AND o.value IS NOT NULL
            ORDER BY i.domain, i.code
        """),
        {"rid": region.id, "year": year},
    )
    rows = result.all()

    return {
        "geo": geo,
        "name": region.name,
        "country": region.country_name,
        "year": year,
        "indicators": [
            {
                "code": r.code, "label": r.label, "domain": r.domain,
                "unit": r.unit, "higher_is": r.higher_is,
                "value": round(r.value, 3), "ci_lo": round(r.ci_lo, 3) if r.ci_lo else None,
                "ci_hi": round(r.ci_hi, 3) if r.ci_hi else None,
                "flag": r.imp_flag,
            }
            for r in rows
        ],
    }
