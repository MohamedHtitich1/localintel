#' @title DHS Visualization Functions
#' @description Functions for creating maps and visualizations of DHS Admin 1
#'   subnational data across Sub-Saharan Africa. Mirrors the Eurostat
#'   visualization layer (\code{\link{build_display_sf}},
#'   \code{\link{plot_best_by_country_level}}) but uses EPSG:4326 projection,
#'   Africa bounding box, and Admin 1 geometries from GADM (primary) / Natural Earth (fallback).
#' @name dhs_visualization
NULL


# ============================================================================
# INTERNAL HELPERS
# ============================================================================

# DHS country code -> ISO alpha-2 mapping
# Most DHS codes match ISO, but these differ:
.dhs_to_iso_map <- function() {
  c(
    BT = "BW",  # Botswana (DHS BT, ISO BW)
    BU = "BI",  # Burundi
    EK = "GQ",  # Equatorial Guinea
    LB = "LR",  # Liberia  (ISO LB = Lebanon)
    MD = "MG",  # Madagascar
    NI = "NE",  # Niger    (ISO NI = Nicaragua)
    NM = "NA",  # Namibia
    OS = "SO"   # Somalia
  )
}

# DHS country code -> ISO alpha-3 mapping (for GADM)
# All 44 SSA countries
.dhs_to_iso3_map <- function() {
  c(
    AO = "AGO",  # Angola
    BF = "BFA",  # Burkina Faso
    BJ = "BEN",  # Benin
    BT = "BWA",  # Botswana (DHS code BT, ISO BW/BWA)
    BU = "BDI",  # Burundi
    CD = "COD",  # Democratic Republic of Congo
    CF = "CAF",  # Central African Republic
    CG = "COG",  # Congo
    CI = "CIV",  # Cote d'Ivoire
    CM = "CMR",  # Cameroon
    CV = "CPV",  # Cape Verde
    EK = "GNQ",  # Equatorial Guinea
    ER = "ERI",  # Eritrea
    ET = "ETH",  # Ethiopia
    GA = "GAB",  # Gabon
    GH = "GHA",  # Ghana
    GM = "GMB",  # The Gambia
    GN = "GIN",  # Guinea
    KE = "KEN",  # Kenya
    KM = "COM",  # Comoros
    LB = "LBR",  # Liberia
    LS = "LSO",  # Lesotho
    MD = "MDG",  # Madagascar
    ML = "MLI",  # Mali
    MR = "MRT",  # Mauritania
    MW = "MWI",  # Malawi
    MZ = "MOZ",  # Mozambique
    NG = "NGA",  # Nigeria
    NI = "NER",  # Niger
    NM = "NAM",  # Namibia
    OS = "SOM",  # Somalia
    RW = "RWA",  # Rwanda
    SD = "SDN",  # Sudan
    SL = "SLE",  # Sierra Leone
    SN = "SEN",  # Senegal
    ST = "STP",  # Sao Tome and Principe
    SZ = "SWZ",  # Eswatini (Swaziland)
    TD = "TCD",  # Chad
    TG = "TGO",  # Togo
    TZ = "TZA",  # Tanzania
    UG = "UGA",  # Uganda
    ZA = "ZAF",  # South Africa
    ZM = "ZMB",  # Zambia
    ZW = "ZWE"   # Zimbabwe
  )
}


#' Normalize a Region Name for Matching
#'
#' Internal helper that normalises region names to a canonical form for
#' robust DHS <-> Natural Earth matching. Steps:
#' \enumerate{
#'   \item Trim leading/trailing whitespace
#'   \item Transliterate accented characters (e->e, i->i, etc.)
#'   \item Lowercase
#'   \item Replace hyphens, en-dashes, and multiple spaces with single space
#'   \item Strip parenthetical qualifiers like "(pre 2022)" or "(>= 2015)"
#'   \item Strip trailing year-like tokens "(2005)" "(2009)" "(2010)"
#' }
#'
#' @param x Character vector of region names
#' @return Normalised character vector
#' @keywords internal
.normalize_region <- function(x) {
  x <- trimws(x)
  # Transliterate accented chars
  x <- iconv(x, from = "UTF-8", to = "ASCII//TRANSLIT", sub = "")
  x <- tolower(x)
  # Hyphens / en-dashes -> space
  x <- gsub("[-\u2013]+", " ", x)
  # Collapse multiple spaces
  x <- gsub("\\s+", " ", x)
  # Strip parenthetical qualifiers
  x <- gsub("\\s*\\(.*?\\)\\s*", "", x)
  # Strip trailing year tokens
  x <- gsub("\\s+\\d{4}$", "", x)
  trimws(x)
}


#' Build DHS <-> GADM/NE Region Name Harmonization Table
#'
#' Creates a lookup table mapping DHS region names to GADM/Natural Earth admin1
#' names. Handles special cases:
#' - **Normalized matching**: Accent cleanup, fuzzy matching
#' - **Manual crosswalk**: Known mismatches (different naming conventions)
#' - **Composite regions**: Slash/comma-separated strata -> component regions
#' - **Dissolve targets**: DHS aggregate zones -> constituent GADM admin1s
#' - **Non-geographic strata**: Epidemiologic zones -> constituent geographic regions
#'
#' Uses multi-pass matching:
#' \enumerate{
#'   \item Normalised exact match (after accent/whitespace/hyphen cleanup)
#'   \item Curated manual crosswalk for known mismatches
#'   \item Composite region expansion (split and map each component)
#'   \item Dissolve lookup for DHS_COARSER countries
#'   \item Non-geographic strata mapping
#'   \item Fuzzy match (agrep) for remaining close matches
#' }
#'
#' @param panel_regions Dataframe with \code{admin0} and \code{region_name}
#'   columns (DHS side).
#' @param geo_regions Dataframe with \code{admin0} and \code{admin1_name}
#'   columns (GADM/NE side).
#' @param geo_sf Optional: sf object with geometry. If provided, composite and
#'   dissolve targets are detected and dissolved automatically.
#'
#' @return A tibble with columns:
#'   \describe{
#'     \item{admin0}{2-letter DHS country code}
#'     \item{dhs_region}{Original DHS region name}
#'     \item{geo_region}{Matched GADM/NE admin1 name(s), or NA if unmatchable}
#'     \item{match_type}{Character: "normalized", "manual", "composite", "dissolve", "nongeo", "fuzzy", NA}
#'     \item{is_multi}{Logical: TRUE if the DHS region maps to multiple geo regions (composite/dissolve)}
#'   }
#' @keywords internal
.build_harmonization <- function(panel_regions, geo_regions, geo_sf = NULL) {

  # --- Pass 1: Normalised match ---
  pr <- panel_regions |>
    dplyr::mutate(.norm = .normalize_region(.data$region_name))
  gr <- geo_regions |>
    dplyr::mutate(.norm = .normalize_region(.data$admin1_name))

  pass1 <- pr |>
    dplyr::inner_join(gr, by = c("admin0", ".norm"), relationship = "many-to-many") |>
    dplyr::distinct(.data$admin0, .data$region_name, .keep_all = TRUE) |>
    dplyr::transmute(
      admin0 = .data$admin0,
      dhs_region = .data$region_name,
      geo_region = .data$admin1_name,
      match_type = "normalized",
      is_multi = FALSE
    )

  remaining <- pr |>
    dplyr::anti_join(pass1, by = c("admin0", "region_name" = "dhs_region"))

  # --- Pass 2: Manual crosswalk ---
  manual <- .manual_crosswalk()
  pass2 <- remaining |>
    dplyr::inner_join(manual, by = c("admin0", "region_name" = "dhs_region")) |>
    dplyr::transmute(
      admin0 = .data$admin0,
      dhs_region = .data$region_name,
      geo_region = .data$ne_region,
      match_type = "manual",
      is_multi = FALSE
    )

  remaining <- remaining |>
    dplyr::anti_join(pass2, by = c("admin0", "region_name" = "dhs_region"))

  # --- Pass 3: Composite regions (slash/comma-separated) ---
  composite <- .composite_split()
  pass3_list <- list()
  for (i in seq_len(nrow(remaining))) {
    ctry <- remaining$admin0[i]
    dhs_name <- remaining$region_name[i]

    # Check if this DHS region is a composite
    comp_match <- composite |>
      dplyr::filter(.data$admin0 == ctry & .data$dhs_region == dhs_name)

    if (nrow(comp_match) > 0) {
      # Found composite: map each component
      components <- comp_match$component
      # For each component, try to find a geo match
      for (comp in components) {
        # Fuzzy match component against geo regions
        geo_for_ctry <- gr$admin1_name[gr$admin0 == ctry]
        comp_norm <- .normalize_region(comp)
        geo_norms <- .normalize_region(geo_for_ctry)
        hits_idx <- agrep(comp_norm, geo_norms, max.distance = 0.15)

        if (length(hits_idx) > 0) {
          # Use first hit
          pass3_list[[length(pass3_list) + 1]] <- tibble::tibble(
            admin0 = ctry,
            dhs_region = dhs_name,
            geo_region = geo_for_ctry[hits_idx[1]],
            match_type = "composite",
            is_multi = TRUE
          )
        }
      }
    }
  }

  pass3 <- if (length(pass3_list) > 0) {
    dplyr::bind_rows(pass3_list)
  } else {
    tibble::tibble(admin0 = character(), dhs_region = character(),
                    geo_region = character(), match_type = character(), is_multi = logical())
  }

  remaining <- remaining |>
    dplyr::anti_join(pass3, by = c("admin0", "region_name" = "dhs_region"))

  # --- Pass 4: Dissolve lookup (DHS_COARSER) ---
  dissolve <- .dissolve_lookup()
  pass4_list <- list()
  for (i in seq_len(nrow(remaining))) {
    ctry <- remaining$admin0[i]
    dhs_name <- remaining$region_name[i]

    # Check if this is a target in dissolve_lookup
    dissolve_match <- dissolve |>
      dplyr::filter(.data$admin0 == ctry & .data$dhs_parent == dhs_name)

    if (nrow(dissolve_match) > 0) {
      # Found dissolve target: map each constituent geo region
      for (geo_reg in unique(dissolve_match$gadm_admin1)) {
        # Verify geo_region exists in our geometries
        if (geo_reg %in% gr$admin1_name[gr$admin0 == ctry]) {
          pass4_list[[length(pass4_list) + 1]] <- tibble::tibble(
            admin0 = ctry,
            dhs_region = dhs_name,
            geo_region = geo_reg,
            match_type = "dissolve",
            is_multi = TRUE
          )
        }
      }
    }
  }

  pass4 <- if (length(pass4_list) > 0) {
    dplyr::bind_rows(pass4_list)
  } else {
    tibble::tibble(admin0 = character(), dhs_region = character(),
                    geo_region = character(), match_type = character(), is_multi = logical())
  }

  remaining <- remaining |>
    dplyr::anti_join(pass4, by = c("admin0", "region_name" = "dhs_region"))

  # --- Pass 5: Non-geographic strata ---
  nongeo <- .nongeo_dissolve()
  pass5_list <- list()
  for (i in seq_len(nrow(remaining))) {
    ctry <- remaining$admin0[i]
    dhs_name <- remaining$region_name[i]

    # Check if this is a non-geographic stratum
    nongeo_match <- nongeo |>
      dplyr::filter(.data$admin0 == ctry & .data$dhs_region == dhs_name)

    if (nrow(nongeo_match) > 0) {
      # Found nongeo: map each constituent component
      for (comp in unique(nongeo_match$component)) {
        # Fuzzy match component against geo regions
        geo_for_ctry <- gr$admin1_name[gr$admin0 == ctry]
        comp_norm <- .normalize_region(comp)
        geo_norms <- .normalize_region(geo_for_ctry)
        hits_idx <- agrep(comp_norm, geo_norms, max.distance = 0.15)

        if (length(hits_idx) > 0) {
          pass5_list[[length(pass5_list) + 1]] <- tibble::tibble(
            admin0 = ctry,
            dhs_region = dhs_name,
            geo_region = geo_for_ctry[hits_idx[1]],
            match_type = "nongeo",
            is_multi = TRUE
          )
        }
      }
    }
  }

  pass5 <- if (length(pass5_list) > 0) {
    dplyr::bind_rows(pass5_list)
  } else {
    tibble::tibble(admin0 = character(), dhs_region = character(),
                    geo_region = character(), match_type = character(), is_multi = logical())
  }

  remaining <- remaining |>
    dplyr::anti_join(pass5, by = c("admin0", "region_name" = "dhs_region"))

  # --- Pass 6: Fuzzy match (agrep) ---
  fuzzy_results <- list()
  for (i in seq_len(nrow(remaining))) {
    ctry <- remaining$admin0[i]
    dhs_name <- remaining$region_name[i]
    geo_names_ctry <- gr$admin1_name[gr$admin0 == ctry]

    if (length(geo_names_ctry) == 0) next

    # Fuzzy on normalised names
    dhs_norm <- .normalize_region(dhs_name)
    geo_norms <- .normalize_region(geo_names_ctry)

    hits_idx <- agrep(dhs_norm, geo_norms, max.distance = 0.2)
    if (length(hits_idx) == 1) {
      # Only accept unambiguous single match
      fuzzy_results[[length(fuzzy_results) + 1]] <- tibble::tibble(
        admin0 = ctry,
        dhs_region = dhs_name,
        geo_region = geo_names_ctry[hits_idx[1]],
        match_type = "fuzzy",
        is_multi = FALSE
      )
    }
  }

  pass6 <- if (length(fuzzy_results) > 0) {
    dplyr::bind_rows(fuzzy_results)
  } else {
    tibble::tibble(admin0 = character(), dhs_region = character(),
                    geo_region = character(), match_type = character(), is_multi = logical())
  }

  dplyr::bind_rows(pass1, pass2, pass3, pass4, pass5, pass6)
}


