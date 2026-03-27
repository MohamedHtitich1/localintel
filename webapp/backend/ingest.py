"""
Data ingestion pipeline: reads R panel data and geometries, loads into PostgreSQL.

Usage:
    python -m backend.ingest --panel ../tests/gapfill-results/dhs_panel_admin1_balanced.rds \
                              --geo ../tests/gapfill-results/gadm_combined_geo.rds

Or from within Docker:
    docker compose exec api python -m backend.ingest --panel /app/data/dhs_panel_admin1_balanced.rds \
                                                      --geo /app/data/gadm_combined_geo.rds
"""

import argparse
import sys
import time
import numpy as np
import pandas as pd
import pyreadr
from sqlalchemy import create_engine, text
from sqlalchemy.orm import Session

from backend.config import get_settings
from backend.models import Base, Region, Indicator, Observation, InequalityMetric


# ── Domain mapping (mirrors R/dhs_reference.R) ──────────────────────────────

DOMAIN_MAP = {
    "basic_vaccination": "Maternal & Child Health",
    "full_vaccination": "Maternal & Child Health",
    "anc_4plus": "Maternal & Child Health",
    "skilled_birth": "Maternal & Child Health",
    "postnatal_mother": "Maternal & Child Health",
    "postnatal_newborn": "Maternal & Child Health",
    "contraceptive_modern": "Maternal & Child Health",
    "contraceptive_any": "Maternal & Child Health",
    "unmet_need_fp": "Maternal & Child Health",
    "fever_treatment": "Maternal & Child Health",
    "diarrhea_ort": "Maternal & Child Health",
    "u5_mortality": "Mortality",
    "infant_mortality": "Mortality",
    "neonatal_mortality": "Mortality",
    "perinatal_mortality": "Mortality",
    "child_mortality": "Mortality",
    "stunting": "Nutrition",
    "wasting": "Nutrition",
    "underweight": "Nutrition",
    "overweight_child": "Nutrition",
    "anemia_children": "Nutrition",
    "anemia_women": "Nutrition",
    "exclusive_bf": "Nutrition",
    "early_bf": "Nutrition",
    "low_bmi_women": "Nutrition",
    "obesity_women": "Nutrition",
    "hiv_prevalence": "HIV/AIDS",
    "hiv_test_women": "HIV/AIDS",
    "hiv_test_men": "HIV/AIDS",
    "hiv_knowledge_women": "HIV/AIDS",
    "hiv_knowledge_men": "HIV/AIDS",
    "hiv_condom_women": "HIV/AIDS",
    "hiv_condom_men": "HIV/AIDS",
    "literacy_women": "Education",
    "literacy_men": "Education",
    "net_attendance_primary": "Education",
    "secondary_completion_women": "Education",
    "secondary_completion_men": "Education",
    "median_years_women": "Education",
    "median_years_men": "Education",
    "no_education_women": "Education",
    "no_education_men": "Education",
    "improved_water": "Water & Sanitation",
    "improved_sanitation": "Water & Sanitation",
    "piped_water": "Water & Sanitation",
    "surface_water": "Water & Sanitation",
    "open_defecation": "Water & Sanitation",
    "handwashing_facility": "Water & Sanitation",
    "wealth_lowest": "Wealth & Assets",
    "wealth_second": "Wealth & Assets",
    "wealth_middle": "Wealth & Assets",
    "wealth_fourth": "Wealth & Assets",
    "wealth_highest": "Wealth & Assets",
    "electricity": "Wealth & Assets",
    "mobile_phone": "Wealth & Assets",
    "bank_account": "Wealth & Assets",
    "women_earning": "Gender",
    "dv_physical": "Gender",
    "dv_sexual": "Gender",
    "dv_emotional": "Gender",
    "dv_attitude_women": "Gender",
    "dv_attitude_men": "Gender",
}

