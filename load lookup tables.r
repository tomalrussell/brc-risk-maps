##
## Functions to load geographical lookup tables
##

##
## England and Wales
##
# Output Area to LSOA to MSOA to Local Authority District (December 2017) Lookup with Area Classifications in Great Britain
# source: http://geoportal.statistics.gov.uk/datasets/fe6c55f0924b4734adf1cf7104a0173e_0
load_lookup_lsoa_msoa_lad = function(url = "https://opendata.arcgis.com/datasets/fe6c55f0924b4734adf1cf7104a0173e_0.csv") {
  readr::read_csv(url) %>% 
    dplyr::select(dplyr::starts_with("LSOA"), dplyr::starts_with("MSOA"), dplyr::starts_with("LAD")) %>% 
    dplyr::distinct()
}

# Local Authority District to Fire and Rescue Authority (December 2017) Lookup in England and Wales
# source: https://geoportal.statistics.gov.uk/datasets/local-authority-district-to-fire-and-rescue-authority-december-2017-lookup-in-england-and-wales-
load_lookup_lad_fra = function(url = "https://opendata.arcgis.com/datasets/fcd35bcc7cf64b68abb53a0097105914_0.csv") readr::read_csv(url)

##
## Scotland
##
# Look-up: Data zone to intermediate zone, local authority, health board, multi-member ward, Scottish parliamentary constituency 
# source: https://www2.gov.scot/Topics/Statistics/SIMD/Look-Up
load_lookup_dz_iz_lad = function(url = "https://www2.gov.scot/Resource/0053/00534447.xlsx", sheet_name = "SIMD16 DZ look-up data") {
  httr::GET(url, httr::write_disk(tf <- tempfile(fileext = ".xlsx")))
  
  readxl::read_excel(tf, sheet = sheet_name) %>% 
    dplyr::select(LSOA11CD = DZ, LSOA11NM = DZname, MSOA11CD = IZcode, MSOA11NM = IZname, LAD17CD = LAcode, LAD17NM = LAname) %>% 
    dplyr::distinct()
}

##
## Northern Ireland
##
# Small Areas (2011) to SOAs to Local Government Districts (December 2018) Lookup with Area Classifications in Northern Ireland
# source: https://geoportal.statistics.gov.uk/datasets/small-areas-2011-to-soas-to-local-government-districts-december-2018-lookup-with-area-classifications-in-northern-ireland
load_lookup_sa_lgd = function(url = "https://opendata.arcgis.com/datasets/096a7ccbc8e244cc972189b2f07a321a_0.csv") read_csv(url)

##
## function to look up country name from LSOA/MSOA/LAD/FRA code
##
get_country = function(code) {
  case_when(
    str_sub(code, 1, 1) == "E" ~ "England",
    str_sub(code, 1, 1) == "W" ~ "Wales",
    str_sub(code, 1, 1) == "S" ~ "Scotland",
    str_sub(code, 1, 1) %in% c("N", "9") ~ "Northern Ireland",
    TRUE ~ ""
  )
}