#' Manual DHS <-> Geometry Region Name Crosswalk
#'
#' Curated mappings for known mismatches that can't be resolved by
#' normalisation or fuzzy matching. Covers: different naming conventions,
#' city-level vs region-level names, GADM-specific name differences, and
#' minor boundary changes.
#'
#' Regions that require special handling (dissolve, composite, non-geographic)
#' are captured in separate helper functions, not here.
#'
#' @return Tibble with columns: admin0, dhs_region, ne_region
#' @keywords internal
.manual_crosswalk <- function() {
  tibble::tribble(
    ~admin0, ~dhs_region, ~ne_region,

    # CD -- DR Congo (GADM has modern boundaries)
    # "CD", "Kinshasa" matches via normalized pass
    # "Kasai Occident" handled via dissolve_lookup (Kasai + Kasai-Central)

    # CG -- Congo
    "CG", "Brazzaville 2009", "Brazzaville",
    "CG", "Pointe-Noire 2009", "Pointe Noire",

    # ER -- Eritrea (DHS English names -> local-language names)
    "ER", "Central", "Maekel",
    "ER", "Southern", "Debub",
    "ER", "Northern Red Sea", "Semenawi Keyih Bahri",
    "ER", "Southern Red Sea", "Debubawi Keyih Bahri",

    # ET -- Ethiopia
    "ET", "SNNPR", "Southern Nations, Nationalities",
    "ET", "Benishangul-Gumuz", "Benshangul-Gumaz",
    "ET", "Gambela", "Gambela Peoples",
    "ET", "Harari", "Harari People",
    "ET", "Oromia", "Oromiya",

    # GH -- Ghana (Brong-Ahafo split into 3 in 2018 -> use dissolve)
    # "GH", "Brong-Ahafo" is now handled via dissolve_lookup

    # GM -- The Gambia (DHS HQ towns -> administrative divisions)
    "GM", "Basse", "Upper River",
    "GM", "Brikama", "Western",
    "GM", "Janjanbureh", "Maccarthy Island",
    "GM", "Kerewan", "North Bank",
    "GM", "Kuntaur", "Maccarthy Island",
    "GM", "Mansakonko", "Lower River",

    # KM -- Comoros
    "KM", "Ngazidja", "Njaz\u00eddja",
    "KM", "Ndzuwani", "Nzwani",

    # LB -- Liberia
    "LB", "Monrovia", "Montserrado",

    # LS -- Lesotho
    "LS", "Qasha's Nek", "Qacha's Nek",

    # ML -- Mali (GADM names differ from NE)
    "ML", "Tombouctou", "Timbuktu",

    # MZ -- Mozambique
    "MZ", "Maputo Cidade", "Maputo",
    "MZ", "Maputo Provincia", "Maputo",

    # NG -- Nigeria (GADM state names for simple matches)
    "NG", "FCT Abuja", "Federal Capital Territory",
    "NG", "Nasarawa", "Nassarawa",

    # NM -- Namibia
    "NM", "Zambezi", "Caprivi",

    # RW -- Rwanda (GADM uses Kinyarwanda names)
    "RW", "Kigali", "Umujyi wa Kigali",
    "RW", "East", "Iburasirazuba",

    # TG -- Togo
    "TG", "Centrale", "Centre",
    "TG", "Lom\u00e9", "Maritime",

    # TZ -- Tanzania
    "TZ", "Pemba North", "Kaskazini Pemba",
    "TZ", "Pemba South", "Kusini Pemba",
    "TZ", "Town West", "Mjini Magharibi",
    "TZ", "Songwe", "Mbeya",

    # ZA -- South Africa
    "ZA", "KwaZulu Natal", "KwaZulu-Natal",
    "ZA", "Western  Cape", "Western Cape",
    "ZA", "Northern Province", "Limpopo",

    # ZW -- Zimbabwe
    "ZW", "Harare Chitungwiza", "Harare",

    # GM -- Gambia (Kanifing is a municipality in the Banjul urban area)
    "GM", "Kanifing", "Western",

    # TG -- Togo (Ensemble Maritime = Maritime region)
    "TG", "Ensemble Maritime", "Maritime",

    # RW -- Rwanda (modern province names -> Kinyarwanda GADM names)
    "RW", "North", "Amajyaruguru",
    "RW", "South", "Amajyepfo",
    "RW", "West", "Iburengerazuba",
    "RW", "Kigali Prefecture 1992", "Umujyi wa Kigali",
    "RW", "Butare/Gitarama", "Amajyepfo",

    # ML -- Mali (Bamako is a direct match, not a composite)
    "ML", "Bamako", "Bamako",

    # CD -- DR Congo (old name variants)
    "CD", "Lomani", "Lomami",
    # "Kasai Occident" handled via dissolve_lookup (Kasai + Kasai-Central)
    "CD", "Kasai", "Kasa\u00ef",

    # CM -- Cameroon (cities -> parent regions)
    "CM", "Douala", "Littoral",
    "CM", "Yaound\u00e9", "Centre",

    # MW -- Malawi (city/rural splits -> parent districts)
    "MW", "Blantyre City", "Blantyre",
    "MW", "Blantyre Rural", "Blantyre",
    "MW", "Lilongwe City", "Lilongwe",
    "MW", "Lilongwe Rural", "Lilongwe",
    "MW", "Mzuzu City", "Mzimba",
    "MW", "Zomba City", "Zomba",
    "MW", "Zomba Rural", "Zomba",

    # SN -- Senegal (time-variant zone names -> handled via dissolve)
    # "Centre (>2010)" and "Nord (>2010)" handled via dissolve_lookup

    # LB -- Liberia (Montserrado variant)
    "LB", "Montserrado incl. Monrovia", "Montserrado",

    # TZ -- Tanzania (Zanzibar variant names)
    # "Zanzibar 1999" handled via dissolve (all Zanzibar regions)
    "TZ", "Zanzibar North", "Kaskazini Unguja",
    "TZ", "Zanzibar South", "Kusini Unguja",

    # MD -- Madagascar (DHS names -> GADM admin2 names)
    "MD", "Vakinankarata", "Vakinankaratra",
    "MD", "Anamoroni'i Mania", "Amoron'i mania",
    "MD", "Atsimo Andrefana", "Atsimo-Andrefana",
    "MD", "Atsimo Atsinanana", "Atsimo-Atsinana",
    "MD", "Haute Matsiatra", "Haute matsiatra",
    "MD", "Vatovavy Fitovinany", "Vatovavy Fitovinany",
    "MD", "Alaotra Mangoro", "Alaotra-Mangoro"
  )
}


#' Get GADM Level for Country
#'
#' Returns the appropriate GADM level for fetching admin1 boundaries.
#' Some countries have finer admin divisions that better match DHS regions.
#'
#' @param iso3 Character: ISO 3166-1 alpha-3 code
#' @return Integer: GADM level (1 or 2)
#' @keywords internal
.gadm_level_override <- function(iso3) {
  # Countries where DHS regions correspond to admin2 (finer than admin1)
  admin2_countries <- c(
    "SLE" = 2,  # Sierra Leone: DHS has 16 districts -> admin2
    "GIN" = 2,  # Guinea: DHS has 8 regions + composite zones -> may need admin2
    "MDG" = 2   # Madagascar: DHS has 22 regions -> admin2
  )

  if (iso3 %in% names(admin2_countries)) {
    return(as.integer(admin2_countries[[iso3]]))
  }
  1L
}