LABELS = {
    "basic_vaccination": "Basic vaccination coverage (%)",
    "full_vaccination": "Full vaccination (%)",
    "anc_4plus": "4+ antenatal care visits (%)",
    "skilled_birth": "Skilled birth attendance (%)",
    "postnatal_mother": "Postnatal checkup - mother (%)",
    "postnatal_newborn": "Postnatal checkup - newborn (%)",
    "contraceptive_modern": "Modern contraceptive use (%)",
    "contraceptive_any": "Any contraceptive use (%)",
    "unmet_need_fp": "Unmet need for family planning (%)",
    "fever_treatment": "Fever treatment - antimalarials (%)",
    "diarrhea_ort": "Diarrhea treated with ORT (%)",
    "u5_mortality": "Under-5 mortality rate (per 1,000)",
    "infant_mortality": "Infant mortality rate (per 1,000)",
    "neonatal_mortality": "Neonatal mortality rate (per 1,000)",
    "perinatal_mortality": "Perinatal mortality rate (per 1,000)",
    "child_mortality": "Child mortality rate (per 1,000)",
    "stunting": "Stunting prevalence (%)",
    "wasting": "Wasting prevalence (%)",
    "underweight": "Underweight prevalence (%)",
    "overweight_child": "Child overweight prevalence (%)",
    "anemia_children": "Child anemia prevalence (%)",
    "anemia_women": "Women with anemia (%)",
    "exclusive_bf": "Exclusive breastfeeding (%)",
    "early_bf": "Early breastfeeding initiation (%)",
    "low_bmi_women": "Women with low BMI (%)",
    "obesity_women": "Women overweight/obese (%)",
    "hiv_prevalence": "HIV prevalence (%)",
    "hiv_test_women": "Women ever tested for HIV (%)",
    "hiv_test_men": "Men ever tested for HIV (%)",
    "hiv_knowledge_women": "HIV knowledge - women (%)",
    "hiv_knowledge_men": "HIV knowledge - men (%)",
    "hiv_condom_women": "HIV condom knowledge - women (%)",
    "hiv_condom_men": "HIV condom knowledge - men (%)",
    "literacy_women": "Female literacy rate (%)",
    "literacy_men": "Male literacy rate (%)",
    "net_attendance_primary": "Net primary attendance (%)",
    "secondary_completion_women": "Female secondary completion (%)",
    "secondary_completion_men": "Male secondary completion (%)",
    "median_years_women": "Median years of education - women",
    "median_years_men": "Median years of education - men",
    "no_education_women": "Women with no education (%)",
    "no_education_men": "Men with no education (%)",
    "improved_water": "Improved water source (%)",
    "improved_sanitation": "Improved sanitation (%)",
    "piped_water": "Piped water (%)",
    "surface_water": "Surface water use (%)",
    "open_defecation": "Open defecation (%)",
    "handwashing_facility": "Basic handwashing facility (%)",
    "wealth_lowest": "Wealth quintile - lowest (%)",
    "wealth_second": "Wealth quintile - second (%)",
    "wealth_middle": "Wealth quintile - middle (%)",
    "wealth_fourth": "Wealth quintile - fourth (%)",
    "wealth_highest": "Wealth quintile - highest (%)",
    "electricity": "Electricity access (%)",
    "mobile_phone": "Mobile phone ownership (%)",
    "bank_account": "Women with bank account (%)",
    "women_earning": "Women deciding own earnings (%)",
    "dv_physical": "Physical violence prevalence (%)",
    "dv_sexual": "Sexual violence prevalence (%)",
    "dv_emotional": "Emotional violence by partner (%)",
    "dv_attitude_women": "Women justifying wife-beating (%)",
    "dv_attitude_men": "Men justifying wife-beating (%)",
}

MORTALITY_INDICATORS = {"u5_mortality", "infant_mortality", "neonatal_mortality",
                         "perinatal_mortality", "child_mortality"}
LOG_EXTRAS = {"median_years_women", "median_years_men"}

# Indicators where higher value = worse outcome
HIGHER_IS_WORSE = {
    "u5_mortality", "infant_mortality", "neonatal_mortality", "perinatal_mortality",
    "child_mortality", "stunting", "wasting", "underweight", "anemia_children",
    "anemia_women", "low_bmi_women", "hiv_prevalence", "unmet_need_fp",
    "no_education_women", "no_education_men", "surface_water", "open_defecation",
    "dv_physical", "dv_sexual", "dv_emotional", "dv_attitude_women", "dv_attitude_men",
    "wealth_lowest",
}

# ── Country name mapping ─────────────────────────────────────────────────────

COUNTRY_NAMES = {
    "AO": "Angola", "BJ": "Benin", "BF": "Burkina Faso", "BU": "Burundi",
    "CM": "Cameroon", "TD": "Chad", "KM": "Comoros", "CD": "DR Congo",
    "CI": "Cote d'Ivoire", "ET": "Ethiopia", "GA": "Gabon", "GM": "Gambia",
    "GH": "Ghana", "GN": "Guinea", "KE": "Kenya", "LS": "Lesotho",
    "LB": "Liberia", "MD": "Madagascar", "MW": "Malawi", "ML": "Mali",
    "MR": "Mauritania", "MZ": "Mozambique", "NM": "Namibia", "NI": "Niger",
    "NG": "Nigeria", "RW": "Rwanda", "SN": "Senegal", "SL": "Sierra Leone",
    "ZA": "South Africa", "SZ": "Eswatini", "TZ": "Tanzania", "TG": "Togo",
    "UG": "Uganda", "ZM": "Zambia", "ZW": "Zimbabwe",
}


def compute_gini(values: np.ndarray) -> float:
    """Compute Gini coefficient from an array of values."""
    if len(values) < 2:
        return None
    values = np.sort(values)
    n = len(values)
    indices = np.arange(1, n + 1)
    return float((2 * np.sum(indices * values) - (n + 1) * np.sum(values)) / (n * np.sum(values)))


