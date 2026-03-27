"""
Generate a self-contained HTML dashboard with embedded data.
Picks the best-coverage indicator per domain, embeds GeoJSON + values inline.

Usage (from within Docker):
    docker compose exec api python /app/scripts/generate_dashboard.py
"""

import json
import math
import os
import sys
import numpy as np
import pandas as pd


# ── Africa Albers Equal Area Conic projection ────────────────────────────────
# ESRI:102022-style parameters tuned for Sub-Saharan Africa
_AEA_LON0 = math.radians(25.0)   # central meridian
_AEA_LAT0 = math.radians(-5.0)   # latitude of origin
_AEA_PHI1 = math.radians(-20.0)  # standard parallel 1
_AEA_PHI2 = math.radians(5.0)    # standard parallel 2
_n = (math.sin(_AEA_PHI1) + math.sin(_AEA_PHI2)) / 2
_C = math.cos(_AEA_PHI1) ** 2 + 2 * _n * math.sin(_AEA_PHI1)
_rho0 = math.sqrt(_C - 2 * _n * math.sin(_AEA_LAT0)) / _n
_SCALE = 0.00009  # scale factor to get reasonable SVG coords


def _albers(lon_deg, lat_deg):
    """Project lon/lat (degrees) to Albers Equal Area x/y (SVG coords)."""
    lon = math.radians(lon_deg)
    lat = math.radians(lat_deg)
    theta = _n * (lon - _AEA_LON0)
    rho = math.sqrt(_C - 2 * _n * math.sin(lat)) / _n
    x = rho * math.sin(theta) / _SCALE
    y = -(rho0 - rho * math.cos(theta)) / _SCALE  # negate for SVG Y-down
    return round(x, 1), round(y, 1)

DATA_DIR = "/app/data"
OUT_DIR = "/app/frontend"

# ── Flagship indicators per domain (best coverage) ──────────────────────────
FLAGSHIPS = {
    "Maternal & Child Health": {
        "code": "anc_4plus", "label": "4+ Antenatal Care Visits", "unit": "%",
        "higher_is": "better",
    },
    "Mortality": {
        "code": "u5_mortality", "label": "Under-5 Mortality Rate", "unit": "per 1,000",
        "higher_is": "worse",
    },
    "Nutrition": {
        "code": "stunting", "label": "Stunting Prevalence", "unit": "%",
        "higher_is": "worse",
    },
    "Education": {
        "code": "literacy_women", "label": "Female Literacy Rate", "unit": "%",
        "higher_is": "better",
    },
    "Water & Sanitation": {
        "code": "improved_water", "label": "Improved Water Source", "unit": "%",
        "higher_is": "better",
    },
    "Wealth & Assets": {
        "code": "electricity", "label": "Electricity Access", "unit": "%",
        "higher_is": "better",
    },
    "HIV/AIDS": {
        "code": "hiv_test_women", "label": "Women Ever Tested for HIV", "unit": "%",
        "higher_is": "better",
    },
    "Gender": {
        "code": "dv_attitude_women", "label": "Women Justifying Wife-Beating", "unit": "%",
        "higher_is": "worse",
    },
}

COUNTRY_NAMES = {
    "AO": "Angola", "BJ": "Benin", "BF": "Burkina Faso", "BU": "Burundi",
    "CM": "Cameroon", "TD": "Chad", "KM": "Comoros", "CD": "DR Congo",
    "CG": "Congo", "CI": "Cote d'Ivoire", "ER": "Eritrea", "ET": "Ethiopia",
    "GA": "Gabon", "GM": "Gambia", "GH": "Ghana", "GN": "Guinea",
    "KE": "Kenya", "LS": "Lesotho", "LB": "Liberia", "MD": "Madagascar",
    "MW": "Malawi", "ML": "Mali", "MR": "Mauritania", "MZ": "Mozambique",
    "NM": "Namibia", "NI": "Niger", "NG": "Nigeria", "RW": "Rwanda",
    "SN": "Senegal", "SL": "Sierra Leone", "ZA": "South Africa",
    "SZ": "Eswatini", "TZ": "Tanzania", "TG": "Togo", "UG": "Uganda",
    "ZM": "Zambia", "ZW": "Zimbabwe",
}


def compute_gini(values):
    v = np.sort(values[~np.isnan(values)])
    n = len(v)
    if n < 2 or np.sum(v) == 0:
        return None
    idx = np.arange(1, n + 1)
    return float((2 * np.sum(idx * v) - (n + 1) * np.sum(v)) / (n * np.sum(v)))