#' Lookup Table: DHS Composite Region Names
#'
#' Maps DHS composite strata (slash- or comma-separated) to component regions.
#' Used to dissolve (union) geometries for composite strata.
#'
#' @return Tibble with columns: admin0, dhs_region, component_1, component_2, ...
#' @keywords internal
.composite_split <- function() {
  tibble::tribble(
    ~admin0, ~dhs_region, ~component,

    # BJ -- Benin (6 composite regions, each spanning 2+ departments)
    "BJ", "Atacora/Donga", "Atacora",
    "BJ", "Atacora/Donga", "Donga",
    "BJ", "Borgou/Alibori", "Borgou",
    "BJ", "Borgou/Alibori", "Alibori",
    "BJ", "Zou/Collines", "Zou",
    "BJ", "Zou/Collines", "Collines",
    "BJ", "Oueme/Plateau", "Oueme",
    "BJ", "Oueme/Plateau", "Plateau",
    "BJ", "Mono/Couffo", "Mono",
    "BJ", "Mono/Couffo", "Couffo",
    "BJ", "Littoral/Atlantique", "Littoral",
    "BJ", "Littoral/Atlantique", "Atlantique",

    # ML -- Mali (4 composite strata from 3+ regions each)
    "ML", "Kidal/Gao/Tombouctou", "Kidal",
    "ML", "Kidal/Gao/Tombouctou", "Gao",
    "ML", "Kidal/Gao/Tombouctou", "Tombouctou",
    "ML", "Kayes, Koulikoro, Segou", "Kayes",
    "ML", "Kayes, Koulikoro, Segou", "Koulikoro",
    "ML", "Kayes, Koulikoro, Segou", "Segou",
    "ML", "Mopti, Sikasso", "Mopti",
    "ML", "Mopti, Sikasso", "Sikasso",

    # NI -- Niger (2 composite zones)
    "NI", "Tahoua/Agadez", "Tahoua",
    "NI", "Tahoua/Agadez", "Agadez",
    "NI", "Zinder/Diffa", "Zinder",
    "NI", "Zinder/Diffa", "Diffa",

    # GH -- Ghana (1 composite: three northern regions)
    "GH", "Northern, Upper West, Upper East", "Northern",
    "GH", "Northern, Upper West, Upper East", "Upper West",
    "GH", "Northern, Upper West, Upper East", "Upper East",

    # BJ -- Benin (alternate orderings with accents)
    "BJ", "Atlantique/Littoral", "Atlantique",
    "BJ", "Atlantique/Littoral", "Littoral",
    "BJ", "Ou\u00e9m\u00e9/Plateau", "Ou\u00e9m\u00e9",
    "BJ", "Ou\u00e9m\u00e9/Plateau", "Plateau",

    # CM -- Cameroon (composite regions from older surveys)
    "CM", "Adamaoua/Nord/Extr\u00eame-Nord", "Adamaoua",
    "CM", "Adamaoua/Nord/Extr\u00eame-Nord", "Nord",
    "CM", "Adamaoua/Nord/Extr\u00eame-Nord", "Extr\u00eame-Nord",
    "CM", "Centre/Sud/Est", "Centre",
    "CM", "Centre/Sud/Est", "Sud",
    "CM", "Centre/Sud/Est", "Est",
    "CM", "Nord Ouest/Sud Ouest", "Nord-Ouest",
    "CM", "Nord Ouest/Sud Ouest", "Sud-Ouest",
    "CM", "Ouest/Littoral", "Ouest",
    "CM", "Ouest/Littoral", "Littoral",
    "CM", "Yaound\u00e9/Douala", "Centre",
    "CM", "Yaound\u00e9/Douala", "Littoral",

    # ML -- Mali (additional composite variants)
    "ML", "Kayes, Koulikoro", "Kayes",
    "ML", "Kayes, Koulikoro", "Koulikoro",
    "ML", "Mopti, Tombouctou/Gao, Kidal", "Mopti",
    "ML", "Mopti, Tombouctou/Gao, Kidal", "Timbuktu",
    "ML", "Mopti, Tombouctou/Gao, Kidal", "Gao",
    "ML", "Mopti, Tombouctou/Gao, Kidal", "Kidal",
    "ML", "Sikasso, S\u00e9gou", "Sikasso",
    "ML", "Sikasso, S\u00e9gou", "S\u00e9gou",

    # RW -- Rwanda (composite old prefecture names)
    # "Butare/Gitarama" maps to single GADM region -> moved to manual_crosswalk
    "RW", "Byumba/Kibungo", "Amajyaruguru",
    "RW", "Byumba/Kibungo", "Iburasirazuba",
    "RW", "Cyangugu/Ginkongoro", "Amajyepfo",
    "RW", "Cyangugu/Ginkongoro", "Iburengerazuba",
    "RW", "Kibuye/Ruhengeri/Gisenyi", "Iburengerazuba",
    "RW", "Kibuye/Ruhengeri/Gisenyi", "Amajyaruguru",

    # TZ -- Tanzania (composite and aggregate Zanzibar regions)
    "TZ", "Arusha/Manyara", "Arusha",
    "TZ", "Arusha/Manyara", "Manyara",
    "TZ", "Pemba", "Kaskazini Pemba",
    "TZ", "Pemba", "Kusini Pemba",
    "TZ", "Unguja", "Kaskazini Unguja",
    "TZ", "Unguja", "Kusini Unguja",
    "TZ", "Unguja", "Mjini Magharibi",
    "TZ", "Zanzibar", "Kaskazini Pemba",
    "TZ", "Zanzibar", "Kusini Pemba",
    "TZ", "Zanzibar", "Kaskazini Unguja",
    "TZ", "Zanzibar", "Kusini Unguja",
    "TZ", "Zanzibar", "Mjini Magharibi",
    "TZ", "Zanzibar 1999", "Kaskazini Pemba",
    "TZ", "Zanzibar 1999", "Kusini Pemba",
    "TZ", "Zanzibar 1999", "Kaskazini Unguja",
    "TZ", "Zanzibar 1999", "Kusini Unguja",
    "TZ", "Zanzibar 1999", "Mjini Magharibi"
  )
}


#' Lookup Table: Non-Geographic Strata to Constituent Regions
#'
#' Maps non-geographic DHS strata (zones, epidemiologic categories) to
#' their constituent geographic regions for dissolution/union.
#'
#' @return Tibble with columns: admin0, dhs_region, component
#' @keywords internal
.nongeo_dissolve <- function() {
  tibble::tribble(
    ~admin0, ~dhs_region, ~component,

    # NG -- Nigeria (geopolitical zones -> constituent states)
    "NG", "North Central", "Niger",
    "NG", "North Central", "Kogi",
    "NG", "North Central", "Benue",
    "NG", "North Central", "Plateau",
    "NG", "North Central", "Nassarawa",
    "NG", "North Central", "Kwara",
    "NG", "North Central", "Federal Capital Territory",

    "NG", "North East", "Adamawa",
    "NG", "North East", "Taraba",
    "NG", "North East", "Bauchi",
    "NG", "North East", "Gombe",
    "NG", "North East", "Yobe",
    "NG", "North East", "Borno",

    "NG", "North West", "Sokoto",
    "NG", "North West", "Kebbi",
    "NG", "North West", "Kaduna",
    "NG", "North West", "Katsina",
    "NG", "North West", "Kano",
    "NG", "North West", "Jigawa",
    "NG", "North West", "Zamfara",

    "NG", "South East", "Abia",
    "NG", "South East", "Enugu",
    "NG", "South East", "Ebonyi",
    "NG", "South East", "Anambra",
    "NG", "South East", "Imo",

    "NG", "South South", "Akwa Ibom",
    "NG", "South South", "Cross River",
    "NG", "South South", "Rivers",
    "NG", "South South", "Bayelsa",
    "NG", "South South", "Delta",
    "NG", "South South", "Edo",

    "NG", "South West", "Oyo",
    "NG", "South West", "Osun",
    "NG", "South West", "Ondo",
    "NG", "South West", "Ekiti",
    "NG", "South West", "Lagos",
    "NG", "South West", "Ogun",

    # TZ -- Tanzania (old epidemiologic zones -> regions)
    "TZ", "Eastern", "Morogoro",
    "TZ", "Eastern", "Pwani",
    "TZ", "Eastern", "Dar es Salaam",

    "TZ", "Lake", "Geita",
    "TZ", "Lake", "Kagera",
    "TZ", "Lake", "Mwanza",
    "TZ", "Lake", "Mara",
    "TZ", "Lake", "Simiyu",
    "TZ", "Lake", "Shinyanga",

    "TZ", "Northern", "Arusha",
    "TZ", "Northern", "Kilimanjaro",
    "TZ", "Northern", "Tanga",

    "TZ", "Southern Highlands", "Mbeya",
    "TZ", "Southern Highlands", "Songwe",
    "TZ", "Southern Highlands", "Iringa",

    "TZ", "Southern", "Lindi",
    "TZ", "Southern", "Ruvuma",

    "TZ", "Western", "Tabora",
    "TZ", "Western", "Kigoma",
    "TZ", "Western", "Rukwa",

    "TZ", "Central", "Dodoma",
    "TZ", "Central", "Singida",

    # CI -- Cote d'Ivoire (urban/rural/economic strata -> regions)
    "CI", "Abidjan", "Abidjan",
    "CI", "Centre", "Yamoussoukro",
    "CI", "Centre", "Lacs",

    "CI", "Rural South", "Nzi-Komoe",
    "CI", "Rural South", "Sud-Bandama",

    "CI", "Rural North", "Savanes",
    "CI", "Rural North", "Vallee du Bandama",

    "CI", "Other Urban", "Lagunes",
    "CI", "Other Urban", "Bafing",
    "CI", "Other Urban", "Denguele",

    # LB -- Liberia (epidemiologic zones -> counties)
    "LB", "North Central", "Bong",
    "LB", "North Central", "Nimba",

    "LB", "South Central", "Grand Gedeh",
    "LB", "South Central", "River Gee",
    "LB", "South Central", "Sinoe",

    "LB", "Southeast", "Greenville",

    "LB", "Central/South", "Montserrado",
    "LB", "Central/South", "Margibi",
    "LB", "Central/South", "Grand Bassa",

    # AO -- Angola (epidemiologic zones -> provinces)
    "AO", "Hyperendemic", "Luanda",
    "AO", "Hyperendemic", "Benguela",

    "AO", "Stable mesoendemic", "Huila",
    "AO", "Stable mesoendemic", "Namibe",

    "AO", "Instable mesoendemic", "Kuanza Sul",
    "AO", "Instable mesoendemic", "Kuanza Norte",

    # KE -- Kenya (malaria epidemiologic zones -> counties)
    "KE", "Coast endemic", "Mombasa",
    "KE", "Coast endemic", "Kilifi",
    "KE", "Coast endemic", "Kwale",
    "KE", "Coast endemic", "Lamu",
    "KE", "Coast endemic", "Taita Taveta",
    "KE", "Highland epidemic", "Nyeri",
    "KE", "Highland epidemic", "Murang'a",
    "KE", "Highland epidemic", "Kirinyaga",
    "KE", "Highland epidemic", "Embu",
    "KE", "Highland epidemic", "Meru",
    "KE", "Highland epidemic", "Tharaka-Nithi",
    "KE", "Highland epidemic", "Kisii",
    "KE", "Highland epidemic", "Nyamira",
    "KE", "Lake endemic", "Kisumu",
    "KE", "Lake endemic", "Homa Bay",
    "KE", "Lake endemic", "Migori",
    "KE", "Lake endemic", "Siaya",
    "KE", "Low risk", "Nairobi",
    "KE", "Semi-arid, seasonal", "Kajiado",
    "KE", "Semi-arid, seasonal", "Narok",
    "KE", "Semi-arid, seasonal", "Turkana",
    "KE", "Semi-arid, seasonal", "Samburu",
    "KE", "Semi-arid, seasonal", "Isiolo",
    "KE", "Semi-arid, seasonal", "Marsabit",

    # TZ -- Tanzania (South West Highlands zone)
    "TZ", "South West Highlands", "Mbeya",
    "TZ", "South West Highlands", "Iringa",
    "TZ", "South West Highlands", "Songwe",
    "TZ", "South West Highlands", "Njombe",

    # MD -- Madagascar (old ecological zones -> modern GADM regions)
    "MD", "Equatorial", "Toamasina",
    "MD", "Equatorial", "Analanjirofo",
    "MD", "Est", "Toamasina",
    "MD", "Est", "Analanjirofo",
    "MD", "Est", "Alaotra-Mangoro",
    "MD", "Hautes Terres Centrales", "Analamanga",
    "MD", "Hautes Terres Centrales", "Vakinankaratra",
    "MD", "Hautes Terres Centrales", "Amoroni-Mania",
    "MD", "Hauts Plateaux", "Analamanga",
    "MD", "Hauts Plateaux", "Vakinankaratra",
    "MD", "Hauts Plateaux", "Itasy",
    "MD", "Hauts Plateaux", "Bongolava",
    "MD", "Marges", "Sofia",
    "MD", "Marges", "Betsiboka",
    "MD", "Marges", "Diana",
    "MD", "Ouest", "Menabe",
    "MD", "Ouest", "Melaky",
    "MD", "Ouest", "Boeny",
    "MD", "Subd\u00e9sertique", "Androy",
    "MD", "Subd\u00e9sertique", "Anosy",
    "MD", "Sud", "Androy",
    "MD", "Sud", "Anosy",
    "MD", "Sud", "Atsimo-Andrefana",
    "MD", "Tropical", "Toamasina",
    "MD", "Tropical", "Analanjirofo",
    "MD", "Tropical", "Atsinanana",

    "MD", "Analamanga excluding capital", "Analamanga",
    "MD", "Antananarivo capital", "Analamanga",

    # CI -- Cote d'Ivoire (survey strata that aren't geographic)
    "CI", "Other urban", "Lagunes",
    "CI", "Other urban", "Como\u00e9",
    "CI", "Other urban", "G\u00f4h-Djiboua",
    "CI", "Other urban", "Sassandra-Marahou\u00e9",
    "CI", "Other urban", "Vall\u00e9e du Bandama",
    "CI", "Rural", "Savanes",
    "CI", "Rural", "Woroba",
    "CI", "Rural", "Dengu\u00e9l\u00e9",
    "CI", "Rural", "Zanzan",
    "CI", "Rural", "Montagnes",
    "CI", "Rural", "Lacs",
    "CI", "Rural", "Bas-Sassandra"
  )
}


