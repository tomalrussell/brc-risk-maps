##
## Health life expectancy at birth data
## - whole UK: https://www.ons.gov.uk/peoplepopulationandcommunity/healthandsocialcare/healthandlifeexpectancies/datasets/healthstatelifeexpectancyatbirthandatage65bylocalareasuk
## - this file contains LADs, counties and other geographies - split them into separate files
##
##
library(tidyverse)
library(readxl)
library(httr)

source("init.r")

##
## download data
##
GET("https://www.ons.gov.uk/file?uri=%2fpeoplepopulationandcommunity%2fhealthandsocialcare%2fhealthandlifeexpectancies%2fdatasets%2fhealthstatelifeexpectancyatbirthandatage65bylocalareasuk%2fcurrent/hsleatbirthandatage65byukla201618.xlsx",
    write_disk(tf <- tempfile(fileext = ".xlsx")))

##
## load data
##
hle_birth_male = read_excel(tf, sheet = "HE - Male at birth", skip = 3) %>% 
  select(lad17cd = `Area Codes`, HLE_birth_male = HLE) %>% 
  fill(HLE_birth_male) %>% 
  na.omit()

hle_birth_female = read_excel(tf, sheet = "HE - Female at birth", skip = 3) %>% 
  select(lad17cd = `Area Codes`, HLE_birth_female = HLE) %>% 
  fill(HLE_birth_female) %>% 
  na.omit()

hle_65_male = read_excel(tf, sheet = "HE - Male at 65", skip = 3) %>% 
  select(lad17cd = `Area Codes`, HLE_65_male = HLE) %>% 
  fill(HLE_65_male) %>% 
  na.omit()

hle_65_female = read_excel(tf, sheet = "HE - Female at 65", skip = 3) %>% 
  select(lad17cd = `Area Codes`, HLE_65_female = HLE) %>% 
  fill(HLE_65_female) %>% 
  na.omit()

# combine and take average of HLEs
hle = hle_birth_male %>% 
  left_join(hle_birth_female, by = "lad17cd") %>% 
  left_join(hle_65_male,      by = "lad17cd") %>% 
  left_join(hle_65_female,    by = "lad17cd") %>% 
  
  mutate(HLE_birth = rowMeans(select(., HLE_birth_male, HLE_birth_female))) %>% 
  mutate(HLE_65    = rowMeans(select(., HLE_65_male, HLE_65_female)))

# keep only rows with valid codes (the rest are footnotes)
hle = hle %>% 
  filter(str_detect(lad17cd, "[A-Z][0-9]+"))

##
## `hle` contains a mix of counties and local authorities - split these into separate dataframes and save
##
county_codes = c("E10", "E11")  # counties and Met counties

country_codes = c(
  "K02000001",  # whole UK
  "E92000001",  # England
  "W92000004",  # Wales
  "S92000003",  # Scotland
  "N92000002"   # NI
)

region_codes = "E12"  # England regions

# save counties
hle %>% 
  filter(str_sub(lad17cd, 1, 3) %in% county_codes) %>% 
  rename(CountyCode = lad17cd) %>% 
  write_csv(file.path(data.dir.processed, "Healthy life expectancy - Counties - whole UK.csv"))

# save local authorities
hle %>% 
  filter(!str_sub(lad17cd, 1, 3) %in% c(county_codes, region_codes)) %>% 
  filter(!lad17cd %in% country_codes) %>% 
  write_csv(file.path(data.dir.processed, "Healthy life expectancy - Local Authorities - whole UK.csv"))

unlink(tf)
