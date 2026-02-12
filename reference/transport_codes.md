# Transport Dataset Codes

Returns a named vector of Eurostat regional transport dataset codes
covering road, rail, air, and maritime transport infrastructure and
traffic at NUTS 2 level.

## Usage

``` r
transport_codes()
```

## Value

Named character vector of dataset codes

## Examples

``` r
transport_codes()
#>  road_rail_waterway            vehicles      road_accidents maritime_passengers 
#>        "tran_r_net"      "tran_r_vehst"       "tran_r_acci"    "tran_r_mapa_nm" 
#>    maritime_freight      air_passengers         air_freight     rail_goods_load 
#>    "tran_r_mago_nm"    "tran_r_avpa_nm"    "tran_r_avgo_nm"       "tran_r_rago" 
#>     rail_passengers road_goods_journeys 
#>       "tran_r_rapa"   "tran_r_veh_jour" 
names(transport_codes())
#>  [1] "road_rail_waterway"  "vehicles"            "road_accidents"     
#>  [4] "maritime_passengers" "maritime_freight"    "air_passengers"     
#>  [7] "air_freight"         "rail_goods_load"     "rail_passengers"    
#> [10] "road_goods_journeys"
```