#' Lookup Table: DHS_COARSER Dissolve (NE admin1 -> parent DHS region)
#'
#' For countries where DHS has aggregate zones (coarser than GADM/NE admin1),
#' this table maps individual GADM admin1 names to their parent DHS region.
#' Used to dissolve (union) GADM/NE polygons into DHS-level regions.
#'
#' Example: Burkina Faso has 13 DHS regions but 45 NE provinces.
#' This table maps each province to its parent DHS region.
#'
#' @return Tibble with columns: admin0, gadm_admin1, dhs_parent
#' @keywords internal
.dissolve_lookup <- function() {
  tibble::tribble(
    ~admin0, ~gadm_admin1, ~dhs_parent,

    # BF -- Burkina Faso (13 DHS regions -> 45 GADM provinces)
    # Regional mapping
    "BF", "Bale", "Cascade",
    "BF", "Nayala", "Cascade",
    "BF", "Sourou", "Cascade",

    "BF", "Bougouriba", "Sud-Ouest",
    "BF", "Ioba", "Sud-Ouest",

    "BF", "Kossi", "Boucle du Mouhoun",
    "BF", "Mouhoun", "Boucle du Mouhoun",
    "BF", "Nienena", "Boucle du Mouhoun",

    "BF", "Ganzourgou", "Plateau-Central",
    "BF", "Kanem", "Plateau-Central",

    "BF", "Bazega", "Centre-Sud",
    "BF", "Nahouri", "Centre-Sud",
    "BF", "Zoundweogo", "Centre-Sud",

    "BF", "Bougouriba", "Sud-Ouest",
    "BF", "Ioba", "Sud-Ouest",
    "BF", "Kenedougou", "Hauts-Bassins",
    "BF", "Tuy", "Hauts-Bassins",

    "BF", "Comoe", "Cascades",
    "BF", "Leraba", "Cascades",

    "BF", "Gourma", "Est",
    "BF", "Gnagna", "Est",
    "BF", "Komondjari", "Est",

    "BF", "Haut-Bassins", "Hauts-Bassins",
    "BF", "Seno", "Sahel",
    "BF", "Sanmantenga", "Plateau-Central",
    "BF", "Soum", "Sahel",
    "BF", "Yagha", "Sahel",
    "BF", "Yatenga", "Nord",
    "BF", "Zondoma", "Nord",
    "BF", "Zoundweogo", "Centre-Sud",
    "BF", "Kanem", "Plateau-Central",
    "BF", "Boulgou", "Centre-Est",
    "BF", "Koulpelogo", "Centre-Est",

    # UG -- Uganda (25 DHS sub-regions -> 112 GADM districts)
    # Northern Region
    "UG", "Gulu", "Northern",
    "UG", "Amuru", "Northern",
    "UG", "Kitgum", "Northern",
    "UG", "Pader", "Northern",
    "UG", "Kole", "Northern",
    "UG", "Nwoya", "Northern",
    "UG", "Oyam", "Northern",

    # Eastern Region
    "UG", "Soroti", "Eastern",
    "UG", "Katakwi", "Eastern",
    "UG", "Kween", "Eastern",
    "UG", "Bukwo", "Eastern",
    "UG", "Kapchorwa", "Eastern",
    "UG", "Bulambuli", "Eastern",

    # Central Region
    "UG", "Kampala", "Central",
    "UG", "Wakiso", "Central",
    "UG", "Luwero", "Central",
    "UG", "Mubende", "Central",
    "UG", "Kiboga", "Central",
    "UG", "Mpigi", "Central",
    "UG", "Masaka", "Central",
    "UG", "Rakai", "Central",

    # Western Region
    "UG", "Mbarara", "Western",
    "UG", "Kabale", "Western",
    "UG", "Kisoro", "Western",
    "UG", "Kanungu", "Western",
    "UG", "Rukungiri", "Western",

    # TD -- Chad (7 DHS zones -> 22 GADM prefectures)
    "TD", "Logone Occidentale", "Zone 1",
    "TD", "Logone Orientale", "Zone 1",
    "TD", "Mayo-Kebbi Est", "Zone 2",
    "TD", "Mayo-Kebbi Ouest", "Zone 2",
    "TD", "Kanem", "Zone 3",
    "TD", "Lac", "Zone 3",
    "TD", "Lac", "Zone 4",
    "TD", "Kanem", "Zone 4",
    "TD", "Barh El Gazel", "Zone 4",
    "TD", "Mont Illi", "Zone 4",
    "TD", "Tibesti", "Zone 4",
    "TD", "Borkou", "Zone 5",
    "TD", "Ennedi Est", "Zone 5",
    "TD", "Ennedi Ouest", "Zone 5",
    "TD", "Chari Baguirmi", "Zone 6",
    "TD", "Guera", "Zone 6",
    "TD", "Hadjer Lamis", "Zone 6",
    "TD", "Salamat", "Zone 6",
    "TD", "Mayo Kebbi", "Zone 7",
    "TD", "Moyen Chari", "Zone 7",
    "TD", "Tandjile", "Zone 7",

    # BU -- Burundi (5 DHS zones -> 17 GADM provinces)
    "BU", "Bujumbura", "Bujumbura City",
    "BU", "Zone 1", "Bururi",
    "BU", "Zone 1", "Muramvya",
    "BU", "Zone 1", "Gitega",
    "BU", "Zone 2", "Karuzi",
    "BU", "Zone 2", "Kirundo",
    "BU", "Zone 3", "Cankuzo",
    "BU", "Zone 3", "Ruyigi",
    "BU", "Zone 4", "Bubanza",
    "BU", "Zone 4", "Bujumbura Rural",
    "BU", "Zone 4", "Makamba",
    "BU", "Zone 4", "Rumonge",

    # GN -- Guinea (4 natural regions -> prefectures at admin2)
    # Middle Guinea (Moyenne Guinee)
    "GN", "Dalaba", "Central Guinea",
    "GN", "Lab\u00e9", "Central Guinea",
    "GN", "L\u00e9louma", "Central Guinea",
    "GN", "Mali", "Central Guinea",
    "GN", "Mamou", "Central Guinea",
    "GN", "Pita", "Central Guinea",
    "GN", "Tougu\u00e9", "Central Guinea",
    "GN", "Koubia", "Central Guinea",

    # Forest Guinea (Guinee Forestiere)
    "GN", "Beyla", "Forest Guinea",
    "GN", "Gu\u00e9ck\u00e9dou", "Forest Guinea",
    "GN", "Lola", "Forest Guinea",
    "GN", "Macenta", "Forest Guinea",
    "GN", "Nz\u00e9r\u00e9kor\u00e9", "Forest Guinea",
    "GN", "Yamou", "Forest Guinea",

    # Lower Guinea (Basse Guinee)
    "GN", "Boffa", "Lower Guinea",
    "GN", "Bok\u00e9", "Lower Guinea",
    "GN", "Coyah", "Lower Guinea",
    "GN", "Dubr\u00e9ka", "Lower Guinea",
    "GN", "For\u00e9cariah", "Lower Guinea",
    "GN", "Fria", "Lower Guinea",
    "GN", "Gaoual", "Lower Guinea",
    "GN", "Kindia", "Lower Guinea",
    "GN", "Koundara", "Lower Guinea",
    "GN", "T\u00e9lim\u00e9l\u00e9", "Lower Guinea",

    # Upper Guinea (Haute Guinee)
    "GN", "Dabola", "Upper Guinea",
    "GN", "Dinguiraye", "Upper Guinea",
    "GN", "Faranah", "Upper Guinea",
    "GN", "Kankan", "Upper Guinea",
    "GN", "K\u00e9rouan\u00e9", "Upper Guinea",
    "GN", "Kissidougou", "Upper Guinea",
    "GN", "Kouroussa", "Upper Guinea",
    "GN", "Mandiana", "Upper Guinea",
    "GN", "Siguiri", "Upper Guinea",

    # KE -- Kenya (old 8 provinces -> 47 GADM counties)
    "KE", "Kiambu", "Central",
    "KE", "Murang'a", "Central",
    "KE", "Nyeri", "Central",
    "KE", "Nyandarua", "Central",
    "KE", "Kirinyaga", "Central",

    "KE", "Mombasa", "Coast",
    "KE", "Kilifi", "Coast",
    "KE", "Kwale", "Coast",
    "KE", "Tana River", "Coast",
    "KE", "Lamu", "Coast",
    "KE", "Taita Taveta", "Coast",

    "KE", "Embu", "Eastern",
    "KE", "Meru", "Eastern",
    "KE", "Tharaka-Nithi", "Eastern",
    "KE", "Kitui", "Eastern",
    "KE", "Machakos", "Eastern",
    "KE", "Makueni", "Eastern",
    "KE", "Isiolo", "Eastern",
    "KE", "Marsabit", "Eastern",

    "KE", "Garissa", "North Eastern",
    "KE", "Wajir", "North Eastern",
    "KE", "Mandera", "North Eastern",

    "KE", "Kisumu", "Nyanza",
    "KE", "Homa Bay", "Nyanza",
    "KE", "Migori", "Nyanza",
    "KE", "Kisii", "Nyanza",
    "KE", "Nyamira", "Nyanza",
    "KE", "Siaya", "Nyanza",

    "KE", "Nakuru", "Rift Valley",
    "KE", "Narok", "Rift Valley",
    "KE", "Kajiado", "Rift Valley",
    "KE", "Kericho", "Rift Valley",
    "KE", "Bomet", "Rift Valley",
    "KE", "Nandi", "Rift Valley",
    "KE", "Uasin Gishu", "Rift Valley",
    "KE", "Trans Nzoia", "Rift Valley",
    "KE", "Elgeyo-Marakwet", "Rift Valley",
    "KE", "Baringo", "Rift Valley",
    "KE", "Laikipia", "Rift Valley",
    "KE", "Samburu", "Rift Valley",
    "KE", "Turkana", "Rift Valley",
    "KE", "West Pokot", "Rift Valley",

    "KE", "Kakamega", "Western",
    "KE", "Bungoma", "Western",
    "KE", "Busia", "Western",
    "KE", "Vihiga", "Western",

    # UG -- Uganda (DHS sub-regions -> GADM districts)
    "UG", "Gulu", "Acholi",
    "UG", "Kitgum", "Acholi",
    "UG", "Pader", "Acholi",

    "UG", "Mbale", "Bugisu/Elgon",
    "UG", "Sironko", "Bugisu/Elgon",
    "UG", "Kapchorwa", "Bugisu/Elgon",

    "UG", "Hoima", "Bunyoro",
    "UG", "Masindi", "Bunyoro",
    "UG", "Kibale", "Bunyoro",

    "UG", "Iganga", "Busoga",
    "UG", "Jinja", "Busoga",
    "UG", "Kamuli", "Busoga",
    "UG", "Bugiri", "Busoga",
    "UG", "Mayuge", "Busoga",

    "UG", "Soroti", "East Central",
    "UG", "Katakwi", "East Central",
    "UG", "Kumi", "East Central",
    "UG", "Pallisa", "East Central",
    "UG", "Kaberamaido", "East Central",

    "UG", "Soroti", "East Central (AIS/MIS)",
    "UG", "Katakwi", "East Central (AIS/MIS)",
    "UG", "Kumi", "East Central (AIS/MIS)",
    "UG", "Pallisa", "East Central (AIS/MIS)",
    "UG", "Kaberamaido", "East Central (AIS/MIS)",

    "UG", "Kotido", "Karamoja",
    "UG", "Moroto", "Karamoja",
    "UG", "Nakapiripirit", "Karamoja",

    "UG", "Kabale", "Kigezi",
    "UG", "Kisoro", "Kigezi",
    "UG", "Kanungu", "Kigezi",
    "UG", "Rukungiri", "Kigezi",

    "UG", "Tororo", "Mid Eastern",
    "UG", "Busia", "Mid Eastern",
    "UG", "Pallisa", "Mid Eastern",

    "UG", "Lira", "Mid Northern",
    "UG", "Apac", "Mid Northern",

    "UG", "Luwero", "North Buganda",
    "UG", "Mukono", "North Buganda",
    "UG", "Kayunga", "North Buganda",
    "UG", "Nakasongola", "North Buganda",
    "UG", "Kiboga", "North Buganda",

    "UG", "Gulu", "North East",
    "UG", "Kitgum", "North East",
    "UG", "Pader", "North East",
    "UG", "Kotido", "North East",
    "UG", "Moroto", "North East",

    "UG", "Masaka", "South Buganda",
    "UG", "Rakai", "South Buganda",
    "UG", "Sembabule", "South Buganda",
    "UG", "Kalangala", "South Buganda",
    "UG", "Mpigi", "South Buganda",

    "UG", "Mbarara", "South West",
    "UG", "Ntungamo", "South West",
    "UG", "Bushenyi", "South West",
    "UG", "Kabarole", "South West",
    "UG", "Kamwenge", "South West",
    "UG", "Kasese", "South West",
    "UG", "Kyenjojo", "South West",
    "UG", "Bundibugyo", "South West",

    "UG", "Soroti", "Teso",
    "UG", "Kumi", "Teso",
    "UG", "Katakwi", "Teso",
    "UG", "Pallisa", "Teso",

    "UG", "Arua", "West Nile",
    "UG", "Nebbi", "West Nile",
    "UG", "Moyo", "West Nile",
    "UG", "Adjumani", "West Nile",
    "UG", "Yumbe", "West Nile",

    # RW -- Rwanda (old prefectures -> GADM Kinyarwanda provinces)
    "RW", "Amajyaruguru", "Byumba",
    "RW", "Amajyaruguru", "Ruhengeri",
    "RW", "Amajyepfo", "Butare",
    "RW", "Amajyepfo", "Gitarama",
    "RW", "Amajyepfo", "Gikongoro",
    "RW", "Iburasirazuba", "Kibungo",
    "RW", "Iburengerazuba", "Cyangugu",
    "RW", "Iburengerazuba", "Gisenyi",
    "RW", "Iburengerazuba", "Kibuye",
    "RW", "Umujyi wa Kigali", "Kigali City",

    # MW -- Malawi (3 DHS regions -> 28 GADM districts)
    "MW", "Chitipa", "Northern",
    "MW", "Karonga", "Northern",
    "MW", "Nkhata Bay", "Northern",
    "MW", "Rumphi", "Northern",
    "MW", "Mzimba", "Northern",
    "MW", "Likoma", "Northern",

    "MW", "Kasungu", "Central",
    "MW", "Nkhotakota", "Central",
    "MW", "Ntchisi", "Central",
    "MW", "Dowa", "Central",
    "MW", "Salima", "Central",
    "MW", "Lilongwe", "Central",
    "MW", "Mchinji", "Central",
    "MW", "Dedza", "Central",
    "MW", "Ntcheu", "Central",

    "MW", "Mangochi", "Southern",
    "MW", "Machinga", "Southern",
    "MW", "Zomba", "Southern",
    "MW", "Chiradzulu", "Southern",
    "MW", "Blantyre", "Southern",
    "MW", "Mwanza", "Southern",
    "MW", "Thyolo", "Southern",
    "MW", "Mulanje", "Southern",
    "MW", "Phalombe", "Southern",
    "MW", "Chikwawa", "Southern",
    "MW", "Nsanje", "Southern",
    "MW", "Balaka", "Southern",
    "MW", "Neno", "Southern",

    # BF -- Burkina Faso (5 DHS macro zones -> 13 GADM regions)
    "BF", "Centre", "Central/South",
    "BF", "Centre-Sud", "Central/South",
    "BF", "Centre-Est", "Central/South",
    "BF", "Centre-Ouest", "Central/South",

    "BF", "Est", "East",

    "BF", "Nord", "North",
    "BF", "Sahel", "North",
    "BF", "Centre-Nord", "North",
    "BF", "Plateau-Central", "North",

    "BF", "Centre", "Ouagadougou",

    "BF", "Haut-Bassins", "West",
    "BF", "Cascades", "West",
    "BF", "Boucle du Mouhoun", "West",
    "BF", "Sud-Ouest", "West",

    # SN -- Senegal (DHS zones -> 14 GADM regions)
    # Pre-2010 zones
    "SN", "Kaolack", "Centre",
    "SN", "Kaffrine", "Centre",
    "SN", "Fatick", "Centre",
    "SN", "Diourbel", "Centre",

    "SN", "Saint-Louis", "Nord et Est",
    "SN", "Matam", "Nord et Est",
    "SN", "Tambacounda", "Nord et Est",
    "SN", "K\u00e9dougou", "Nord et Est",
    "SN", "Louga", "Nord et Est",

    "SN", "Dakar", "Ouest",
    "SN", "Thi\u00e8s", "Ouest",
    "SN", "Ziguinchor", "Ouest",
    "SN", "S\u00e9dhiou", "Ouest",
    "SN", "Kolda", "Ouest",

    # Post-2010 zones
    "SN", "Kaolack", "Centre (>2010)",
    "SN", "Kaffrine", "Centre (>2010)",
    "SN", "Fatick", "Centre (>2010)",
    "SN", "Diourbel", "Centre (>2010)",

    "SN", "Saint-Louis", "Nord (>2010)",
    "SN", "Matam", "Nord (>2010)",
    "SN", "Louga", "Nord (>2010)",

    "SN", "K\u00e9dougou", "Sud (>2010)",
    "SN", "Kolda", "Sud (>2010)",
    "SN", "S\u00e9dhiou", "Sud (>2010)",
    "SN", "Tambacounda", "Sud (>2010)",
    "SN", "Ziguinchor", "Sud (>2010)",

    "SN", "S\u00e9dhiou", "Sud",
    "SN", "Kolda", "Sud",
    "SN", "Tambacounda", "Sud",
    "SN", "K\u00e9dougou", "Sud",
    "SN", "Ziguinchor", "Sud",

    # BU -- Burundi (named zones -> 17 GADM provinces)
    "BU", "Gitega", "Centre-East",
    "BU", "Muramvya", "Centre-East",
    "BU", "Mwaro", "Centre-East",
    "BU", "Karuzi", "Centre-East",
    "BU", "Rutana", "Centre-East",
    "BU", "Ruyigi", "Centre-East",
    "BU", "Cankuzo", "Centre-East",

    "BU", "Ngozi", "North",
    "BU", "Kayanza", "North",
    "BU", "Kirundo", "North",
    "BU", "Muyinga", "North",

    "BU", "Bururi", "South",
    "BU", "Makamba", "South",
    "BU", "Rumonge", "South",
    "BU", "Rutana", "South",

    "BU", "Bubanza", "West",
    "BU", "Cibitoke", "West",
    "BU", "Bujumbura Rural", "West",
    "BU", "Bujumbura Mairie", "West",

    # CD -- DR Congo (old provinces -> 26 modern GADM provinces)
    "CD", "Kwango", "Bandundu",
    "CD", "Kwilu", "Bandundu",
    "CD", "Mai-Ndombe", "Bandundu",

    "CD", "Kongo-Central", "Bas-Congo",

    "CD", "Haut-Katanga", "Katanga",
    "CD", "Haut-Lomami", "Katanga",
    "CD", "Lualaba", "Katanga",
    "CD", "Tanganyika", "Katanga",

    "CD", "Lomami", "Lomani",

    "CD", "Kasa\u00ef", "Kasa\u00ef Occident",
    "CD", "Kasa\u00ef-Central", "Kasa\u00ef Occident",

    "CD", "Kasa\u00ef-Oriental", "Kasa\u00ef Oriental",
    "CD", "Lomami", "Kasa\u00ef Oriental",
    "CD", "Sankuru", "Kasa\u00ef Oriental",

    # GH -- Ghana (Brong-Ahafo split into 3 in 2018)
    "GH", "Ahafo", "Brong-Ahafo",
    "GH", "Bono", "Brong-Ahafo",
    "GH", "Bono East", "Brong-Ahafo",

    # NM -- Namibia (4 DHS macro zones -> 13 GADM regions)
    "NM", "Khomas", "Central",
    "NM", "Otjozondjupa", "Central",
    "NM", "Erongo", "Central",

    "NM", "Kavango", "Northeast",
    "NM", "Zambezi", "Northeast",
    "NM", "Ohangwena", "Northeast",
    "NM", "Oshikoto", "Northeast",
    "NM", "Oshana", "Northeast",
    "NM", "Omusati", "Northeast",

    "NM", "Kunene", "Northwest",

    "NM", "!Karas", "South",
    "NM", "Hardap", "South",
    "NM", "Omaheke", "South",

    # LB -- Liberia (zone -> county mappings)
    "LB", "Lofa", "North Western",
    "LB", "Bomi", "North Western",
    "LB", "Grand Cape Mount", "North Western",
    "LB", "Gbapolu", "North Western",

    "LB", "Grand Gedeh", "South Eastern A",
    "LB", "River Gee", "South Eastern A",
    "LB", "Sinoe", "South Eastern A",

    "LB", "Grand Kru", "South Eastern B",
    "LB", "Maryland", "South Eastern B",
    "LB", "Rivercess", "South Eastern B",

    # GA -- Gabon (3 DHS zones -> 9 GADM provinces)
    "GA", "Estuaire", "Libreville,Port-Gentil",
    "GA", "Ogoou\u00e9-Maritime", "Libreville,Port-Gentil",

    "GA", "Woleu-Ntem", "North",
    "GA", "Ogoou\u00e9-Ivindo", "North",
    "GA", "Haut-Ogoou\u00e9", "North",

    "GA", "Ngouni\u00e9", "South",
    "GA", "Nyanga", "South",
    "GA", "Ogoou\u00e9-Lolo", "South",
    "GA", "Moyen-Ogoou\u00e9", "South",

    # CG -- Congo (2 DHS aggregate zones -> 12 GADM departments)
    "CG", "Likouala", "Nord",
    "CG", "Cuvette", "Nord",
    "CG", "Cuvette-Ouest", "Nord",
    "CG", "Sangha", "Nord",
    "CG", "Plateaux", "Nord",

    "CG", "Pool", "Sud",
    "CG", "L\u00e9koumou", "Sud",
    "CG", "Bouenza", "Sud",
    "CG", "Niari", "Sud",
    "CG", "Kouilou", "Sud",

    # SL -- Sierra Leone (DHS provinces -> GADM admin2 districts)
    "SL", "Kailahun", "Eastern",
    "SL", "Kenema", "Eastern",
    "SL", "Kono", "Eastern",

    "SL", "Koinadugu", "Falaba",

    "SL", "Bombali", "North Western",
    "SL", "Kambia", "North Western",
    "SL", "Port Loko", "North Western",

    "SL", "Bombali", "Northern",
    "SL", "Kambia", "Northern",
    "SL", "Koinadugu", "Northern",
    "SL", "Port Loko", "Northern",
    "SL", "Tonkolili", "Northern",

    "SL", "Bombali", "Northern (before 2017)",
    "SL", "Kambia", "Northern (before 2017)",
    "SL", "Koinadugu", "Northern (before 2017)",
    "SL", "Port Loko", "Northern (before 2017)",
    "SL", "Tonkolili", "Northern (before 2017)",

    "SL", "Bo", "Southern",
    "SL", "Bonthe", "Southern",
    "SL", "Moyamba", "Southern",
    "SL", "Pujehun", "Southern",

    "SL", "Western Rural", "Western",
    "SL", "Western Urban", "Western",

    # CI -- Cote d'Ivoire (DHS zones -> 14 GADM districts)
    "CI", "Como\u00e9", "Centre-Est",
    "CI", "Zanzan", "Centre-Est",

    "CI", "G\u00f4h-Djiboua", "Centre-Ouest",
    "CI", "Sassandra-Marahou\u00e9", "Centre-Ouest",

    "CI", "Woroba", "Nord-Ouest",
    "CI", "Dengu\u00e9l\u00e9", "Nord-Ouest",

    "CI", "Lagunes", "Sud sans Abidjan",
    "CI", "Bas-Sassandra", "Sud sans Abidjan",

    # TD -- Chad (missing zone -> GADM mappings)
    "TD", "Mandoul", "Zone 7",
    "TD", "Moyen-Chari", "Zone 7",
    "TD", "Tandjil\u00e9", "Zone 7",
    "TD", "Mayo-Kebbi Ouest", "Zone 7",
    "TD", "Mayo-Kebbi Est", "Zone 7",

    "TD", "Ouadda\u00ef", "Zone 8",
    "TD", "Wadi Fira", "Zone 8",
    "TD", "Sila", "Zone 8",
    "TD", "Batha", "Zone 8",

    # MD -- Madagascar (old 6 provinces -> 22 GADM admin2 regions)
    "MD", "Analamanga", "Antananarivo",
    "MD", "Bongolava", "Antananarivo",
    "MD", "Itasy", "Antananarivo",
    "MD", "Vakinankaratra", "Antananarivo",

    "MD", "Diana", "Antsiranana",
    "MD", "Sava", "Antsiranana",

    "MD", "Amoron'i mania", "Fianarantsoa",
    "MD", "Atsimo-Atsinana", "Fianarantsoa",
    "MD", "Haute matsiatra", "Fianarantsoa",
    "MD", "Ihorombe", "Fianarantsoa",
    "MD", "Vatovavy Fitovinany", "Fianarantsoa",

    "MD", "Betsiboka", "Mahajanga",
    "MD", "Boeny", "Mahajanga",
    "MD", "Melaky", "Mahajanga",
    "MD", "Sofia", "Mahajanga",

    "MD", "Alaotra-Mangoro", "Toamasina",
    "MD", "Analanjirofo", "Toamasina",
    "MD", "Atsinanana", "Toamasina",

    "MD", "Androy", "Toliary",
    "MD", "Anosy", "Toliary",
    "MD", "Atsimo-Andrefana", "Toliary",
    "MD", "Menabe", "Toliary"
  )
}