def main():
    print("Loading panel...")
    panel = pd.read_csv(os.path.join(DATA_DIR, "panel.csv.gz"))
    panel["geo"] = panel["geo"].str.strip()
    print(f"  {panel.shape[0]} rows, {panel.shape[1]} cols")

    print("Loading geometries...")
    with open(os.path.join(DATA_DIR, "ssa_admin1_web.geojson")) as f:
        geojson = json.load(f)
    print(f"  {len(geojson['features'])} features")

    # Build SVG paths from GeoJSON
    print("Building SVG paths...")
    geo_paths = {}  # geo_code -> list of SVG path strings
    geo_meta = {}   # geo_code -> {name, admin0, country}
    for feat in geojson["features"]:
        p = feat["properties"]
        geo = p.get("geo", f'{p["admin0"]}_{p["name"]}')
        name = p.get("name", p.get("admin1_name", ""))
        admin0 = p["admin0"]

        paths = []
        geom = feat["geometry"]
        rings = []
        if geom["type"] == "MultiPolygon":
            for poly in geom["coordinates"]:
                for ring in poly:
                    rings.append(ring)
        elif geom["type"] == "Polygon":
            rings = geom["coordinates"]

        for ring in rings:
            if len(ring) < 3:
                continue
            d = ""
            for i, c in enumerate(ring):
                x, y = _albers(c[0], c[1])
                d += ("M" if i == 0 else "L") + f"{x},{y}"
            d += "Z"
            paths.append(d)

        if paths:
            geo_paths[geo] = paths
            geo_meta[geo] = {
                "name": name,
                "admin0": admin0,
                "country": COUNTRY_NAMES.get(admin0, admin0),
            }

    print(f"  {len(geo_paths)} regions with paths")

    # Build data object per indicator per year
    print("Building indicator data...")
    years = sorted(panel["year"].unique())
    # Use a reasonable year range
    year_range = [y for y in years if 1990 <= y <= 2024]

    D = {
        "years": year_range,
        "variables": [],
        "varMeta": {},
        "paths": geo_paths,
        "regionMeta": geo_meta,
        "values": {},  # var -> year -> geo -> {v, flag}
    }

    for domain, info in FLAGSHIPS.items():
        code = info["code"]
        if code not in panel.columns:
            print(f"  SKIP {code} (not in panel)")
            continue

        D["variables"].append(code)
        D["varMeta"][code] = {
            "label": info["label"],
            "unit": info["unit"],
            "domain": domain,
            "higher_is": info["higher_is"],
        }

        flag_col = f"imp_{code}_flag"
        D["values"][code] = {}
        n_fallback_total = 0

        for yr in year_range:
            subset = panel[panel["year"] == yr]
            yr_data = {}
            for _, row in subset.iterrows():
                geo = row["geo"]
                val = row[code]
                if pd.notna(val):
                    flag = int(row[flag_col]) if flag_col in panel.columns and pd.notna(row.get(flag_col)) else 0
                    yr_data[geo] = {"v": round(float(val), 1), "f": flag}

            # --- National fallback: fill missing regions with country average ---
            # Build country averages from regions that have admin1 data
            country_vals = {}
            for geo, d in yr_data.items():
                cc = geo.split("_")[0] if "_" in geo else geo[:2]
                if cc not in country_vals:
                    country_vals[cc] = []
                country_vals[cc].append(d["v"])

            country_avg = {cc: round(float(np.mean(vals)), 1)
                           for cc, vals in country_vals.items() if len(vals) > 0}

            # Fill regions with no data using their country's average
            n_fallback = 0
            for geo, meta in geo_meta.items():
                if geo not in yr_data:
                    cc = meta.get("admin0", geo.split("_")[0] if "_" in geo else geo[:2])
                    if cc in country_avg:
                        yr_data[geo] = {"v": country_avg[cc], "f": 3}
                        n_fallback += 1

            n_fallback_total += n_fallback
            D["values"][code][str(yr)] = yr_data

        # Count coverage at 2020
        n2020 = len(D["values"][code].get("2020", {}))
        print(f"  {code:25s} {n2020:4d} regions (2020), {n_fallback_total} national fallback cells")

    # Compute inequality metrics per country for latest year
    print("Computing inequality metrics...")
    ineq = {}  # var -> [{admin0, country, gini, mean, best, worst, n}]
    for code in D["variables"]:
        yr_data = D["values"][code].get("2020", {})
        meta = D["varMeta"][code]
        is_worse = meta["higher_is"] == "worse"

        by_country = {}
        for geo, d in yr_data.items():
            m = geo_meta.get(geo, {})
            admin0 = m.get("admin0", geo[:2])
            if admin0 not in by_country:
                by_country[admin0] = []
            by_country[admin0].append((geo, d["v"], m.get("name", geo)))

        country_ineq = []
        for admin0, entries in sorted(by_country.items()):
            vals = np.array([e[1] for e in entries])
            shifted = vals.copy()
            if np.any(shifted <= 0):
                shifted = shifted - shifted.min() + 0.01
            gini = compute_gini(shifted)
            if gini is None:
                continue

            if is_worse:
                best = min(entries, key=lambda x: x[1])
                worst = max(entries, key=lambda x: x[1])
            else:
                best = max(entries, key=lambda x: x[1])
                worst = min(entries, key=lambda x: x[1])

            country_ineq.append({
                "a": admin0,
                "c": COUNTRY_NAMES.get(admin0, admin0),
                "g": round(gini, 4),
                "m": round(float(np.mean(vals)), 1),
                "b": best[2],  # best region name
                "w": worst[2],  # worst region name
                "n": len(entries),
            })

        country_ineq.sort(key=lambda x: x["g"], reverse=True)
        ineq[code] = country_ineq

    D["inequality"] = ineq

    # Serialize (handle numpy types)
    print("Serializing data...")

    class NpEncoder(json.JSONEncoder):
        def default(self, obj):
            if isinstance(obj, np.integer):
                return int(obj)
            if isinstance(obj, np.floating):
                return None if np.isnan(obj) else round(float(obj), 4)
            if isinstance(obj, np.ndarray):
                return obj.tolist()
            return super().default(obj)

    data_json = json.dumps(D, separators=(",", ":"), cls=NpEncoder)
    print(f"  Data size: {len(data_json) / 1024 / 1024:.1f} MB")

    # Generate HTML
    print("Generating HTML...")
    html = generate_html(data_json)

    out_path = os.path.join(OUT_DIR, "index.html")
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(html)
    print(f"  Written to {out_path} ({len(html) / 1024 / 1024:.1f} MB)")
    print("Done!")