def compute_theil(values: np.ndarray) -> float:
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


def compute_inequality_metrics(values: np.ndarray, geo_codes: list, higher_is_worse: bool):
    """Compute all inequality metrics for an array of region values."""
    clean = values[~np.isnan(values)]
    if len(clean) < 2:
        return None

    # For ranking best/worst: depends on indicator direction
    valid_mask = ~np.isnan(values)
    valid_vals = values[valid_mask]
    valid_geos = [g for g, m in zip(geo_codes, valid_mask) if m]

    if higher_is_worse:
        best_idx = np.argmin(valid_vals)
        worst_idx = np.argmax(valid_vals)
    else:
        best_idx = np.argmax(valid_vals)
        worst_idx = np.argmin(valid_vals)

    # Ensure all values positive for Gini/Theil (shift if needed)
    shifted = clean.copy()
    if np.any(shifted <= 0):
        shifted = shifted - shifted.min() + 0.01

    sorted_vals = np.sort(clean)
    n = len(clean)
    p10_idx = max(0, int(n * 0.1))
    p90_idx = min(n - 1, int(n * 0.9))

    p10 = sorted_vals[p10_idx]
    p90 = sorted_vals[p90_idx]

    q1 = np.percentile(clean, 25)
    q3 = np.percentile(clean, 75)

    return {
        "gini": compute_gini(shifted),
        "cv": float(np.std(clean) / np.mean(clean)) if np.mean(clean) != 0 else None,
        "theil": compute_theil(shifted),
        "ratio_max_min": float(np.max(clean) / np.min(clean)) if np.min(clean) > 0 else None,
        "ratio_p90_p10": float(p90 / p10) if p10 > 0 else None,
        "range_abs": float(np.max(clean) - np.min(clean)),
        "iqr": float(q3 - q1),
        "mean_value": float(np.mean(clean)),
        "median_value": float(np.median(clean)),
        "std_dev": float(np.std(clean)),
        "n_regions": int(n),
        "best_region": valid_geos[best_idx],
        "worst_region": valid_geos[worst_idx],
    }