# ============================================================================
# ADMIN 1 GEOMETRY FETCHING
# ============================================================================

#' Get Admin 1 Geometries for SSA Countries
#'
#' Fetches Admin 1 (state/province/region) boundary geometries for Sub-Saharan
#' African countries. **PRIMARY SOURCE**: GADM (Global Administrative Division
#' Maps) has correct modern boundaries for most countries (e.g., Kenya 47 counties,
#' Sierra Leone districts, DRC 26 new provinces).
#'
#' **FALLBACK**: Natural Earth is used for countries not available in GADM or
#' for fallback boundaries.
#'
#' **HARMONIZATION**: The function automatically:
#'   1. Matches normalized region names (exact, then fuzzy)
#'   2. Applies manual crosswalk for known mismatches
#'   3. Dissolves GADM/NE polygons for DHS_COARSER countries (BF, UG, TD, BU, GN)
#'   4. Unions component polygons for composite DHS strata (e.g., "Atacora/Donga")
#'   5. Maps non-geographic strata to constituent regions (e.g., NG zones)
#'
#' Results are cached within the R session via the localintel cache system.
#'
#' @param country_ids Character vector of 2-letter DHS country codes.
#'   If NULL (default), uses \code{\link{ssa_codes}()}.
#'
#' @return An sf object with columns:
#'   \describe{
#'     \item{admin0}{2-letter DHS country code}
#'     \item{admin1_name}{Admin 1 region name}
#'     \item{geometry}{MULTIPOLYGON geometry in EPSG:4326}
#'   }
#'
#' @details
#' **GADM vs Natural Earth**: GADM provides more current boundaries for most SSA
#' countries. Natural Earth is used as a fallback when GADM is unavailable.
#'
#' **DHS country code mapping**: Most DHS country codes match ISO 3166-1 alpha-2,
#' but some differ. This function maps DHS codes to ISO codes internally.
#'
#' @export
#' @examples
#' \dontrun{
#' geo <- get_admin1_geo(country_ids = c("KE", "NG"))
#' plot(geo["admin1_name"])
#' }
get_admin1_geo <- function(country_ids = NULL) {

  if (is.null(country_ids)) country_ids <- ssa_codes()

  key <- cache_key("get_admin1_geo", paste(sort(country_ids), collapse = ","))
  cached <- cache_get(key)
  if (!is.null(cached)) return(cached)

  # Try GADM first, with Natural Earth fallback
  gadm_available <- requireNamespace("geodata", quietly = TRUE)
  ne_available <- requireNamespace("rnaturalearth", quietly = TRUE)

  if (!gadm_available && !ne_available) {
    stop("Either 'geodata' (for GADM) or 'rnaturalearth' (for Natural Earth) ",
         "package is required for Admin 1 geometries.\n",
         "Install with: install.packages(c('geodata', 'rnaturalearth'))",
         call. = FALSE)
  }

  # DHS <-> ISO mappings
  dhs_to_iso2 <- .dhs_to_iso_map()
  dhs_to_iso3 <- .dhs_to_iso3_map()

  # Convert DHS codes to ISO codes
  iso2_codes <- vapply(country_ids, function(dhs) {
    if (dhs %in% names(dhs_to_iso2)) dhs_to_iso2[[dhs]] else dhs
  }, character(1), USE.NAMES = FALSE)

  iso3_codes <- vapply(country_ids, function(dhs) {
    if (dhs %in% names(dhs_to_iso3)) dhs_to_iso3[[dhs]] else dhs
  }, character(1), USE.NAMES = FALSE)

  # Reverse mapping: ISO -> DHS
  iso2_to_dhs <- stats::setNames(country_ids, iso2_codes)
  iso3_to_dhs <- stats::setNames(country_ids, iso3_codes)

  # Fetch geometries
  admin1_gadm <- NULL
  admin1_ne <- NULL

  if (gadm_available) {
    tryCatch({
      # Try to fetch from GADM for each country
      gadm_list <- list()
      for (iso3 in iso3_codes) {
        level <- .gadm_level_override(iso3)
        geom <- geodata::gadm(iso3, level = level, path = tempdir())

        if (!is.null(geom) && inherits(geom, "SpatVector")) {
          geom <- sf::st_as_sf(geom)
        } else if (!is.null(geom) && inherits(geom, "SpatialPolygonsDataFrame")) {
          geom <- sf::st_as_sf(geom)
        }
        if (!is.null(geom) && inherits(geom, "sf")) {
          # Normalize column names (GADM returns NAME_1, NAME_2, etc.)
          col_names <- names(geom)
          admin1_col <- if (level == 1) "NAME_1" else "NAME_2"
          if (admin1_col %in% col_names) {
            gadm_list[[iso3]] <- geom |>
              dplyr::transmute(
                iso3 = iso3,
                admin1_name = .data[[admin1_col]],
                geometry = .data$geometry
              )
          }
        }
      }

      if (length(gadm_list) > 0) {
        admin1_gadm <- dplyr::bind_rows(gadm_list)
      }
    }, error = function(e) {
      message("GADM fetch failed (will use Natural Earth): ", e$message)
    })
  }

  if (ne_available && is.null(admin1_gadm)) {
    tryCatch({
      admin1 <- rnaturalearth::ne_download(
        scale = 10,
        type = "admin_1_states_provinces",
        category = "cultural",
        returnclass = "sf"
      )

      admin1_ne <- admin1 |>
        dplyr::filter(.data$iso_a2 %in% iso2_codes) |>
        sf::st_make_valid() |>
        dplyr::transmute(
          iso2 = .data$iso_a2,
          admin1_name = .data$name,
          geometry = .data$geometry
        )
    }, error = function(e) {
      message("Natural Earth fetch failed: ", e$message)
    })
  } else if (!is.null(admin1_gadm)) {
    # Use GADM as primary; no NE fallback needed
    admin1_ne <- NULL
  }

  # Combine GADM (preferred) with NE fallback
  if (!is.null(admin1_gadm) && !is.null(admin1_ne)) {
    # GADM countries
    gadm_iso3 <- unique(admin1_gadm$iso3)
    # Filter NE to non-GADM countries
    admin1_ne <- admin1_ne |>
      dplyr::mutate(iso3 = iso3_to_dhs[.data$iso2]) |>
      dplyr::filter(!.data$iso3 %in% gadm_iso3) |>
      dplyr::select("iso3", "admin1_name", "geometry")

    result <- dplyr::bind_rows(
      admin1_gadm |> dplyr::rename(iso3 = "iso3"),
      admin1_ne
    )
  } else if (!is.null(admin1_gadm)) {
    result <- admin1_gadm |> dplyr::rename(iso3 = "iso3")
  } else if (!is.null(admin1_ne)) {
    result <- admin1_ne |>
      dplyr::mutate(iso3 = iso3_to_dhs[.data$iso2]) |>
      dplyr::select("iso3", "admin1_name", "geometry")
  } else {
    stop("Failed to fetch Admin 1 geometries from GADM or Natural Earth",
         call. = FALSE)
  }

  # Add DHS codes and standardize geometry
  result <- result |>
    dplyr::mutate(
      admin0 = iso3_to_dhs[.data$iso3]
    ) |>
    sf::st_make_valid() |>
    dplyr::transmute(
      admin0 = .data$admin0,
      admin1_name = .data$admin1_name,
      geometry = .data$geometry
    ) |>
    sf::st_transform(4326)

  cache_set(key, result)
  result
}