def generate_html(data_json):
    return f'''<!DOCTYPE html>
<html lang="en" data-theme="dark">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>LocalIntel — SSA Inequality Mapping Engine</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=EB+Garamond:ital,wght@0,400;0,500;0,600;0,700;1,400&family=IBM+Plex+Sans:wght@300;400;500;600&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
<style>
:root {{
  --font-serif: 'EB Garamond', Georgia, serif;
  --font-sans: 'IBM Plex Sans', -apple-system, BlinkMacSystemFont, sans-serif;
  --font-mono: 'JetBrains Mono', 'SF Mono', monospace;
}}
[data-theme="dark"] {{
  --bg: #050507; --bg-card: rgba(20,22,25,0.5); --bg-card-hover: rgba(30,32,35,0.6);
  --bg-map: rgba(20,24,22,0.85); --text: #f5f5f7; --text2: #a8a8ad; --text3: #6e6e73;
  --accent: #5a8a6d; --accent-hover: #6b9b7e; --accent-dim: rgba(90,138,109,0.15);
  --border: rgba(255,255,255,0.08); --border-hover: rgba(255,255,255,0.14);
  --glow: rgba(90,138,109,0.08); --danger: #c54b4b; --warn: #c49a3c;
  --aurora1: rgba(90,138,109,0.06); --aurora2: rgba(80,120,160,0.04); --aurora3: rgba(140,100,160,0.03);
}}
[data-theme="light"] {{
  --bg: #f0f4f2; --bg-card: rgba(255,255,255,0.4); --bg-card-hover: rgba(255,255,255,0.55);
  --bg-map: rgba(245,248,246,0.9); --text: #1a1d1c; --text2: #4a4d4c; --text3: #7a7d7c;
  --accent: #5a8a6d; --accent-hover: #4a7a5d; --accent-dim: rgba(90,138,109,0.1);
  --border: rgba(0,0,0,0.08); --border-hover: rgba(0,0,0,0.14);
  --glow: rgba(90,138,109,0.06); --danger: #b33a3a; --warn: #a88030;
  --aurora1: rgba(90,138,109,0.04); --aurora2: rgba(80,120,160,0.03); --aurora3: rgba(140,100,160,0.02);
}}
*,*::before,*::after {{ box-sizing:border-box; margin:0; padding:0; }}
html {{ scroll-behavior:smooth; -webkit-font-smoothing:antialiased; }}
body {{ font-family:var(--font-sans); background:var(--bg); color:var(--text); min-height:100vh; overflow-x:hidden; transition:background .4s,color .4s; }}

.aurora {{ position:fixed; inset:0; z-index:0; pointer-events:none; overflow:hidden; }}
.aurora-band {{ position:absolute; border-radius:50%; filter:blur(120px); opacity:.6; animation:drift 25s ease-in-out infinite alternate; }}
.aurora-band:nth-child(1) {{ width:60vw; height:40vh; top:-10%; left:10%; background:radial-gradient(ellipse,var(--aurora1),transparent 70%); }}
.aurora-band:nth-child(2) {{ width:50vw; height:35vh; top:30%; right:-5%; background:radial-gradient(ellipse,var(--aurora2),transparent 70%); animation-delay:-8s; animation-duration:34s; }}
.aurora-band:nth-child(3) {{ width:45vw; height:30vh; bottom:-5%; left:25%; background:radial-gradient(ellipse,var(--aurora3),transparent 70%); animation-delay:-13s; animation-duration:42s; }}
@keyframes drift {{ 0%{{transform:translate(0,0) scale(1)}} 50%{{transform:translate(3vw,-2vh) scale(1.05)}} 100%{{transform:translate(-2vw,1vh) scale(.97)}} }}

.glass {{ background:var(--bg-card); border:1px solid var(--border); border-radius:16px; backdrop-filter:blur(24px) saturate(1.5); -webkit-backdrop-filter:blur(24px) saturate(1.5); box-shadow:inset 0 1px 0 rgba(255,255,255,.06),0 8px 32px rgba(0,0,0,.12); transition:border-color .2s,box-shadow .2s; }}
.glass:hover {{ border-color:var(--border-hover); box-shadow:inset 0 1px 0 rgba(255,255,255,.08),0 12px 40px rgba(0,0,0,.16),0 0 40px var(--glow); }}

.container {{ position:relative; z-index:1; max-width:1100px; margin:0 auto; padding:20px; animation:fadeIn .55s ease; }}
@keyframes fadeIn {{ from{{opacity:0}} to{{opacity:1}} }}

/* Header */
.header {{ display:flex; align-items:center; justify-content:space-between; padding:18px 24px; margin-bottom:20px; }}
.header h1 {{ font-family:var(--font-serif); font-size:1.6rem; font-weight:600; letter-spacing:-.02em; }}
.header h1 span {{ color:var(--accent); }}
.header-sub {{ font-size:.78rem; color:var(--text3); margin-top:2px; }}
.header-right {{ display:flex; gap:10px; align-items:center; }}
.theme-toggle {{ width:36px; height:36px; border-radius:50%; border:1px solid var(--border); background:var(--bg-card); color:var(--text2); cursor:pointer; display:flex; align-items:center; justify-content:center; font-size:1rem; transition:all .2s; }}
.theme-toggle:hover {{ border-color:var(--accent); color:var(--accent); }}

/* Stats banner */
.stats {{ display:grid; grid-template-columns:repeat(4,1fr); gap:14px; margin-bottom:20px; }}
.stat {{ padding:14px 16px; text-align:center; }}
.stat-v {{ font-family:var(--font-mono); font-size:1.4rem; font-weight:500; color:var(--accent); }}
.stat-l {{ font-size:.72rem; color:var(--text3); margin-top:3px; text-transform:uppercase; letter-spacing:.06em; }}

/* Variable selector */
.var-selector {{ padding:14px 20px; margin-bottom:20px; display:flex; flex-wrap:wrap; gap:6px; align-items:center; }}
.var-selector .label {{ font-family:var(--font-serif); font-size:.95rem; color:var(--text2); margin-right:8px; }}
.var-btn {{ padding:6px 14px; border:1px solid var(--border); background:transparent; color:var(--text3); font-family:var(--font-sans); font-size:.75rem; cursor:pointer; border-radius:20px; transition:all .15s; white-space:nowrap; }}
.var-btn:hover {{ border-color:var(--accent); color:var(--text); }}
.var-btn.active {{ background:var(--accent-dim); border-color:var(--accent); color:var(--accent); font-weight:500; }}

/* Map block */
.map-block {{ padding:0; margin-bottom:20px; overflow:hidden; }}
.map-header {{ padding:16px 20px 10px; display:flex; justify-content:space-between; align-items:center; }}
.map-title {{ font-family:var(--font-serif); font-size:1.15rem; font-weight:500; }}
.map-sub {{ font-size:.75rem; color:var(--text3); margin-top:2px; }}
.timeline {{ padding:0 20px 14px; display:flex; align-items:center; gap:10px; }}
.play-btn {{ width:30px; height:30px; border-radius:50%; border:1px solid var(--border); background:var(--bg-card); color:var(--text2); cursor:pointer; display:flex; align-items:center; justify-content:center; font-size:.8rem; transition:all .2s; }}
.play-btn:hover,.play-btn.on {{ border-color:var(--accent); color:var(--accent); }}
.slider {{ flex:1; -webkit-appearance:none; height:3px; border-radius:2px; background:var(--border); outline:none; }}
.slider::-webkit-slider-thumb {{ -webkit-appearance:none; width:14px; height:14px; border-radius:50%; background:var(--accent); cursor:pointer; border:2px solid var(--bg); }}
.yr {{ font-family:var(--font-mono); font-size:.82rem; color:var(--accent); min-width:36px; text-align:right; }}
.spd {{ font-family:var(--font-mono); font-size:.68rem; color:var(--text3); cursor:pointer; padding:2px 5px; border-radius:4px; border:1px solid var(--border); background:transparent; }}
.spd:hover {{ border-color:var(--accent); color:var(--accent); }}

.map-area {{ width:100%; background:var(--bg-map); border-radius:0 0 16px 16px; overflow:hidden; position:relative; }}
#map {{ width:100%; display:block; }}
#map path {{ stroke:var(--bg); stroke-width:.25; cursor:pointer; transition:fill .12s; }}
#map path:hover {{ stroke-width:.8; stroke:var(--accent); filter:brightness(1.15); }}
#map path.sel {{ stroke-width:1.2; stroke:var(--accent); }}
.legend {{ position:absolute; bottom:12px; left:16px; display:flex; align-items:center; gap:5px; padding:6px 12px; border-radius:8px; background:var(--bg-card); backdrop-filter:blur(12px); border:1px solid var(--border); }}
.legend canvas {{ border-radius:3px; }}
.leg-l {{ font-family:var(--font-mono); font-size:.68rem; color:var(--text3); }}

/* Region detail block */
.detail-block {{ padding:18px 22px; margin-bottom:20px; min-height:80px; }}
.detail-block h3 {{ font-family:var(--font-serif); font-size:1.1rem; margin-bottom:3px; }}
.detail-country {{ font-size:.75rem; color:var(--text3); margin-bottom:12px; }}
.detail-row {{ display:flex; justify-content:space-between; align-items:baseline; padding:5px 0; border-bottom:1px solid var(--border); }}
.detail-row:last-child {{ border-bottom:none; }}
.detail-label {{ font-size:.75rem; color:var(--text2); }}
.detail-val {{ font-family:var(--font-mono); font-size:.82rem; font-weight:500; }}
.empty {{ display:flex; align-items:center; justify-content:center; padding:20px; color:var(--text3); font-size:.82rem; }}

/* Sparkline */
.spark {{ margin-top:12px; padding-top:12px; border-top:1px solid var(--border); }}
.spark-label {{ font-size:.68rem; color:var(--text3); text-transform:uppercase; letter-spacing:.06em; margin-bottom:4px; }}
.spark svg {{ width:100%; height:55px; }}
.spark .line {{ fill:none; stroke:var(--accent); stroke-width:1.5; }}
.spark .area {{ fill:var(--accent-dim); }}
.spark .d0 {{ fill:var(--accent); }}
.spark .d1 {{ fill:var(--text3); }}
.spark .d2 {{ fill:var(--warn); }}
.spark-legend {{ display:flex; gap:10px; margin-top:3px; }}
.spark-legend span {{ font-size:.62rem; }}

/* Inequality block */
.ineq-block {{ padding:18px 22px; margin-bottom:20px; }}
.ineq-block h3 {{ font-family:var(--font-serif); font-size:1.1rem; margin-bottom:10px; color:var(--text2); }}
.ineq-sub {{ font-size:.68rem; color:var(--text3); text-transform:uppercase; letter-spacing:.06em; margin-bottom:10px; }}
.bar-row {{ display:flex; align-items:center; gap:7px; margin-bottom:3px; }}
.bar-code {{ font-family:var(--font-mono); font-size:.7rem; color:var(--text3); width:24px; text-align:right; }}
.bar-track {{ flex:1; height:5px; background:var(--border); border-radius:3px; overflow:hidden; }}
.bar-fill {{ height:100%; border-radius:3px; transition:width .4s ease; }}
.bar-val {{ font-family:var(--font-mono); font-size:.68rem; color:var(--text3); width:38px; }}
.bar-fill.high {{ background:var(--danger); }}
.bar-fill.med {{ background:var(--warn); }}
.bar-fill.low {{ background:var(--accent); }}

/* Insights */
.insights-block {{ padding:18px 22px; margin-bottom:20px; }}
.insights-block h3 {{ font-family:var(--font-serif); font-size:1.1rem; margin-bottom:10px; color:var(--text2); }}
.insight {{ padding:10px 12px; margin-bottom:6px; border-radius:10px; background:rgba(90,138,109,.06); border:1px solid rgba(90,138,109,.1); font-size:.78rem; color:var(--text2); line-height:1.45; }}
.insight .tag {{ font-family:var(--font-mono); font-size:.65rem; color:var(--accent); text-transform:uppercase; letter-spacing:.08em; margin-bottom:4px; }}

/* Responsive */
@media(max-width:700px) {{
  .stats {{ grid-template-columns:repeat(2,1fr); }}
  .var-selector {{ gap:4px; }}
  .var-btn {{ font-size:.7rem; padding:5px 10px; }}
}}
::-webkit-scrollbar {{ width:5px; }}
::-webkit-scrollbar-track {{ background:transparent; }}
::-webkit-scrollbar-thumb {{ background:var(--border); border-radius:3px; }}
</style>
</head>
<body>
<div class="aurora"><div class="aurora-band"></div><div class="aurora-band"></div><div class="aurora-band"></div></div>
<div class="container">

<!-- Header -->
<header class="header glass">
  <div>
    <h1>Local<span>Intel</span></h1>
    <div class="header-sub">Sub-Saharan Africa Inequality Mapping Engine</div>
  </div>
  <div class="header-right">
    <button class="theme-toggle" onclick="toggleTheme()" aria-label="Toggle theme"><span id="ti">&#9790;</span></button>
  </div>
</header>

<!-- Stats -->
<div class="stats" id="stats">
  <div class="stat glass"><div class="stat-v" id="s-ctry">35</div><div class="stat-l">Countries</div></div>
  <div class="stat glass"><div class="stat-v" id="s-rgn">652</div><div class="stat-l">Regions</div></div>
  <div class="stat glass"><div class="stat-v" id="s-ind">8</div><div class="stat-l">Indicators</div></div>
  <div class="stat glass"><div class="stat-v" id="s-cov">-</div><div class="stat-l">Coverage</div></div>
</div>

<!-- Variable selector -->
<div class="var-selector glass" id="var-sel"></div>

<!-- Map -->
<div class="map-block glass" id="map-block">
  <div class="map-header">
    <div><div class="map-title" id="map-title">Select an indicator</div><div class="map-sub" id="map-sub"></div></div>
  </div>
  <div class="timeline">
    <button class="play-btn" id="play" onclick="togglePlay()">&#9654;</button>
    <input type="range" class="slider" id="slider" min="1990" max="2024" value="2020" oninput="setYear(+this.value)">
    <span class="yr" id="yr-lbl">2020</span>
    <button class="spd" id="spd" onclick="cycleSpd()">1x</button>
  </div>
  <div class="map-area">
    <svg id="map" viewBox="-18 -26 70 62" preserveAspectRatio="xMidYMid meet"></svg>
    <div class="legend" id="legend" style="display:none">
      <span class="leg-l" id="leg-min">0</span>
      <canvas id="leg-cv" width="100" height="6"></canvas>
      <span class="leg-l" id="leg-max">100</span>
    </div>
  </div>
</div>

<!-- Region detail -->
<div class="detail-block glass" id="detail">
  <div class="empty">Click a region on the map to see details</div>
</div>

<!-- Inequality -->
<div class="ineq-block glass" id="ineq-block">
  <h3>Subnational Inequality by Country</h3>
  <div id="ineq-content"><div class="empty">Select an indicator</div></div>
</div>

<!-- Insights -->
<div class="insights-block glass" id="insights-block">
  <h3>Key Insights</h3>
  <div id="insights"><div class="empty">Select an indicator</div></div>
</div>

</div>

<script>
const D={data_json};

const VIRIDIS=[[68,1,84],[72,35,116],[64,67,135],[52,94,141],[33,122,133],[33,148,110],[64,175,79],[127,205,55],[202,225,31],[253,231,37]];

let cur={{v:null,yr:2020,sel:null,playing:false,timer:null,speed:1}};

function getColor(t){{
  t=Math.max(0,Math.min(1,t));
  const i=t*(VIRIDIS.length-1),lo=Math.floor(i),hi=Math.min(lo+1,VIRIDIS.length-1),f=i-lo;
  const r=Math.round(VIRIDIS[lo][0]+f*(VIRIDIS[hi][0]-VIRIDIS[lo][0]));
  const g=Math.round(VIRIDIS[lo][1]+f*(VIRIDIS[hi][1]-VIRIDIS[lo][1]));
  const b=Math.round(VIRIDIS[lo][2]+f*(VIRIDIS[hi][2]-VIRIDIS[lo][2]));
  return `rgb(${{r}},${{g}},${{b}})`;
}}

function init(){{
  renderMap();
  renderVarSelector();
  if(D.variables.length>0) selectVar(D.variables[0]);
}}

function renderMap(){{
  const svg=document.getElementById('map');
  let html='';
  for(const[geo,paths] of Object.entries(D.paths)){{
    for(const d of paths){{
      html+=`<path d="${{d}}" data-g="${{geo}}" fill="var(--border)" onmouseenter="hover('${{geo.replace(/'/g,"\\\\'")}}')" onclick="click('${{geo.replace(/'/g,"\\\\'")}}')"/>`;
    }}
  }}
  svg.innerHTML=html;
}}

function renderVarSelector(){{
  const el=document.getElementById('var-sel');
  let h='<span class="label">Indicator</span>';
  D.variables.forEach(v=>{{
    const m=D.varMeta[v];
    h+=`<button class="var-btn" data-v="${{v}}" onclick="selectVar('${{v}}')">${{m.domain.split(' ')[0]}}: ${{m.label}}</button>`;
  }});
  el.innerHTML=h;
}}

function selectVar(v){{
  cur.v=v;
  document.querySelectorAll('.var-btn').forEach(b=>b.classList.toggle('active',b.dataset.v===v));
  updateMap();
  updateIneq();
  updateInsights();
  if(cur.sel) showDetail(cur.sel);
}}

function setYear(y){{
  cur.yr=y;
  document.getElementById('yr-lbl').textContent=y;
  document.getElementById('slider').value=y;
  updateMap();
  if(cur.sel) showDetail(cur.sel);
}}

function updateMap(){{
  if(!cur.v) return;
  const m=D.varMeta[cur.v];
  const yd=D.values[cur.v][String(cur.yr)]||{{}};

  document.getElementById('map-title').textContent=m.label;
  document.getElementById('map-sub').textContent=`${{cur.yr}} | ${{m.unit}} | ${{m.domain}}`;

  const vals=Object.values(yd).map(d=>d.v).filter(v=>v!=null);
  const vmin=vals.length?Math.min(...vals):0, vmax=vals.length?Math.max(...vals):1;

  document.querySelectorAll('#map path').forEach(p=>{{
    const geo=p.getAttribute('data-g');
    const d=yd[geo];
    if(d&&d.v!=null){{
      const t=vmax>vmin?(d.v-vmin)/(vmax-vmin):0.5;
      p.setAttribute('fill',getColor(t));
    }} else {{
      p.setAttribute('fill','var(--border)');
    }}
  }});

  // Legend
  const leg=document.getElementById('legend'); leg.style.display='flex';
  document.getElementById('leg-min').textContent=vmin.toFixed(1);
  document.getElementById('leg-max').textContent=vmax.toFixed(1);
  const ctx=document.getElementById('leg-cv').getContext('2d');
  for(let x=0;x<100;x++){{ ctx.fillStyle=getColor(x/99); ctx.fillRect(x,0,1,6); }}

  // Stats
  const nRgn=vals.length;
  const countries=new Set();
  for(const[geo,d] of Object.entries(yd)) if(d.v!=null) countries.add((D.regionMeta[geo]||{{}}).admin0||'');
  document.getElementById('s-rgn').textContent=nRgn;
  document.getElementById('s-ctry').textContent=countries.size;
  document.getElementById('s-cov').textContent=Math.round(nRgn/652*100)+'%';
}}

function hover(geo){{ if(!cur.sel) showDetail(geo); }}
function click(geo){{
  if(cur.sel===geo){{ cur.sel=null; document.querySelectorAll('#map path.sel').forEach(p=>p.classList.remove('sel')); clearDetail(); return; }}
  cur.sel=geo;
  document.querySelectorAll('#map path.sel').forEach(p=>p.classList.remove('sel'));
  document.querySelectorAll(`#map path[data-g="${{geo}}"]`).forEach(p=>p.classList.add('sel'));
  showDetail(geo);
}}

function showDetail(geo){{
  if(!cur.v) return;
  const yd=D.values[cur.v][String(cur.yr)]||{{}};
  const d=yd[geo]; if(!d) return;
  const rm=D.regionMeta[geo]||{{}};
  const m=D.varMeta[cur.v];
  const fl=['Observed','Interpolated','Forecasted'][d.f]||'';
  const fc=['var(--accent)','var(--text3)','var(--warn)'][d.f]||'';

  let h=`<h3>${{rm.name||geo}}</h3><div class="detail-country">${{rm.country||''}} (${{rm.admin0||''}}) | ${{cur.yr}}</div>`;
  h+=`<div class="detail-row"><span class="detail-label">${{m.label}}</span><span class="detail-val">${{d.v}} ${{m.unit}}</span></div>`;
  h+=`<div class="detail-row"><span class="detail-label">Data source</span><span class="detail-val" style="color:${{fc}};font-size:.75rem">${{fl}}</span></div>`;

  // Sparkline
  const series=[];
  D.years.forEach(y=>{{
    const v=(D.values[cur.v][String(y)]||{{}})[geo];
    if(v) series.push({{y,v:v.v,f:v.f}});
  }});
  if(series.length>=2){{
    const w=280,ht=55,pad=4;
    const ys=series.map(s=>s.y), vs=series.map(s=>s.v);
    const mn=Math.min(...vs)*.95, mx=Math.max(...vs)*1.05;
    const xS=y=>pad+(y-ys[0])/(ys[ys.length-1]-ys[0])*(w-2*pad);
    const yS=v=>ht-pad-(v-mn)/(mx-mn)*(ht-2*pad);
    const lp=series.map(s=>`${{xS(s.y).toFixed(1)}},${{yS(s.v).toFixed(1)}}`).join('L');
    const ap=`M${{lp}}L${{xS(ys[ys.length-1]).toFixed(1)}},${{ht-pad}}L${{xS(ys[0]).toFixed(1)}},${{ht-pad}}Z`;
    let dots='';
    series.forEach(s=>{{ dots+=`<circle class="d${{s.f}}" cx="${{xS(s.y).toFixed(1)}}" cy="${{yS(s.v).toFixed(1)}}" r="2"/>`; }});
    h+=`<div class="spark"><div class="spark-label">Time series (${{ys[0]}}-${{ys[ys.length-1]}})</div>`;
    h+=`<svg viewBox="0 0 ${{w}} ${{ht}}"><path class="area" d="${{ap}}"/><path class="line" d="M${{lp}}"/>${{dots}}</svg>`;
    h+=`<div class="spark-legend"><span style="color:var(--accent)">&#9679; Observed</span><span style="color:var(--text3)">&#9679; Interpolated</span><span style="color:var(--warn)">&#9679; Forecasted</span></div></div>`;
  }}
  document.getElementById('detail').innerHTML=h;
}}

function clearDetail(){{ document.getElementById('detail').innerHTML='<div class="empty">Click a region on the map to see details</div>'; }}

function updateIneq(){{
  if(!cur.v) return;
  const data=D.inequality[cur.v]||[];
  if(!data.length){{ document.getElementById('ineq-content').innerHTML='<div class="empty">No data</div>'; return; }}
  const maxG=Math.max(...data.map(d=>d.g));
  let h=`<div class="ineq-sub">Gini coefficient — ${{D.varMeta[cur.v].label}} (${{cur.yr}})</div><div>`;
  data.forEach(d=>{{
    const pct=maxG>0?(d.g/maxG*100):0;
    const cls=d.g>0.15?'high':d.g>0.08?'med':'low';
    h+=`<div class="bar-row"><span class="bar-code">${{d.a}}</span><div class="bar-track"><div class="bar-fill ${{cls}}" style="width:${{pct.toFixed(1)}}%"></div></div><span class="bar-val">${{d.g.toFixed(3)}}</span></div>`;
  }});
  h+='</div>';
  document.getElementById('ineq-content').innerHTML=h;
}}

function updateInsights(){{
  if(!cur.v) return;
  const yd=D.values[cur.v][String(cur.yr)]||{{}};
  const m=D.varMeta[cur.v];
  const isW=m.higher_is==='worse';
  const entries=Object.entries(yd).filter(([,d])=>d.v!=null);
  if(entries.length<2){{ document.getElementById('insights').innerHTML='<div class="empty">Not enough data</div>'; return; }}

  entries.sort((a,b)=>a[1].v-b[1].v);
  const best=isW?entries[0]:entries[entries.length-1];
  const worst=isW?entries[entries.length-1]:entries[0];
  const mean=entries.reduce((s,[,d])=>s+d.v,0)/entries.length;
  const nObs=entries.filter(([,d])=>d.f===0).length;
  const nInt=entries.filter(([,d])=>d.f===1).length;
  const nFc=entries.filter(([,d])=>d.f===2).length;

  const ineqData=D.inequality[cur.v]||[];
  const mostUnequal=ineqData[0];
  const leastUnequal=ineqData[ineqData.length-1];

  let h='';
  const bm=D.regionMeta[best[0]]||{{}};
  const wm=D.regionMeta[worst[0]]||{{}};
  h+=ins('Best performing',`${{bm.name}} (${{bm.country}}): ${{best[1].v}} ${{m.unit}}`);
  h+=ins('Worst performing',`${{wm.name}} (${{wm.country}}): ${{worst[1].v}} ${{m.unit}}`);
  h+=ins('Continental mean',`${{mean.toFixed(1)}} ${{m.unit}} across ${{entries.length}} regions`);
  h+=ins('Absolute gap',`${{Math.abs(worst[1].v-best[1].v).toFixed(1)}} ${{m.unit}} between best and worst`);
  if(mostUnequal) h+=ins('Most unequal country',`${{mostUnequal.c}} (Gini: ${{mostUnequal.g.toFixed(3)}}, ${{mostUnequal.n}} regions)`);
  if(leastUnequal) h+=ins('Least unequal country',`${{leastUnequal.c}} (Gini: ${{leastUnequal.g.toFixed(3)}}, ${{leastUnequal.n}} regions)`);
  h+=ins('Data quality',`${{nObs}} observed, ${{nInt}} interpolated, ${{nFc}} forecasted`);
  document.getElementById('insights').innerHTML=h;
}}

function ins(tag,text){{ return `<div class="insight"><div class="tag">${{tag}}</div>${{text}}</div>`; }}

function togglePlay(){{
  cur.playing=!cur.playing;
  document.getElementById('play').classList.toggle('on',cur.playing);
  document.getElementById('play').innerHTML=cur.playing?'&#9646;&#9646;':'&#9654;';
  if(cur.playing) step(); else clearTimeout(cur.timer);
}}
function step(){{
  if(!cur.playing) return;
  let y=cur.yr+1; if(y>2024) y=1990;
  setYear(y);
  cur.timer=setTimeout(step,cur.speed===1?700:cur.speed===2?350:175);
}}
function cycleSpd(){{
  const s=[1,2,4]; cur.speed=s[(s.indexOf(cur.speed)+1)%3];
  document.getElementById('spd').textContent=cur.speed+'x';
}}

function toggleTheme(){{
  const t=document.documentElement.dataset.theme==='dark'?'light':'dark';
  document.documentElement.dataset.theme=t;
  document.getElementById('ti').innerHTML=t==='dark'?'&#9790;':'&#9788;';
}}

document.addEventListener('DOMContentLoaded',init);
</script>
</body>
</html>'''


if __name__ == "__main__":
    main()