def main():
    parser = argparse.ArgumentParser(description="Ingest localintel data into PostgreSQL")
    parser.add_argument("--panel", required=True, help="Path to dhs_panel_admin1_balanced.rds")
    parser.add_argument("--geo", default=None, help="Path to gadm_combined_geo.rds (optional)")
    parser.add_argument("--drop", action="store_true", help="Drop existing tables first")
    args = parser.parse_args()

    settings = get_settings()
    engine = create_engine(settings.database_url_sync, echo=False)

    if args.drop:
        print("Dropping existing tables...")
        with engine.connect() as conn:
            conn.execute(text("DROP SCHEMA public CASCADE"))
            conn.execute(text("CREATE SCHEMA public"))
            conn.execute(text("CREATE EXTENSION IF NOT EXISTS postgis"))
            conn.commit()

    print("Creating tables...")
    Base.metadata.create_all(engine)

    # ── Load panel ──────────────────────────────────────────────────────────
    print(f"Reading panel: {args.panel}")
    t0 = time.time()
    if args.panel.endswith(".csv") or args.panel.endswith(".csv.gz"):
        panel = pd.read_csv(args.panel)
    else:
        rds = pyreadr.read_r(args.panel)
        panel = list(rds.values())[0]
    print(f"  Panel shape: {panel.shape} ({time.time() - t0:.1f}s)")

    # Detect indicator columns via imp_*_flag pattern
    flag_cols = [c for c in panel.columns if c.startswith("imp_") and c.endswith("_flag")]
    indicator_codes = [c[4:-5] for c in flag_cols]
    print(f"  Found {len(indicator_codes)} indicators")

    # ── Load geometry (optional) ────────────────────────────────────────────
    geo_df = None
    if args.geo:
        try:
            import geopandas as gpd
            print(f"Reading geometries: {args.geo}")
            geo_rds = pyreadr.read_r(args.geo)
            geo_df = list(geo_rds.values())[0]
            print(f"  Geometry rows: {len(geo_df)}")
        except Exception as e:
            print(f"  Warning: Could not load geometry file: {e}")
            print("  Continuing without geometries...")

    with Session(engine) as session:
        # ── 1. Insert regions ───────────────────────────────────────────────
        print("\n1. Inserting regions...")
        regions = panel[["geo", "admin0"]].drop_duplicates().reset_index(drop=True)
        region_map = {}  # geo -> Region.id

        for _, row in regions.iterrows():
            geo = row["geo"]
            admin0 = row["admin0"]
            # Extract region name from geo code (format: "XX_RegionName")
            parts = geo.split("_", 1)
            name = parts[1] if len(parts) > 1 else geo
            country = COUNTRY_NAMES.get(admin0, admin0)

            rgn = Region(
                geo=geo, name=name, admin0=admin0, country_name=country,
            )
            session.add(rgn)
            session.flush()
            region_map[geo] = rgn.id

        session.commit()
        print(f"  Inserted {len(region_map)} regions")

        # ── 2. Insert indicators ────────────────────────────────────────────
        print("\n2. Inserting indicators...")
        indicator_map = {}  # code -> Indicator.id

        for code in indicator_codes:
            domain = DOMAIN_MAP.get(code, "Other")
            label = LABELS.get(code, code)
            transform = "log" if code in MORTALITY_INDICATORS or code in LOG_EXTRAS else "logit"
            higher_is = "worse" if code in HIGHER_IS_WORSE else "better"
            unit = "per 1,000" if code in MORTALITY_INDICATORS else (
                "years" if code in LOG_EXTRAS else "%"
            )

            # Count coverage
            if code in panel.columns:
                n_regions = int(panel[code].notna().sum() / panel["year"].nunique() * 1)
                n_countries = int(panel.loc[panel[code].notna(), "admin0"].nunique())
            else:
                n_regions = 0
                n_countries = 0

            ind = Indicator(
                code=code, label=label, domain=domain, unit=unit,
                transform=transform, higher_is=higher_is,
                coverage_regions=n_regions, coverage_countries=n_countries,
            )
            session.add(ind)
            session.flush()
            indicator_map[code] = ind.id

        session.commit()
        print(f"  Inserted {len(indicator_map)} indicators")

        # ── 3. Insert observations (bulk) ───────────────────────────────────
        print("\n3. Inserting observations...")
        t0 = time.time()
        batch = []
        batch_size = 10000
        total = 0

        for idx, code in enumerate(indicator_codes):
            if code not in panel.columns:
                continue

            flag_col = f"imp_{code}_flag"
            ci_lo_col = f"{code}_ci_lo"
            ci_hi_col = f"{code}_ci_hi"
            src_col = f"src_{code}_level"

            ind_id = indicator_map[code]

            for _, row in panel.iterrows():
                val = row.get(code)
                if pd.isna(val):
                    continue

                batch.append({
                    "region_id": region_map[row["geo"]],
                    "indicator_id": ind_id,
                    "year": int(row["year"]),
                    "value": float(val),
                    "ci_lo": float(row[ci_lo_col]) if ci_lo_col in panel.columns and pd.notna(row.get(ci_lo_col)) else None,
                    "ci_hi": float(row[ci_hi_col]) if ci_hi_col in panel.columns and pd.notna(row.get(ci_hi_col)) else None,
                    "imp_flag": int(row[flag_col]) if flag_col in panel.columns and pd.notna(row.get(flag_col)) else 0,
                    "src_level": int(row[src_col]) if src_col in panel.columns and pd.notna(row.get(src_col)) else None,
                })

                if len(batch) >= batch_size:
                    session.execute(Observation.__table__.insert(), batch)
                    total += len(batch)
                    batch = []

            if (idx + 1) % 10 == 0:
                elapsed = time.time() - t0
                print(f"  [{idx+1}/{len(indicator_codes)}] {code:30s} total={total:,} ({elapsed:.0f}s)")

        if batch:
            session.execute(Observation.__table__.insert(), batch)
            total += len(batch)

        session.commit()
        print(f"  Inserted {total:,} observations ({time.time() - t0:.0f}s)")

        # ── 4. Compute inequality metrics ───────────────────────────────────
        print("\n4. Computing inequality metrics...")
        t0 = time.time()
        n_metrics = 0

        years = sorted(panel["year"].unique())
        countries = sorted(panel["admin0"].unique())

        for code in indicator_codes:
            if code not in panel.columns:
                continue
            ind_id = indicator_map[code]
            is_worse = code in HIGHER_IS_WORSE

            for yr in years:
                for ctry in countries:
                    mask = (panel["admin0"] == ctry) & (panel["year"] == yr)
                    subset = panel.loc[mask]
                    vals = subset[code].dropna().values
                    geos = subset.loc[subset[code].notna(), "geo"].values.tolist()

                    if len(vals) < 2:
                        continue

                    metrics = compute_inequality_metrics(vals, geos, is_worse)
                    if metrics is None:
                        continue

                    session.add(InequalityMetric(
                        admin0=ctry, indicator_id=ind_id, year=int(yr),
                        **metrics,
                    ))
                    n_metrics += 1

            if n_metrics % 5000 == 0 and n_metrics > 0:
                session.commit()

        session.commit()
        print(f"  Computed {n_metrics:,} inequality metrics ({time.time() - t0:.0f}s)")

    print("\nIngestion complete!")


if __name__ == "__main__":
    main()