#' Get Country Boundaries for SSA
#'
#' Fetches country-level (Admin 0) boundary geometries for Sub-Saharan
#' African countries. Used as a basemap layer for DHS visualizations.
#'
#' @param country_ids Character vector of 2-letter DHS country codes.
#'   If NULL (default), uses \code{\link{ssa_codes}()}.
#' @param buffer_countries Logical: if TRUE (default), also includes
#'   bordering countries (North Africa, Middle East) for map context.
#'
#' @return An sf object in EPSG:4326
#' @export
#' @examples
#' \dontrun{
#' borders <- get_admin0_geo()
#' plot(borders["admin0"])
#' }
get_admin0_geo <- function(country_ids = NULL, buffer_countries = TRUE) {
  if (is.null(country_ids)) country_ids <- ssa_codes()

  key <- cache_key("get_admin0_geo", paste(sort(country_ids), collapse = ","),
                    buffer_countries)
  cached <- cache_get(key)
  if (!is.null(cached)) return(cached)

  if (!requireNamespace("rnaturalearth", quietly = TRUE)) {
    stop("'rnaturalearth' package is required.\n",
         "Install it with: install.packages('rnaturalearth')",
         call. = FALSE)
  }

  # DHS code -> ISO alpha-2 mapping
  dhs_to_iso <- .dhs_to_iso_map()
  iso_codes <- vapply(country_ids, function(dhs) {
    if (dhs %in% names(dhs_to_iso)) dhs_to_iso[[dhs]] else dhs
  }, character(1), USE.NAMES = FALSE)

  countries <- rnaturalearth::ne_countries(returnclass = "sf", scale = 50)

  if (buffer_countries) {
    # Include all African countries for basemap context
    result <- countries |>
      dplyr::filter(.data$continent == "Africa") |>
      sf::st_make_valid() |>
      dplyr::transmute(
        admin0 = .data$iso_a2,
        name = .data$name,
        in_ssa = .data$iso_a2 %in% iso_codes,
        geometry = .data$geometry
      )
  } else {
    result <- countries |>
      dplyr::filter(.data$iso_a2 %in% iso_codes) |>
      sf::st_make_valid() |>
      dplyr::transmute(
        admin0 = .data$iso_a2,
        name = .data$name,
        in_ssa = TRUE,
        geometry = .data$geometry
      )
  }

  result <- sf::st_transform(result, 4326)
  cache_set(key, result)
  result
}


