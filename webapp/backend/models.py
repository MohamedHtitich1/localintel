"""
SQLAlchemy models for the LocalIntel inequality mapping engine.

Schema design:
- regions: Admin 1 geometries with country metadata
- indicators: Indicator registry with domain, label, transform info
- observations: The big table — region x indicator x year values
- inequality_metrics: Pre-computed country-level inequality measures per year
"""

from sqlalchemy import (
    Column, Integer, Float, String, Text, SmallInteger,
    ForeignKey, UniqueConstraint, Index, CheckConstraint
)
from sqlalchemy.orm import relationship
from geoalchemy2 import Geometry
from backend.database import Base


class Region(Base):
    __tablename__ = "regions"

    id = Column(Integer, primary_key=True)
    geo = Column(String(120), unique=True, nullable=False, index=True)
    name = Column(String(200), nullable=False)
    admin0 = Column(String(3), nullable=False, index=True)  # ISO3
    country_name = Column(String(100), nullable=False)
    geom = Column(Geometry("MULTIPOLYGON", srid=4326), nullable=True)
    centroid_lon = Column(Float)
    centroid_lat = Column(Float)

    observations = relationship("Observation", back_populates="region")


class Indicator(Base):
    __tablename__ = "indicators"

    id = Column(Integer, primary_key=True)
    code = Column(String(80), unique=True, nullable=False, index=True)
    label = Column(String(200), nullable=False)
    domain = Column(String(60), nullable=False, index=True)
    unit = Column(String(40), default="%")
    transform = Column(String(10), default="logit")  # "log" or "logit"
    higher_is = Column(String(10), default="better")  # "better" or "worse"
    coverage_regions = Column(Integer, default=0)  # how many regions have data
    coverage_countries = Column(Integer, default=0)

    observations = relationship("Observation", back_populates="indicator")


class Observation(Base):
    """Core data table: ~652 regions x 62 indicators x ~39 years = ~1.5M rows."""
    __tablename__ = "observations"

    id = Column(Integer, primary_key=True)
    region_id = Column(Integer, ForeignKey("regions.id"), nullable=False)
    indicator_id = Column(Integer, ForeignKey("indicators.id"), nullable=False)
    year = Column(SmallInteger, nullable=False)
    value = Column(Float)
    ci_lo = Column(Float)
    ci_hi = Column(Float)
    imp_flag = Column(SmallInteger, default=0)  # 0=observed, 1=interpolated, 2=forecasted
    src_level = Column(SmallInteger)

    region = relationship("Region", back_populates="observations")
    indicator = relationship("Indicator", back_populates="observations")

    __table_args__ = (
        UniqueConstraint("region_id", "indicator_id", "year", name="uq_obs_region_ind_year"),
        Index("ix_obs_indicator_year", "indicator_id", "year"),
        Index("ix_obs_region_indicator", "region_id", "indicator_id"),
    )


class InequalityMetric(Base):
    """Pre-computed inequality metrics per country x indicator x year."""
    __tablename__ = "inequality_metrics"

    id = Column(Integer, primary_key=True)
    admin0 = Column(String(3), nullable=False, index=True)
    indicator_id = Column(Integer, ForeignKey("indicators.id"), nullable=False)
    year = Column(SmallInteger, nullable=False)

    # Core inequality measures
    gini = Column(Float)                  # Gini coefficient (0-1)
    cv = Column(Float)                    # Coefficient of variation
    theil = Column(Float)                 # Theil index (GE(1))
    ratio_max_min = Column(Float)         # Max / Min ratio
    ratio_p90_p10 = Column(Float)         # 90th / 10th percentile ratio
    range_abs = Column(Float)             # Max - Min absolute range
    iqr = Column(Float)                   # Interquartile range
    mean_value = Column(Float)            # Country mean
    median_value = Column(Float)          # Country median
    std_dev = Column(Float)               # Standard deviation
    n_regions = Column(SmallInteger)      # Number of regions with data
    best_region = Column(String(120))     # Region geo code with best value
    worst_region = Column(String(120))    # Region geo code with worst value

    indicator = relationship("Indicator")

    __table_args__ = (
        UniqueConstraint("admin0", "indicator_id", "year", name="uq_ineq_country_ind_year"),
        Index("ix_ineq_indicator_year", "indicator_id", "year"),
    )
