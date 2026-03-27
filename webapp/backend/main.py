"""
LocalIntel — SSA Inequality Mapping Engine
FastAPI application entry point.

API groups:
  /api/indicators   — Indicator data, choropleth, time series
  /api/regions      — Region geometries and metadata
  /api/inequality   — Pre-computed inequality metrics
  /api/insights     — Live narrative insight generation
  /api/reports      — Structured reports and CSV exports
  /api/admin        — Pipeline orchestration and refresh
"""

import logging
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from contextlib import asynccontextmanager

from backend.config import get_settings
from backend.database import engine, Base
from backend.api.indicators import router as indicators_router
from backend.api.regions import router as regions_router
from backend.api.inequality import router as inequality_router
from backend.api.insights import router as insights_router
from backend.api.reports import router as reports_router
from backend.api.admin import router as admin_router

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(name)s] %(message)s")

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Create tables on startup
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    await engine.dispose()


app = FastAPI(
    title=settings.app_title,
    version="0.4.0",
    lifespan=lifespan,
    docs_url="/api/docs",
    redoc_url="/api/redoc",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:8090",
        "http://127.0.0.1:8090",
        "http://localhost:8001",
        "https://api.dockermhtitich.com",
        "https://mhtitich.com",
        "https://www.mhtitich.com",
    ],
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)

# ── API routes ───────────────────────────────────────────────────────────────

# Core data
app.include_router(indicators_router, prefix="/api")
app.include_router(regions_router, prefix="/api")
app.include_router(inequality_router, prefix="/api")

# Automation & insights
app.include_router(insights_router, prefix="/api")
app.include_router(reports_router, prefix="/api")
app.include_router(admin_router, prefix="/api")


@app.get("/api/health")
async def health():
    return {"status": "ok", "version": "0.4.0"}


@app.get("/api/endpoints")
async def list_endpoints():
    """List all available API endpoints for discoverability."""
    routes = []
    for route in app.routes:
        if hasattr(route, "methods") and hasattr(route, "path"):
            if route.path.startswith("/api"):
                routes.append({
                    "path": route.path,
                    "methods": sorted(route.methods - {"HEAD", "OPTIONS"}),
                    "name": route.name,
                })
    routes.sort(key=lambda r: r["path"])
    return {"endpoints": routes, "total": len(routes)}


# Serve frontend
app.mount("/assets", StaticFiles(directory="frontend/assets", check_dir=False), name="assets")


@app.get("/")
async def serve_frontend():
    return FileResponse("frontend/localintel-platform.html")


@app.get("/legacy")
async def serve_legacy_frontend():
    """Serve the older generated dashboard (index.html)."""
    return FileResponse("frontend/index.html")