# ============================================================================
# DISPLAY SF BUILDER
# ============================================================================

#' Build Display SF for DHS Admin 1 Data
#'
#' Creates an sf object for visualization by joining the DHS panel data
#' to Admin 1 geometries. This is the DHS counterpart of
#' \code{\link{build_display_sf}()}.
#'
#' Since DHS data comes directly at Admin 1 level (no multi-level cascading),
#' this function is simpler than the Eurostat version -- it does a direct join
#' on region names rather than selecting the best NUTS level per country.
#'
#' @param panel Dataframe from \code{\link{cascade_to_admin1}()} or
#'   \code{\link{dhs_pipeline}()}, with columns \code{geo}, \code{admin0},
#'   \code{year}, and indicator columns.
#' @param admin1_geo sf object from \code{\link{get_admin1_geo}()}. If NULL,
#'   fetched automatically using countries present in the panel.
#' @param var Character string of variable to display.
#' @param years Integer vector of years to include. If NULL, uses all available.
#'
#' @return sf object with columns: \code{geo}, \code{admin0}, \code{year},
#'   \code{value}, \code{geometry}
#' @export
#' @examples
#' \dontrun{
#' sf_data <- build_dhs_display_sf(panel, var = "u5_mortality", years = 2020)
#' }
build_dhs_display_sf <- function(panel,
                                  admin1_geo = NULL,
                                  var,
                                  years = NULL) {
  stopifnot(all(c("geo", "admin0", "year", var) %in% names(panel)))

  D <- panel
  if (!is.null(years)) {
    D <- D |> dplyr::filter(.data$year %in% years)
  }

  # Extract value column
  vals <- D |>
    dplyr::transmute(
      geo    = .data$geo,
      admin0 = .data$admin0,
      year   = .data$year,
      value  = .data[[var]]
    ) |>
    dplyr::filter(!is.na(.data$value))

  if (nrow(vals) == 0) {
    warning("No non-NA values for variable: ", var, call. = FALSE)
    return(sf::st_sf(
      geo = character(), admin0 = character(), year = integer(),
      value = numeric(), geometry = sf::st_sfc(crs = 4326)
    ))
  }

  # Fetch geometries if not provided
  if (is.null(admin1_geo)) {
    admin1_geo <- get_admin1_geo(unique(vals$admin0))
  }

  # --- Harmonize names ---
  # Extract DHS region names from geo key
  vals <- vals |>
    dplyr::mutate(.dhs_region = sub("^[A-Z]{2}_", "", .data$geo))

  # Build harmonization table (cached per unique set of regions)
  panel_regions <- vals |>
    dplyr::distinct(.data$admin0, .dhs_region) |>
    dplyr::rename(region_name = ".dhs_region")

  geo_regions <- admin1_geo |>
    sf::st_drop_geometry() |>
    dplyr::select("admin0", "admin1_name")

  harm <- .build_harmonization(panel_regions, geo_regions, geo_sf = admin1_geo)

  # --- Handle composite/dissolve targets ---
  # For regions with is_multi = TRUE, we need to dissolve (union) the constituent geometries
  multi_target_regions <- harm |>
    dplyr::filter(.data$is_multi) |>
    dplyr::distinct(.data$admin0, .data$dhs_region)

  if (nrow(multi_target_regions) > 0) {
    # Build dissolved geometries for each multi-region
    dissolved_list <- list()

    for (i in seq_len(nrow(multi_target_regions))) {
      ctry <- multi_target_regions$admin0[i]
      dhs_reg <- multi_target_regions$dhs_region[i]

      # Get all constituent geo_regions for this DHS region
      constituent_geos <- harm |>
        dplyr::filter(
          .data$admin0 == ctry &
          .data$dhs_region == dhs_reg
        ) |>
        dplyr::pull("geo_region")

      if (length(constituent_geos) > 0) {
        # Extract and dissolve geometries
        constituent_sf <- admin1_geo |>
          dplyr::filter(
            .data$admin0 == ctry &
            .data$admin1_name %in% constituent_geos
          )

        if (nrow(constituent_sf) > 0) {
          dissolved_geom <- constituent_sf |>
            sf::st_union() |>
            sf::st_make_valid()

          # Extract the single sfg geometry from the sfc
          dissolved_sfg <- dissolved_geom[[1]]

          dissolved_list[[length(dissolved_list) + 1]] <- list(
            admin0 = ctry,
            dhs_region = dhs_reg,
            geom = dissolved_sfg
          )
        }
      }
    }

    # Combine dissolved geometries into an sf object
    if (length(dissolved_list) > 0) {
      d_admin0 <- vapply(dissolved_list, `[[`, character(1), "admin0")
      d_region <- vapply(dissolved_list, `[[`, character(1), "dhs_region")
      d_geoms  <- sf::st_sfc(lapply(dissolved_list, `[[`, "geom"), crs = 4326)

      dissolved_geos <- sf::st_sf(
        admin0     = d_admin0,
        dhs_region = d_region,
        geometry   = d_geoms
      )
    } else {
      dissolved_geos <- sf::st_sf(
        admin0     = character(),
        dhs_region = character(),
        geometry   = sf::st_sfc(crs = 4326)
      )
    }

    # Standard geometries (non-multi)
    standard_geos <- harm |>
      dplyr::filter(!.data$is_multi) |>
      dplyr::inner_join(admin1_geo, by = c("admin0", "geo_region" = "admin1_name")) |>
      dplyr::distinct(.data$admin0, .data$dhs_region, .keep_all = TRUE) |>
      dplyr::transmute(
        admin0 = .data$admin0,
        dhs_region = .data$dhs_region,
        geometry = .data$geometry
      ) |>
      sf::st_as_sf()

    # Combine
    all_geos <- dplyr::bind_rows(standard_geos, dissolved_geos)
  } else {
    # No multi-regions, use standard join
    all_geos <- harm |>
      dplyr::filter(!is.na(.data$geo_region)) |>
      dplyr::inner_join(admin1_geo, by = c("admin0", "geo_region" = "admin1_name")) |>
      dplyr::distinct(.data$admin0, .data$dhs_region, .keep_all = TRUE) |>
      dplyr::transmute(
        admin0 = .data$admin0,
        dhs_region = .data$dhs_region,
        geometry = .data$geometry
      ) |>
      sf::st_as_sf()
  }

  # Join data values to geometries
  matched <- vals |>
    dplyr::left_join(
      all_geos |>
        dplyr::transmute(admin0 = .data$admin0, .dhs_region = .data$dhs_region, geometry = .data$geometry),
      by = c("admin0", ".dhs_region")
    ) |>
    dplyr::filter(!is.na(.data$geometry))

  matched |>
    dplyr::select("geo", "admin0", "year", "value", "geometry") |>
    dplyr::distinct(.data$geo, .data$year, .keep_all = TRUE) |>
    sf::st_as_sf()
}


# ============================================================================
# MAP PLOTTING
# ============================================================================

#' Plot DHS Map for Sub-Saharan Africa
#'
#' Creates choropleth maps of DHS indicator data at Admin 1 level across
#' Sub-Saharan Africa. This is the DHS counterpart of
#' \code{\link{plot_best_by_country_level}()}, using EPSG:4326 projection
#' with an Africa bounding box.
#'
#' @param panel Dataframe from \code{\link{cascade_to_admin1}()}.
#' @param admin1_geo sf object from \code{\link{get_admin1_geo}()}. If NULL,
#'   fetched automatically.
#' @param var Character string of variable to plot.
#' @param years Integer vector of years to plot. If NULL, uses most recent year.
#' @param title Optional custom title. If NULL, uses the DHS variable label.
#' @param palette Character: tmap/viridis palette name (default: "viridis").
#' @param n_breaks Integer: number of legend breaks (default: 7).
#' @param breaks Optional custom breaks vector.
#' @param bb_x Numeric vector of longitude limits (default: Africa extent).
#' @param bb_y Numeric vector of latitude limits (default: Africa extent).
#' @param basemap Logical: if TRUE (default), draws country borders as basemap.
#' @param pdf_file Optional PDF filename for output.
#'
#' @return Prints tmap objects for each year (invisibly returns last plot)
#' @export
#' @examples
#' \dontrun{
#' plot_dhs_map(panel, var = "u5_mortality", years = 2020)
#' plot_dhs_map(panel, var = "stunting", years = c(2010, 2015, 2020))
#' }
plot_dhs_map <- function(panel,
                          admin1_geo = NULL,
                          var,
                          years = NULL,
                          title = NULL,
                          palette = "viridis",
                          n_breaks = 7,
                          breaks = NULL,
                          bb_x = c(-18, 52),
                          bb_y = c(-36, 18),
                          basemap = TRUE,
                          pdf_file = NULL) {

  # Default to most recent year
  if (is.null(years)) {
    avail_years <- sort(unique(panel$year[!is.na(panel[[var]])]))
    years <- utils::tail(avail_years, 1)
  }

  # Build display sf
  sf_vals <- build_dhs_display_sf(panel, admin1_geo, var, years)
  if (nrow(sf_vals) == 0) stop("No data to plot for variable: ", var)

  yrs <- sort(unique(sf_vals$year))

  # Fixed breaks across all years
  if (is.null(breaks)) {
    rng <- range(sf_vals$value, na.rm = TRUE)
    if (!is.finite(rng[1]) || !is.finite(rng[2])) stop("No finite values for ", var)
    if (rng[1] == rng[2]) rng <- c(rng[1] - 1e-9, rng[2] + 1e-9)
    breaks <- pretty(rng, n = n_breaks)
  }

  # Title
  labs <- dhs_var_labels()
  title_base <- if (is.null(title)) {
    if (var %in% names(labs)) labs[[var]] else var
  } else {
    title
  }

  # Basemap
  admin0_geo <- if (basemap) {
    get_admin0_geo(unique(panel$admin0))
  } else {
    NULL
  }

  tmap::tmap_mode("plot")

  last_plot <- NULL
  for (yy in yrs) {
    legend_title <- paste0(title_base, " - ", yy)

    # Build plot
    p <- if (!is.null(admin0_geo)) {
      tmap::tm_shape(admin0_geo, bbox = sf::st_bbox(c(
        xmin = bb_x[1], ymin = bb_y[1], xmax = bb_x[2], ymax = bb_y[2]
      ), crs = sf::st_crs(4326))) +
        tmap::tm_polygons(col = "grey95", lwd = 0.5, border.col = "grey80")
    } else {
      tmap::tm_shape(sf_vals |> dplyr::filter(.data$year == yy))
    }

    p <- p +
      tmap::tm_shape(sf_vals |> dplyr::filter(.data$year == yy)) +
      tmap::tm_polygons(
        "value",
        style = "fixed",
        breaks = breaks,
        palette = palette,
        title = legend_title,
        border.col = "white",
        lwd = 0.3,
        legend.show = TRUE
      ) +
      tmap::tm_layout(frame = FALSE)

    print(p)
    last_plot <- p
  }

  if (!is.null(pdf_file)) {
    message("Plotted: ", pdf_file)
  }

  invisible(last_plot)
}


# ============================================================================
# MULTI-VARIABLE SF BUILDER (Tableau Export)
# ============================================================================

#' Build Multi-Variable Display SF for DHS Data
#'
#' Creates a combined sf object with multiple DHS indicators for export
#' to Tableau or other GIS tools. Mirrors \code{\link{build_multi_var_sf}()}
#' for the Eurostat pipeline.
#'
#' @param panel Dataframe from \code{\link{cascade_to_admin1}()}.
#' @param admin1_geo sf object from \code{\link{get_admin1_geo}()}.
#'   If NULL, fetched automatically.
#' @param vars Character vector of indicator names to include.
#'   If NULL, uses all indicators detected from \code{imp_*_flag} columns.
#' @param years Integer vector of years.
#' @param var_labels Optional named character vector for display labels.
#'   If NULL, uses \code{\link{dhs_var_labels}()}.
#' @param domain_mapping Optional named character vector for domain grouping.
#'   If NULL, uses \code{\link{dhs_domain_mapping}()}.
#'
#' @return sf object in EPSG:4326 with columns: geo, admin0, year, var,
#'   value, var_label, domain, geometry
#' @export
#' @examples
#' \dontrun{
#' sf_all <- build_dhs_multi_var_sf(panel,
#'   vars = c("u5_mortality", "stunting", "skilled_birth"))
#' export_to_geojson(sf_all, "ssa_data.geojson")
#' }
build_dhs_multi_var_sf <- function(panel,
                                    admin1_geo = NULL,
                                    vars = NULL,
                                    years = NULL,
                                    var_labels = NULL,
                                    domain_mapping = NULL) {

  # Auto-detect indicators
  if (is.null(vars)) {
    flag_cols <- grep("^imp_(.+)_flag$", names(panel), value = TRUE)
    vars <- sub("^imp_(.+)_flag$", "\\1", flag_cols)
  }

  if (is.null(var_labels)) var_labels <- dhs_var_labels()
  if (is.null(domain_mapping)) domain_mapping <- dhs_domain_mapping()
  if (is.null(years)) years <- sort(unique(panel$year))

  # Filter to requested years
  panel_sub <- panel |> dplyr::filter(.data$year %in% years)

  sf_all <- dplyr::bind_rows(
    lapply(vars, function(v) {
      if (!v %in% names(panel_sub)) return(NULL)

      sf_data <- build_dhs_display_sf(panel_sub, admin1_geo, var = v)

      if (nrow(sf_data) == 0) return(NULL)

      sf_data |>
        dplyr::mutate(
          var       = v,
          var_label = if (v %in% names(var_labels)) var_labels[[v]] else v,
          domain    = if (v %in% names(domain_mapping)) domain_mapping[[v]] else "Other"
        )
    })
  )

  if (nrow(sf_all) == 0) {
    warning("No data matched geometries for any variable", call. = FALSE)
    return(sf::st_sf(
      geo = character(), admin0 = character(), year = integer(),
      value = numeric(), var = character(), var_label = character(),
      domain = character(), geometry = sf::st_sfc(crs = 4326)
    ))
  }

  sf_all |> sf::st_cast("MULTIPOLYGON", warn = FALSE)
}


# ============================================================================
# TABLEAU ENRICHMENT
# ============================================================================

#' Enrich DHS Data for Tableau Export
#'
#' Enriches DHS sf data with country names and domain metadata for
#' Tableau-ready exports. Mirrors \code{\link{enrich_for_tableau}()} for
#' the Eurostat pipeline.
#'
#' @param sf_data sf object from \code{\link{build_dhs_display_sf}()} or
#'   \code{\link{build_dhs_multi_var_sf}()}.
#' @param var_col Name of the variable column (default: "var").
#' @param value_col Name of the value column (default: "value").
#'
#' @return Enriched sf object with country names and performance tags
#' @export
#' @examples
#' \dontrun{
#' sf_enriched <- enrich_dhs_for_tableau(sf_multi)
#' export_to_geojson(sf_enriched, "ssa_tableau.geojson")
#' }
enrich_dhs_for_tableau <- function(sf_data,
                                    var_col = "var",
                                    value_col = "value") {

  result <- sf_data |>
    add_dhs_country_name()

  # Compute country-level performance tags
  if (var_col %in% names(result)) {
    result <- result |>
      dplyr::group_by(.data$country_name, .data$year, .data[[var_col]]) |>
      dplyr::mutate(
        country_avg = mean(.data[[value_col]], na.rm = TRUE)
      ) |>
      dplyr::group_by(.data$year, .data[[var_col]]) |>
      dplyr::mutate(
        country_rank = dplyr::dense_rank(.data$country_avg),
        performance_tag = dplyr::case_when(
          .data[[value_col]] == max(.data[[value_col]], na.rm = TRUE) ~ "Highest",
          .data[[value_col]] == min(.data[[value_col]], na.rm = TRUE) ~ "Lowest",
          TRUE ~ NA_character_
        )
      ) |>
      dplyr::ungroup()
  }

  result
}
