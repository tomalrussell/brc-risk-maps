##
## Prepare risk data by nation - for each country, give the:
## - risk indicator
## - domain (overall inequality, deprivation decile or rural/urban classification)
## - value
##
## Also calculate a summary table with a measure of inequality:
## - absolute difference between most and least deprived
## - or inequality range/gap for rural/urban classification
##
library(tidyverse)
library(janitor)
library(brclib)

# for stats models
library(broom)
library(rstanarm)
library(loo)

source("init.r")
source("load lookup tables.r")


###############################################################################
## Load risk data
##
risk_eng_msoa = read_csv(file.path(data.dir.out, "England - MSOA - risks.csv"))
risk_wal_msoa = read_csv(file.path(data.dir.out, "Wales - MSOA - risks.csv"))
risk_sco_msoa = read_csv(file.path(data.dir.out, "Scotland - MSOA - risks.csv"))
risk_ni_lsoa  = read_csv(file.path(data.dir.out, "NI - LSOA - risks.csv"))

risk_eng_lad = read_csv(file.path(data.dir.out, "England - LAD - risks.csv"))
risk_wal_lad = read_csv(file.path(data.dir.out, "Wales - LAD - risks.csv"))
risk_sco_lad = read_csv(file.path(data.dir.out, "Scotland - LAD - risks.csv"))
risk_ni_lad  = read_csv(file.path(data.dir.out, "NI - LAD - risks.csv"))

risk_wal_fra = read_csv(file.path(data.dir.out, "Wales - FRA - risks.csv"))


###############################################################################
## Load lookups - LSOA, MSOA, LAD, FRA
##
lookup_dz_iz_lad = load_lookup_dz_iz_lad()
lookup_lad_fra = load_lookup_lad_fra()
lookup_lsoa_msoa_lad = load_lookup_lsoa_msoa_lad()
lookup_sa_lgd = load_lookup_sa_lgd()

# make lookup table with LSOA and MSOA codes (doesn't include NI because there's no equivalent to MSOAs)
lookup_uk_lsoa_msoa = bind_rows(
  # England and Wales
  lookup_lsoa_msoa_lad %>% 
    select(LSOA11CD, MSOA11CD) %>% 
    distinct(),
  
  # Scotland
  lookup_dz_iz_lad %>% 
    select(LSOA11CD, MSOA11CD) %>% 
    distinct()
)

# make lookup table with LSOA and LAD codes
lookup_uk_lsoa_lad = bind_rows(
  # England and Wales
  lookup_lsoa_msoa_lad %>% 
    select(LSOA11CD, LAD17CD) %>% 
    distinct(),
  
  # Scotland
  lookup_dz_iz_lad %>% 
    select(LSOA11CD, LAD17CD) %>% 
    distinct(),
  
  # NI
  lookup_sa_lgd %>% 
    select(LSOA11CD, LAD17CD = LAD18CD) %>% 
    distinct()
)

# make lookup table with LSOA and FRA codes
lookup_uk_lsoa_fra = lookup_uk_lsoa_lad %>% 
  left_join(lookup_lad_fra, by = "LAD17CD") %>% 
  select(LSOA11CD, FRA17CD) %>% 
  distinct()


###############################################################################
## Summarise deprivation by MSOA, LAD, and FRA
## = % of LSOAs in each geography in the top 10% most deprived, split into quintiles
##
imd_lsoa = load_IMD()

##
## MSOA
##
imd_msoa = imd_lsoa %>% 
  # lookup MSOAs for each LSOA
  select(LSOA, IMD_decile) %>% 
  left_join(lookup_uk_lsoa_msoa, by = c("LSOA" = "LSOA11CD")) %>% 
  
  # add Northern Ireland's LSOAs as if they're MSOAs
  bind_rows(imd_lsoa %>% filter(startsWith(LSOA, "9")) %>% mutate(MSOA11CD = LSOA)) %>% 
  
  # label deciles by whether they're in top 10 then summarise by this label
  mutate(IMD_top10 = ifelse(IMD_decile <= 2, "Top10", "Other")) %>% 
  janitor::tabyl(MSOA11CD, IMD_top10) %>% 
  
  # calculate proportion of most deprived LSOAs
  mutate(Prop_top10 = Top10 / (Top10 + Other)) %>% 
  
  mutate(Country = get_country(MSOA11CD)) %>% 
  na.omit()

# need to calculate deciles separately and merge into dataframe
imd_msoa_e = imd_msoa %>% 
  filter(Country == "England") %>% 
  select(MSOA11CD, Prop_top10) %>% 
  add_risk_quantiles("Prop_top10", quants = 10)

imd_msoa_w = imd_msoa %>% 
  filter(Country == "Wales") %>% 
  select(MSOA11CD, Prop_top10) %>% 
  add_risk_quantiles("Prop_top10", quants = 10)

imd_msoa_s = imd_msoa %>% 
  filter(Country == "Scotland") %>% 
  select(MSOA11CD, Prop_top10) %>% 
  add_risk_quantiles("Prop_top10", quants = 10)

imd_msoa_n = imd_msoa %>% 
  filter(Country == "Northern Ireland") %>% 
  select(MSOA11CD, Prop_top10) %>% 
  add_risk_quantiles("Prop_top10", quants = 10)

# merge quantiles into imd_msoa
imd_msoa = imd_msoa %>% 
  select(-Prop_top10) %>% 
  left_join(
    bind_rows(imd_msoa_e, imd_msoa_w, imd_msoa_s, imd_msoa_n),
    by = "MSOA11CD"
  )

##
## LAD
##
imd_lad = imd_lsoa %>% 
  # lookup LADs for each LSOA
  select(LSOA, IMD_decile) %>% 
  left_join(lookup_uk_lsoa_lad, by = c("LSOA" = "LSOA11CD")) %>% 
  
  # label deciles by whether they're in top 10 then summarise by this label
  mutate(IMD_top10 = ifelse(IMD_decile <= 2, "Top10", "Other")) %>% 
  janitor::tabyl(LAD17CD, IMD_top10) %>% 
  
  # calculate proportion of most deprived LSOAs
  mutate(Prop_top10 = Top10 / (Top10 + Other)) %>% 
  
  mutate(Country = get_country(LAD17CD))
  
  # calculate deciles for higher-level geography within nations
  # group_by(Country) %>% 
  # add_risk_quantiles("Prop_top10", quants = 10) %>% 
  # ungroup()

# need to calculate deciles separately and merge into dataframe
imd_lad_e = imd_lad %>% 
  filter(Country == "England") %>% 
  select(LAD17CD, Prop_top10) %>% 
  add_risk_quantiles("Prop_top10", quants = 10)

imd_lad_w = imd_lad %>% 
  filter(Country == "Wales") %>% 
  select(LAD17CD, Prop_top10) %>% 
  add_risk_quantiles("Prop_top10", quants = 10)

imd_lad_s = imd_lad %>% 
  filter(Country == "Scotland") %>% 
  select(LAD17CD, Prop_top10) %>% 
  add_risk_quantiles("Prop_top10", quants = 10)

imd_lad_n = imd_lad %>% 
  filter(Country == "Northern Ireland") %>% 
  select(LAD17CD, Prop_top10) %>% 
  add_risk_quantiles("Prop_top10", quants = 10)

# merge quantiles into imd_lad
imd_lad = imd_lad %>% 
  select(-Prop_top10) %>% 
  left_join(
    bind_rows(imd_lad_e, imd_lad_w, imd_lad_s, imd_lad_n),
    by = "LAD17CD"
  )

##
## FRA
##
imd_fra = imd_lsoa %>% 
  # lookup FRAs for each LSOA
  select(LSOA, IMD_decile) %>% 
  left_join(lookup_uk_lsoa_fra, by = c("LSOA" = "LSOA11CD")) %>% 
  
  # label deciles by whether they're in top 10 then summarise by this label
  mutate(IMD_top10 = ifelse(IMD_decile <= 2, "Top10", "Other")) %>% 
  janitor::tabyl(FRA17CD, IMD_top10) %>% 
  
  # calculate proportion of most deprived LSOAs
  mutate(Prop_top10 = Top10 / (Top10 + Other)) %>% 
  
  mutate(Country = get_country(FRA17CD)) %>% 
  
  filter(Country == "Wales") %>%  # we only have FRA-level data for Wales
  
  # calculate deciles for higher-level geography within nations
  group_by(Country) %>% 
  add_risk_quantiles("Prop_top10", quants = 10) %>% 
  ungroup()


###############################################################################
## Load rural-urban classifications
## - these files were created by the code in https://github.com/mattmalcher/IndexOfNeed/tree/master/Datasets/Rural-Urban%20Classifications
## - for details of what the classification codes mean, see: https://github.com/mattmalcher/IndexOfNeed/blob/master/Datasets/Rural-Urban%20Classifications/rural-urban%20classification%20codes.md
##
ruc_ew  = read_csv(file.path(data.dir.in, "rural-urban", "RUC England Wales - LSOA.csv"))
ruc_sco = read_csv(file.path(data.dir.in, "rural-urban", "RUC Scotland - DZ.csv"))
ruc_ni  = read_csv(file.path(data.dir.in, "rural-urban", "RUC Northern Ireland - SOA.csv"))

# dichotomise detailed classifications into rural or urban
ruc_ew = ruc_ew %>% 
  select(LSOA11CD, RUC11CD) %>% 
  mutate(RUC = case_when(
    RUC11CD %in% c("A1", "B1", "C1", "C2") ~ "Urban",
    RUC11CD %in% c("D1", "D2", "E1", "E2", "F1", "F2") ~ "Rural"
  ))

ruc_sco = ruc_sco %>% 
  select(LSOA11CD = DZ_CODE, UR2FOLD) %>% 
  mutate(RUC = ifelse(UR2FOLD == 1, "Urban", "Rural"))

# need to do something slightly different for NI, since they have a 'mixed' category - but conveniently they count how many of each category are in each LSOA
ruc_ni = ruc_ni %>% 
  select(LSOA11CD = `SOA Code`, Urban, Mixed = `mixed urban/rural`, Rural) %>% 
  mutate(Urban = replace_na(as.integer(Urban), 0),
         Mixed = replace_na(as.integer(Mixed), 0),
         Rural = replace_na(as.integer(Rural), 0))

##
## summarise into MSOAs, calculating proportions of urban versus rural areas in each
## - count the number of urban and rural (and mixed, in NI) LSOAs in each MSOA
## - calculate the proportion of urban LSOAs
## - categorise into three quantiles
##
# England
ruc_eng_msoa = ruc_ew %>% 
  filter(startsWith(LSOA11CD, "E")) %>%
  left_join(lookup_uk_lsoa_msoa, by = "LSOA11CD") %>% 
  
  tabyl(MSOA11CD, RUC) %>% 
  mutate(Prop_Urban = Urban / (Urban + Rural)) %>% 
  add_risk_quantiles("Prop_Urban", quants = 3) %>% 
  
  select(MSOA11CD, Prop_Urban, Prop_Urban_q, Prop_Urban_q_name)

# Wales
ruc_wal_msoa = ruc_ew %>% 
  filter(startsWith(LSOA11CD, "W")) %>%
  left_join(lookup_uk_lsoa_msoa, by = "LSOA11CD") %>% 
  
  tabyl(MSOA11CD, RUC) %>% 
  mutate(Prop_Urban = Urban / (Urban + Rural)) %>% 
  add_risk_quantiles("Prop_Urban", quants = 3) %>% 
  
  select(MSOA11CD, Prop_Urban, Prop_Urban_q, Prop_Urban_q_name)

# Scotland
ruc_sco_msoa = ruc_sco %>% 
  left_join(lookup_uk_lsoa_msoa, by = "LSOA11CD") %>% 
  
  tabyl(MSOA11CD, RUC) %>% 
  mutate(Prop_Urban = Urban / (Urban + Rural)) %>% 
  add_risk_quantiles("Prop_Urban", quants = 3) %>% 
  
  select(MSOA11CD, Prop_Urban, Prop_Urban_q, Prop_Urban_q_name)

# NI
ruc_ni_lsoa = ruc_ni %>%
  mutate(Prop_Urban = (Urban + (Mixed / 2)) / (Urban + Mixed + Rural)) %>%   # ARBITRARY DECISION: counting half the mixed LSOAs as urban
  add_risk_quantiles("Prop_Urban", quants = 3) %>% 
  
  select(MSOA11CD = LSOA11CD, Prop_Urban, Prop_Urban_q, Prop_Urban_q_name)

# stitch these into a UK-wide dataframe
ruc_uk_msoa = bind_rows(ruc_eng_msoa, ruc_wal_msoa, ruc_sco_msoa, ruc_ni_lsoa)


##
## summarise into Local Authorities, calculating proportions of urban versus rural areas in each
## - count the number of urban and rural (and mixed, in NI) LSOAs in each LAD
## - calculate the proportion of urban LSOAs
## - categorise into three quantiles
##
# England
ruc_eng_lad = ruc_ew %>% 
  filter(startsWith(LSOA11CD, "E")) %>%
  left_join(lookup_uk_lsoa_lad, by = "LSOA11CD") %>% 
  
  tabyl(LAD17CD, RUC) %>% 
  mutate(Prop_Urban = Urban / (Urban + Rural)) %>% 
  add_risk_quantiles("Prop_Urban", quants = 3) %>% 
  
  select(LAD17CD, Prop_Urban, Prop_Urban_q, Prop_Urban_q_name)

# Wales
ruc_wal_lad = ruc_ew %>% 
  filter(startsWith(LSOA11CD, "W")) %>%
  left_join(lookup_uk_lsoa_lad, by = "LSOA11CD") %>% 
  
  tabyl(LAD17CD, RUC) %>% 
  mutate(Prop_Urban = Urban / (Urban + Rural)) %>% 
  add_risk_quantiles("Prop_Urban", quants = 3) %>% 
  
  select(LAD17CD, Prop_Urban, Prop_Urban_q, Prop_Urban_q_name)

# Scotland
ruc_sco_lad = ruc_sco %>% 
  left_join(lookup_uk_lsoa_lad, by = "LSOA11CD") %>% 
  
  tabyl(LAD17CD, RUC) %>% 
  mutate(Prop_Urban = Urban / (Urban + Rural)) %>% 
  add_risk_quantiles("Prop_Urban", quants = 3) %>% 
  
  select(LAD17CD, Prop_Urban, Prop_Urban_q, Prop_Urban_q_name)

# NI
ruc_ni_lad = ruc_ni %>% 
  left_join(lookup_uk_lsoa_lad, by = "LSOA11CD") %>% 
  
  group_by(LAD17CD) %>% 
  summarise(Urban = sum(Urban),
            Mixed = sum(Mixed),
            Rural = sum(Rural)) %>% 
  
  mutate(Prop_Urban = (Urban + (Mixed / 2)) / (Urban + Mixed + Rural)) %>%   # ARBITRARY DECISION: counting half the mixed LSOAs as urban
  add_risk_quantiles("Prop_Urban", quants = 3) %>% 
  
  select(LAD17CD, Prop_Urban, Prop_Urban_q, Prop_Urban_q_name)

# stitch these into a UK-wide dataframe
ruc_uk_lad = bind_rows(ruc_eng_lad, ruc_wal_lad, ruc_sco_lad, ruc_ni_lad)

# get categories (to write as a note on Power BI dashboard)
unique(ruc_eng_lad$Prop_Urban_q_name)
unique(ruc_wal_lad$Prop_Urban_q_name)
unique(ruc_sco_lad$Prop_Urban_q_name)
unique(ruc_ni_lad$Prop_Urban_q_name)


###############################################################################
## Calculate inequalities for each indicator in each nation - for Local Authorities
##
risk_uk_lad = bind_rows(
  risk_eng_lad %>% select(LAD17CD, Sec95, destitution_migrant, HLE_birth, digital_total_mult, destitution_all,  # LAD-level risks
                          worst_fires, worst_floods, worst_lonely, worst_alone),  # MSOA-level risks
  
  risk_wal_lad %>% select(LAD17CD, Sec95, destitution_migrant, HLE_birth, digital_total_mult, destitution_all,  # LAD-level risks
                          worst_floods, worst_lonely, worst_alone),  # MSOA-level risks
  
  risk_sco_lad %>% select(LAD17CD, Sec95, destitution_migrant, HLE_birth, digital_total_mult, destitution_all,  # LAD-level risks
                          worst_fires, worst_lonely, worst_alone),  # MSOA-level risks
  
  risk_ni_lad  %>% select(LAD17CD = LAD18CD, Sec95, HLE_birth, digital_total_mult,  # LAD-level risks
                          worst_floods, worst_lonely, worst_alone)  # MSOA-level risks
)

# merge indicators, IMD and RUC
uk_lad = risk_uk_lad %>% 
  left_join(imd_lad, by = "LAD17CD") %>%   # merge deprivation summary
  left_join(ruc_uk_lad, by = "LAD17CD") %>% 
  
  select(-Other, -Top10, -Prop_top10_q_name) %>% 
  rename(Deprivation = Prop_top10_q, `Rural-urban classification` = Prop_Urban_q)

# summarise each indicator within countries and domains (most need to report the max. value, but...
# ... Health Life Expectancy should report min. (i.e. lowest HLE))
sum_uk_lad = uk_lad %>% 
  pivot_longer(cols = c(Deprivation, `Rural-urban classification`), names_to = "Domain", values_to = "Domain Value") %>%  # convert to long format

  group_by(Country, Domain, `Domain Value`) %>% 
  summarise(
    # LAD-level indicators
    `Asylum seekers receiving support` = max(Sec95, na.rm = T),
    `Migrant destitution` = max(destitution_migrant, na.rm = T),
    `Healthy life expectancy` = min(HLE_birth, na.rm = T),
    `Digital exclusion` = max(digital_total_mult, na.rm = T),
    Destitution = max(destitution_all, na.rm = T),
    
    # already-summarised MSOA-level indicators
    `Dwelling fires` = max(worst_fires, na.rm = T),
    `Flooding` = max(worst_floods, na.rm = T),
    `Loneliness` = max(worst_lonely, na.rm = T),
    `Living alone` = max(worst_alone, na.rm = T)
  ) %>% 
  ungroup() %>% 
  
  # pivot indicator columns into long format
  pivot_longer(cols = `Asylum seekers receiving support`:`Living alone`, names_to = "Indicator", values_to = "Indicator Value") %>% 
  
  # select(Country, LAD17CD, Domain, `Domain Value`, Prop_top10, Prop_Urban, Indicator, `Indicator Value`) %>% 
  arrange(Country, Domain, `Domain Value`)

##
## summarise into country-level inequalities
##
# difference between worst versus best outcomes
sum_uk = sum_uk_lad %>% 
  group_by(Country, Domain, Indicator) %>% 
  summarise(max = max(`Indicator Value`, na.rm = T),
            min = min(`Indicator Value`, na.rm = T),
            diff = abs(max - min)) %>% 
  ungroup()

##
## calculate mean difference between outcome in most-deprived geography versus least-deprived geographies (and most-urban versus least-urban)
##
# deprivation
sum_uk_dep = sum_uk_lad %>% 
  filter(Domain == "Deprivation", `Domain Value` %in% c(1, 10)) %>% 
  
  # calculate mean values for indicators in most and least deprived areas
  group_by(Country, Domain, `Domain Value`, Indicator) %>% 
  summarise(mean = mean(`Indicator Value`, na.rm = T)) %>% 
  
  # make the mean deprivation scores columns and calculate the absolute difference
  pivot_wider(names_from = `Domain Value`, names_prefix = "Dep_", values_from = mean) %>% 
  mutate(mean_diff = abs(Dep_1 - Dep_10)) %>% 
  
  ungroup() %>% 
  select(-Dep_1, -Dep_10)
  
# rural-urban classification
sum_uk_urb = sum_uk_lad %>% 
  filter(Domain == "Rural-urban classification", `Domain Value` %in% c(1, 3)) %>% 
  
  # calculate mean values for indicators in most and least deprived areas
  group_by(Country, Domain, `Domain Value`, Indicator) %>% 
  summarise(mean = mean(`Indicator Value`, na.rm = T)) %>% 
  
  # make the mean deprivation scores columns and calculate the absolute difference
  pivot_wider(names_from = `Domain Value`, names_prefix = "Urb_", values_from = mean) %>% 
  mutate(mean_diff = abs(Urb_1 - Urb_3)) %>% 
  
  ungroup() %>% 
  select(-Urb_1, -Urb_3)

# merge mean differences into 
sum_uk = sum_uk %>% 
  left_join(bind_rows(sum_uk_dep, sum_uk_urb), 
            by = c("Country", "Domain", "Indicator"))

##
## save
##
write_csv(sum_uk, file.path(data.dir.out, "Risks - nations - summary.csv"))
write_csv(sum_uk_lad, file.path(data.dir.out, "Risks - nations.csv"))

# output a list of indicators in the current dataset
sum_uk_lad %>%
  select(Indicator) %>% 
  distinct() %>% 
  arrange(Indicator) %>% 
  write_csv(file.path(data.dir.out, "Risks - nations - indicators.csv"))


###############################################################################
## Calculate inequalities for each indicator in each nation - for MSOAs
##
risk_uk_msoa = bind_rows(
  risk_eng_msoa %>% select(MSOA11CD, n_fires, n_people_flood, loneills_2018, prop_alone),
  risk_wal_msoa %>% select(MSOA11CD, n_people_flood, loneills_2018, prop_alone),
  risk_sco_msoa %>% select(MSOA11CD, n_fires, loneills_2018, prop_alone),
  risk_ni_lsoa  %>% select(MSOA11CD = LSOA11CD, n_people_flood, loneills_2018, prop_alone)
)

# merge indicators, IMD and RUC
uk_msoa = risk_uk_msoa %>% 
  left_join(imd_msoa, by = "MSOA11CD") %>%   # merge deprivation summary
  left_join(ruc_uk_msoa, by = "MSOA11CD") %>% 
  
  select(-Other, -Top10, -Prop_top10_q_name) %>% 
  
  rename(Deprivation = Prop_top10_q, `Rural-urban classification` = Prop_Urban_q)
  # pivot_longer(cols = c(Deprivation, `Rural-urban classification`), names_to = "Domain", values_to = "Domain Value")


###############################################################################
## Analyse healthy life expectancy
##
# make dataset for analysis
uk_lad_hle = uk_lad %>% 
  select(Country, LAD17CD, Deprivation, Prop_top10, RUC = `Rural-urban classification`, Prop_Urban, HLE_birth) %>% 
  na.omit()

##
## descriptive stats
##
# histograms of HLE by country
uk_lad_hle %>% 
  ggplot(aes(x = HLE_birth, fill = Country)) +
  geom_histogram(binwidth = 1) +
  facet_wrap(~Country, scales = "free_y")

# summary stats by country
tapply(uk_lad_hle$HLE_birth, uk_lad_hle$Country, summary)
tapply(uk_lad_hle$Prop_top10, uk_lad_hle$Country, summary)
tapply(uk_lad_hle$Prop_Urban, uk_lad_hle$Country, summary)

# range of HLE in least-deprived LADs
uk_lad_hle %>% 
  filter(Prop_top10 == 0 & Country == "England") %>% 
  summarise(min(HLE_birth), max(HLE_birth))

# range of HLE in most-urban LADs
uk_lad_hle %>% 
  filter(Prop_Urban == 1 & Country == "England") %>% 
  summarise(min(HLE_birth), max(HLE_birth))

##
## how does average HLE vary across nations?
##
# median/sd HLE across countries
uk_lad_hle %>% 
  group_by(Country) %>% 
  summarise(HLE_med = median(HLE_birth, na.rm = T),
            HLE_sd  = sd(HLE_birth, na.rm = T)) %>% 
  
  mutate(HLE_sd = replace_na(HLE_sd, 0)) %>% 
  
  ggplot(aes(x = Country, y = HLE_med, colour = Country)) +
  geom_pointrange(aes(ymin = HLE_med - HLE_sd, ymax = HLE_med + HLE_sd), show.legend = F) +
  
  theme_classic() +
  labs(y = "Healthy life expectancy at birth (years)\n", x = NULL, colour = NULL) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave("plots/nations/hle - country.png", width = 100, height = 110, units = "mm")

# model average HLE across nations
(m_hle = tidy(lm(HLE_birth ~ Country, data = uk_lad_hle), conf.int = T))

m_hle$conf.high * 12  # convert proportions of a year to months

##
## how does HLE differ between deprivation and nations (non-spatial)?
##
m_hle_dep = lm(HLE_birth ~ Prop_top10 * Country, data = uk_lad_hle)

plot(m_hle_dep)  # check residuals etc.
glance(m_hle_dep)  # look at model fit etc.

tidy(m_hle_dep, conf.int = T)

# Bayesian version
m_hle_dep = stan_glm(HLE_birth ~ Prop_top10 * Country, 
                             data = uk_lad_hle,
                             prior_intercept = normal(0, 5), prior = normal(0, 5),
                             adapt_delta = 0.99, chains = 4)

# plot coefficients
plot(m_hle_dep)

tidy(m_hle_dep, conf.int = T)

# plot model predictions for proportion of deprivation and country on HLE
new.data = expand_grid(
  Country = unique(uk_lad_hle$Country),
  Prop_top10 = seq(0, 1, by = 0.01)
)

post = posterior_predict(m_hle_dep, newdata = new.data)
pred = posterior_linpred(m_hle_dep, newdata = new.data)

quants = apply(post, 2, quantile, probs = c(0.025, 0.5, 0.975))  # quantiles over mcmc samples
quants2 = apply(pred, 2, quantile, probs = c(0.025, 0.5, 0.975))  # quantiles over mcmc samples
row.names(quants) = c("sim.lwr", "sim.med", "sim.upr")
row.names(quants2) = c("lwr", "HLE_birth.pred", "upr")

new.data = cbind(new.data, t(quants), t(quants2))

ggplot(new.data, aes(x = Prop_top10, y = HLE_birth.pred)) +
  geom_point(data = uk_lad_hle, aes(y = HLE_birth), alpha = 0.2) +
  geom_ribbon(aes(ymin = lwr, ymax = upr, fill = Country), alpha = 0.4, show.legend = F) +
  geom_line(aes(colour = Country), lwd = 1.5, show.legend = F) +
  
  facet_wrap(~Country) +
  
  scale_color_brewer(palette = "Accent") +
  scale_fill_brewer(palette = "Accent") +
  scale_x_continuous(labels = scales::percent) +
  scale_y_continuous(breaks = seq(40, 70, by = 5)) +
  
  labs(y = "Healthy life expectancy at birth (years)\n", x = "\nProportion of highly deprived neighbourhoods in a Local Authority") +
  theme_classic()

ggsave("plots/nations/hle - deprivation.png", width = 175, height = 150, units = "mm")

##
## how does HLE differ between urban/rural and nations (non-spatial)?
##
# m_hle_ruc = lm(HLE_birth ~ Prop_Urban * Country, data = uk_lad_hle)
# 
# plot(m_hle_ruc)  # check residuals etc.
# glance(m_hle_ruc)  # look at model fit etc.
# 
# tidy(m_hle_ruc, conf.int = T)

# Bayesian version
m_hle_ruc = stan_glm(HLE_birth ~ Prop_Urban * Country, 
                     data = uk_lad_hle,
                     prior_intercept = normal(0, 5), prior = normal(0, 5),
                     adapt_delta = 0.99, chains = 4)

# plot coefficients
plot(m_hle_ruc)

# plot model predictions for proportion of deprivation and country on HLE
new.data = expand_grid(
  Country = unique(uk_lad_hle$Country),
  Prop_Urban = seq(0, 1, by = 0.01)
)

post = posterior_predict(m_hle_ruc, newdata = new.data)
pred = posterior_linpred(m_hle_ruc, newdata = new.data)

quants = apply(post, 2, quantile, probs = c(0.025, 0.5, 0.975))  # quantiles over mcmc samples
quants2 = apply(pred, 2, quantile, probs = c(0.025, 0.5, 0.975))  # quantiles over mcmc samples
row.names(quants) = c("sim.lwr", "sim.med", "sim.upr")
row.names(quants2) = c("lwr", "HLE_birth.pred", "upr")

new.data = cbind(new.data, t(quants), t(quants2))

ggplot(new.data, aes(x = Prop_Urban, y = HLE_birth.pred)) +
  geom_point(data = uk_lad_hle, aes(y = HLE_birth), alpha = 0.2) +
  geom_ribbon(aes(ymin = lwr, ymax = upr, fill = Country), alpha = 0.4, show.legend = F) +
  geom_line(aes(colour = Country), lwd = 1.5, show.legend = F) +
  
  facet_wrap(~Country) +
  
  scale_color_brewer(palette = "Accent") +
  scale_fill_brewer(palette = "Accent") +
  scale_x_continuous(labels = scales::percent) +
  scale_y_continuous(breaks = seq(40, 70, by = 5)) +
  
  labs(y = "Healthy life expectancy at birth (years)\n", x = "\nProportion of urban neighbourhoods in a Local Authority") +
  theme_classic()

ggsave("plots/nations/hle - rural urban.png", width = 175, height = 150, units = "mm")

##
## Interaction between deprivation and urban
##
m_hle_both = stan_glm(HLE_birth ~ Prop_top10 * Prop_Urban * Country, 
                      data = uk_lad_hle,
                      prior_intercept = normal(0, 5), prior = normal(0, 5),
                      adapt_delta = 0.99, chains = 4)

# see whether the full interaction model fits best, or whether it's better to report deprivation and RUC separately
loo_m_hle_dep = loo(m_hle_dep)
loo_m_hle_ruc = loo(m_hle_ruc)
loo_m_hle_both = loo(m_hle_both)

loo_compare(loo_m_hle_dep, loo_m_hle_ruc, loo_m_hle_both)  #--> deprivation model fits best - report them separately

# plot coefficients
plot(m_hle_both)

# plot model predictions for proportion of deprivation and country on HLE
new.data = expand_grid(
  Country = unique(uk_lad_hle$Country),
  Prop_Urban = c(0, 1),
  Prop_top10 = c(0, 1)
)

post = posterior_predict(m_hle_both, newdata = new.data)
pred = posterior_linpred(m_hle_both, newdata = new.data)

quants = apply(post, 2, quantile, probs = c(0.025, 0.5, 0.975))  # quantiles over mcmc samples
quants2 = apply(pred, 2, quantile, probs = c(0.025, 0.5, 0.975))  # quantiles over mcmc samples
row.names(quants) = c("sim.lwr", "sim.med", "sim.upr")
row.names(quants2) = c("lwr", "HLE_birth.pred", "upr")

new.data = cbind(new.data, t(quants), t(quants2))

# labels for x axis
new.data = new.data %>% 
  mutate(x_label = case_when(
    Prop_top10 == 0 & Prop_Urban == 0   ~ "Rural, no deprivation",
    # Prop_top10 == 0 & Prop_Urban == 0.5 ~ "Mixed rural/urban, no deprivation",
    Prop_top10 == 0 & Prop_Urban == 1   ~ "Urban, no deprivation",
    
    # Prop_top10 == 0.5 & Prop_Urban == 0   ~ "Rural, 50% deprivation",
    # Prop_top10 == 0.5 & Prop_Urban == 0.5 ~ "Mixed rural/urban, 50% deprivation",
    # Prop_top10 == 0.5 & Prop_Urban == 1   ~ "Urban, 50% deprivation",
    
    Prop_top10 == 1 & Prop_Urban == 0   ~ "Rural, full deprivation",
    # Prop_top10 == 1 & Prop_Urban == 0.5 ~ "Mixed rural/urban, full deprivation",
    Prop_top10 == 1 & Prop_Urban == 1   ~ "Urban, full deprivation"
  ))


ggplot(new.data, aes(x = x_label, y = HLE_birth.pred, colour = Country)) +
  geom_pointrange(aes(ymin = lwr, ymax = upr)) +
  
  facet_wrap(~Country) +
  
  labs(y = "Healthy life expectancy at birth (years)\n", x = NULL, colour = NULL) +
  theme_classic() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave("plots/nations/hle - deprivation and urban.png", width = 175, height = 150, units = "mm")

##
## table of HLE 
##
uk_lad_hle %>% 
  filter(Deprivation %in% c(1, 10)) %>% 
  
  group_by(Country, Deprivation, RUC) %>% 
  summarise(HLE_med = median(HLE_birth, na.rm = T),
            HLE_sd  = sd(HLE_birth, na.rm = T)) %>% 
  
  mutate(HLE_sd = replace_na(HLE_sd, 0)) %>% 
  
  # labels for x axis
  mutate(x_label = factor(case_when(
    Deprivation == 10 & RUC == 3 ~ "Least deprived, mostly rural",
    Deprivation == 10 & RUC == 2 ~ "Least deprived, mixed rural/urban",
    Deprivation == 10 & RUC == 1 ~ "Least deprived, mostly urban",
    
    Deprivation == 1 & RUC == 3 ~ "Most deprived, mostly rural",
    Deprivation == 1 & RUC == 2 ~ "Most deprived, mixed rural/urban",
    Deprivation == 1 & RUC == 1 ~ "Most deprived, mostly urban"
  ),
  levels = c("Least deprived, mostly rural", "Least deprived, mixed rural/urban", "Least deprived, mostly urban",
             "Most deprived, mostly rural", "Most deprived, mixed rural/urban", "Most deprived, mostly urban"))) %>% 
  
  ggplot(aes(x = x_label, y = HLE_med, colour = Country)) +
  geom_pointrange(aes(ymin = HLE_med - HLE_sd, ymax = HLE_med + HLE_sd)) +
  
  facet_wrap(~Country) +
  
  theme_classic() +
  labs(y = "Healthy life expectancy at birth (years)\n", x = NULL, colour = NULL) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))


###############################################################################
## Analyse flooding (in MSOAs)
##
# make dataset for analysis
uk_msoa_flood = uk_msoa %>% 
  select(Country, MSOA11CD, Deprivation, Prop_top10, RUC = `Rural-urban classification`, Prop_Urban, n_people_flood) %>% 
  na.omit()

# show variation in flood risks by deprivation decile and country
uk_msoa_flood %>% 
  ggplot(aes(x = factor(Deprivation), y = n_people_flood)) +
  geom_boxplot() +
  facet_wrap(~ Country)

# look at distribution of people affected across countries
uk_msoa_flood %>% 
  ggplot(aes(x = n_people_flood)) +
  geom_histogram(binwidth = 100) +
  facet_wrap(~ Country)

##
## how does flood risk vary with deprivation and country?
##
m_flood = stan_glm(n_people_flood ~ Prop_top10 * Country, 
                   data = uk_msoa_flood,
                   # family = neg_binomial_2,
                   prior_intercept = normal(0, 5), prior = normal(0, 5),
                   adapt_delta = 0.99, chains = 4)

# check the proportion of zeroes in the dataset is similar to those predicted by the model - only if using negative binomial model
# prop_zero <- function(y) mean(y == 0)
# pp_check(m_flood, plotfun = "stat", stat = "prop_zero", binwidth = 0.01)  #--> yes - good

# plot coefficients
plot(m_flood)

# plot model predictions for proportion of deprivation and country on HLE
new.data = expand_grid(
  Country = c("England", "Wales", "Northern Ireland"),
  Prop_top10 = seq(0, 1, by = 0.01)
)

post = posterior_predict(m_flood, newdata = new.data)
pred = posterior_linpred(m_flood, newdata = new.data)

quants = apply(post, 2, quantile, probs = c(0.025, 0.5, 0.975))  # quantiles over mcmc samples
quants2 = apply(pred, 2, quantile, probs = c(0.025, 0.5, 0.975))  # quantiles over mcmc samples
row.names(quants) = c("sim.lwr", "sim.med", "sim.upr")
row.names(quants2) = c("lwr", "flood.pred", "upr")

new.data = cbind(new.data, t(quants), t(quants2))

ggplot(new.data, aes(x = Prop_top10, y = flood.pred)) +
  geom_point(data = uk_msoa_flood, aes(y = n_people_flood), alpha = 0.2) +
  geom_ribbon(aes(ymin = lwr, ymax = upr, fill = Country), alpha = 0.4, show.legend = F) +
  geom_line(aes(colour = Country), lwd = 1.5, show.legend = F) +
  
  facet_wrap(~Country) +
  
  scale_color_brewer(palette = "Accent") +
  scale_fill_brewer(palette = "Accent") +
  scale_x_continuous(labels = scales::percent) +
  scale_y_continuous(labels = scales::comma) +
  
  labs(y = "Number of people at risk of flooding\n", x = "\nProportion of highly deprived areas within a neighbourhood") +
  theme_classic()

ggsave("plots/nations/flood - deprivation.png", width = 190, height = 150, units = "mm")

##
## how does flood risk vary with rurality and country?
##
m_flood_ruc = stan_glm(n_people_flood ~ Prop_Urban * Country, 
                       data = uk_msoa_flood,
                       prior_intercept = normal(0, 5), prior = normal(0, 5),
                       adapt_delta = 0.99, chains = 4)

# plot coefficients
plot(m_flood_ruc)

# plot model predictions for proportion of deprivation and country on HLE
new.data = expand_grid(
  Country = c("England", "Wales", "Northern Ireland"),
  Prop_Urban = seq(0, 1, by = 0.01)
)

post = posterior_predict(m_flood_ruc, newdata = new.data)
pred = posterior_linpred(m_flood_ruc, newdata = new.data)

quants = apply(post, 2, quantile, probs = c(0.025, 0.5, 0.975))  # quantiles over mcmc samples
quants2 = apply(pred, 2, quantile, probs = c(0.025, 0.5, 0.975))  # quantiles over mcmc samples
row.names(quants) = c("sim.lwr", "sim.med", "sim.upr")
row.names(quants2) = c("lwr", "flood.pred", "upr")

new.data = cbind(new.data, t(quants), t(quants2))

ggplot(new.data, aes(x = Prop_Urban, y = flood.pred)) +
  geom_point(data = uk_msoa_flood, aes(y = n_people_flood), alpha = 0.2) +
  geom_ribbon(aes(ymin = lwr, ymax = upr, fill = Country), alpha = 0.4, show.legend = F) +
  geom_line(aes(colour = Country), lwd = 1.5, show.legend = F) +
  
  facet_wrap(~Country) +
  
  scale_color_brewer(palette = "Accent") +
  scale_fill_brewer(palette = "Accent") +
  scale_x_continuous(labels = scales::percent) +
  scale_y_continuous(labels = scales::comma, limits = c(0, NA)) +
  
  labs(y = "Number of people at risk of flooding\n", x = "\nProportion of urban areas within a neighbourhood") +
  theme_classic()

ggsave("plots/nations/flood - rural urban.png", width = 190, height = 150, units = "mm")


###############################################################################
## Analyse Section 95 support
##
# make dataset for analysis
uk_lad_asy = uk_lad %>% 
  select(Country, LAD17CD, Deprivation, Prop_top10, RUC = `Rural-urban classification`, Prop_Urban, Sec95) %>% 
  na.omit()

##
## descriptive stats
##
# totals per country
uk_lad_asy %>% 
  group_by(Country) %>% 
  summarise(n = sum(Sec95))

# histograms of HLE by country
uk_lad_asy %>%
  filter(Sec95 > 0) %>%
  
  ggplot(aes(x = Sec95, fill = Country)) +
  geom_histogram(binwidth = 20, show.legend = F) +
  
  facet_wrap(~Country, scales = "free") +
  theme_classic() +
  labs(x = "No. people receiving Section 95 support", y = "Frequency")

ggsave("plots/nations/displacement - country.png", width = 150, height = 110, units = "mm")

# which LADs host the most asylum seekers in each country?
uk_lad_asy %>% 
  group_by(Country) %>% 
  top_n(Sec95, n = 1)

# summary stats by country
tapply(uk_lad_asy$Sec95, uk_lad_asy$Country, summary)
tapply(uk_lad_asy$Prop_top10, uk_lad_asy$Country, summary)
tapply(uk_lad_asy$Prop_Urban, uk_lad_asy$Country, summary)

##
## how does number of asylum seekers vary across nations?
##
# model average HLE across nations
tidy(glm(Sec95 ~ Country, data = uk_lad_asy, family = "poisson"), conf.int = T)

# fit poisson, accounting for all the zeroes in the data (i.e. Local Authorities with no asylum seekers)
m_asy = stan_glm(Sec95 ~ Country,
                 data = uk_lad_asy,
                 family = neg_binomial_2,
                 prior_intercept = normal(0, 5), prior = normal(0, 5),
                 adapt_delta = 0.99, chains = 4)

# check the proportion of zeroes in the dataset is similar to those predicted by the model
prop_zero <- function(y) mean(y == 0)
pp_check(m_asy, plotfun = "stat", stat = "prop_zero", binwidth = 0.01)  #--> yes - good

tidy(m_asy) %>% mutate_if(is.numeric, exp)
exp(posterior_interval(m_asy))

##
## how does S95 support differ between deprivation and nations (non-spatial)?
##
m_asy_dep = stan_glm(Sec95 ~ Prop_top10 * Country, 
                     data = uk_lad_asy,
                     family = neg_binomial_2,
                     prior_intercept = normal(0, 5), prior = normal(0, 5),
                     adapt_delta = 0.99, chains = 4)

# plot coefficients
plot(m_asy_dep)

tidy(m_asy_dep, conf.int = T)

# plot model predictions for proportion of deprivation and country on HLE
new.data = expand_grid(
  Country = unique(uk_lad$Country),
  Prop_top10 = seq(0, 1, by = 0.01)
)

post = posterior_predict(m_asy_dep, newdata = new.data)
pred = posterior_linpred(m_asy_dep, newdata = new.data)

quants = apply(post, 2, quantile, probs = c(0.025, 0.5, 0.975))  # quantiles over mcmc samples
quants2 = apply(pred, 2, quantile, probs = c(0.025, 0.5, 0.975))  # quantiles over mcmc samples
row.names(quants) = c("sim.lwr", "sim.med", "sim.upr")
row.names(quants2) = c("lwr", "Sec95.pred", "upr")

new.data = cbind(new.data, t(quants), t(quants2))

ggplot(new.data, aes(x = Prop_top10, y = Sec95.pred)) +
  geom_point(data = uk_lad_asy, aes(y = Sec95), alpha = 0.2) +
  # geom_ribbon(aes(ymin = lwr, ymax = upr, fill = Country), alpha = 0.4, show.legend = F) +
  # geom_line(aes(colour = Country), lwd = 1.5, show.legend = F) +
  # 
  facet_wrap(~Country) +
  
  scale_color_brewer(palette = "Accent") +
  scale_fill_brewer(palette = "Accent") +
  scale_x_continuous(labels = scales::percent) +
  # scale_y_continuous(breaks = seq(40, 70, by = 5)) +
  
  labs(y = "No. people receiving Section 95 support\n", x = "\nProportion of highly deprived neighbourhoods in a Local Authority") +
  theme_classic()

ggsave("plots/nations/displacement - deprivation.png", width = 175, height = 150, units = "mm")

##
## how does S95 support differ between rural-urban areas and nations (non-spatial)?
##
m_asy_ruc = stan_glm(Sec95 ~ Prop_Urban * Country, 
                     data = uk_lad_asy,
                     family = neg_binomial_2,
                     prior_intercept = normal(0, 5), prior = normal(0, 5),
                     adapt_delta = 0.99, chains = 4)

# plot coefficients
plot(m_asy_ruc)

tidy(m_asy_ruc, conf.int = T)

# plot model predictions for proportion of deprivation and country on HLE
new.data = expand_grid(
  Country = unique(uk_lad$Country),
  Prop_Urban = seq(0, 1, by = 0.01)
)

post = posterior_predict(m_asy_ruc, newdata = new.data)
pred = posterior_linpred(m_asy_ruc, newdata = new.data)

quants = apply(post, 2, quantile, probs = c(0.025, 0.5, 0.975))  # quantiles over mcmc samples
quants2 = apply(pred, 2, quantile, probs = c(0.025, 0.5, 0.975))  # quantiles over mcmc samples
row.names(quants) = c("sim.lwr", "sim.med", "sim.upr")
row.names(quants2) = c("lwr", "Sec95.pred", "upr")

new.data = cbind(new.data, t(quants), t(quants2))

ggplot(new.data, aes(x = Prop_Urban, y = Sec95.pred)) +
  geom_point(data = uk_lad_asy, aes(y = Sec95), alpha = 0.2) +
  # geom_ribbon(aes(ymin = lwr, ymax = upr, fill = Country), alpha = 0.4, show.legend = F) +
  # geom_line(aes(colour = Country), lwd = 1.5, show.legend = F) +
  
  facet_wrap(~Country) +
  
  scale_color_brewer(palette = "Accent") +
  scale_fill_brewer(palette = "Accent") +
  scale_x_continuous(labels = scales::percent) +
  # scale_y_continuous(breaks = seq(40, 70, by = 5)) +
  
  labs(y = "No. people receiving Section 95 support\n", x = "\nProportion of urban neighbourhoods in a Local Authority") +
  theme_classic()

ggsave("plots/nations/displacement - rural urban.png", width = 175, height = 150, units = "mm")


###############################################################################
## Analyse loneliness (in MSOAs)
##
# make dataset for analysis
uk_msoa_lonely = uk_msoa %>% 
  select(Country, MSOA11CD, Deprivation, Prop_top10, RUC = `Rural-urban classification`, Prop_Urban, loneills_2018) %>% 
  na.omit()

# show variation in lonely risks by deprivation decile and country
uk_msoa_lonely %>% 
  ggplot(aes(x = factor(Deprivation), y = loneills_2018)) +
  geom_boxplot() +
  facet_wrap(~ Country)

# look at distribution of people affected across countries
uk_msoa_lonely %>% 
  ggplot(aes(x = loneills_2018)) +
  geom_histogram(binwidth = 1) +
  facet_wrap(~ Country)

##
## how does loneliness risk vary across nations?
##
# median/sd HLE across countries
uk_msoa_lonely %>% 
  group_by(Country) %>% 
  summarise(lonely_mean = mean(loneills_2018, na.rm = T),
            lonely_sd   = sd(loneills_2018, na.rm = T)) %>% 
  
  mutate(lonely_sd = replace_na(lonely_sd, 0)) %>% 
  
  ggplot(aes(x = Country, y = lonely_mean, colour = Country)) +
  geom_pointrange(aes(ymin = lonely_mean - lonely_sd, ymax = lonely_mean + lonely_sd), show.legend = F) +
  
  theme_classic() +
  labs(y = "Loneliness risk (higher means greater risk)\n", x = NULL, colour = NULL) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave("plots/nations/lonely - country.png", width = 100, height = 110, units = "mm")

# model loneliness risk across nations
tidy(lm(loneills_2018 ~ Country, data = uk_msoa_lonely), conf.int = T)

##
## how does loneliness risk vary with deprivation and country?
##
m_lonely = stan_glm(loneills_2018 ~ Prop_top10 * Country, 
                   data = uk_msoa_lonely,
                   prior_intercept = normal(0, 5), prior = normal(0, 5),
                   adapt_delta = 0.99, chains = 4)

# plot coefficients
plot(m_lonely)

# plot model predictions for proportion of deprivation and country on HLE
new.data = expand_grid(
  Country = unique(uk_msoa$Country),
  Prop_top10 = seq(0, 1, by = 0.01)
)

post = posterior_predict(m_lonely, newdata = new.data)
pred = posterior_linpred(m_lonely, newdata = new.data)

quants = apply(post, 2, quantile, probs = c(0.025, 0.5, 0.975))  # quantiles over mcmc samples
quants2 = apply(pred, 2, quantile, probs = c(0.025, 0.5, 0.975))  # quantiles over mcmc samples
row.names(quants) = c("sim.lwr", "sim.med", "sim.upr")
row.names(quants2) = c("lwr", "lonely.pred", "upr")

new.data = cbind(new.data, t(quants), t(quants2))

ggplot(new.data, aes(x = Prop_top10, y = lonely.pred)) +
  geom_point(data = uk_msoa_lonely, aes(y = loneills_2018), alpha = 0.2) +
  geom_ribbon(aes(ymin = lwr, ymax = upr, fill = Country), alpha = 0.4, show.legend = F) +
  geom_line(aes(colour = Country), lwd = 1.5, show.legend = F) +
  
  facet_wrap(~Country) +
  
  scale_color_brewer(palette = "Accent") +
  scale_fill_brewer(palette = "Accent") +
  scale_x_continuous(labels = scales::percent) +
  # scale_y_continuous(labels = scales::comma) +
  
  labs(y = "Risk of loneliness (higher numbers mean greater risk)\n", x = "\nProportion of highly deprived areas within a neighbourhood") +
  theme_classic()

ggsave("plots/nations/lonely - deprivation.png", width = 175, height = 150, units = "mm")

##
## how does lonely risk vary with rurality and country?
##
m_lonely_ruc = stan_glm(loneills_2018 ~ Prop_Urban * Country, 
                       data = uk_msoa_lonely,
                       prior_intercept = normal(0, 5), prior = normal(0, 5),
                       adapt_delta = 0.99, chains = 4)

# plot coefficients
plot(m_lonely_ruc)

# plot model predictions for proportion of deprivation and country on HLE
new.data = expand_grid(
  Country = unique(uk_msoa$Country),
  Prop_Urban = seq(0, 1, by = 0.01)
)

post = posterior_predict(m_lonely_ruc, newdata = new.data)
pred = posterior_linpred(m_lonely_ruc, newdata = new.data)

quants = apply(post, 2, quantile, probs = c(0.025, 0.5, 0.975))  # quantiles over mcmc samples
quants2 = apply(pred, 2, quantile, probs = c(0.025, 0.5, 0.975))  # quantiles over mcmc samples
row.names(quants) = c("sim.lwr", "sim.med", "sim.upr")
row.names(quants2) = c("lwr", "lonely.pred", "upr")

new.data = cbind(new.data, t(quants), t(quants2))

ggplot(new.data, aes(x = Prop_Urban, y = lonely.pred)) +
  geom_point(data = uk_msoa_lonely, aes(y = loneills_2018), alpha = 0.2) +
  geom_ribbon(aes(ymin = lwr, ymax = upr, fill = Country), alpha = 0.4, show.legend = F) +
  geom_line(aes(colour = Country), lwd = 1.5, show.legend = F) +
  
  facet_wrap(~Country) +
  
  scale_color_brewer(palette = "Accent") +
  scale_fill_brewer(palette = "Accent") +
  scale_x_continuous(labels = scales::percent) +
  # scale_y_continuous(labels = scales::comma, limits = c(0, NA)) +
  
  labs(y = "Risk of loneliness (higher numbers mean greater risk)\n", x = "\nProportion of urban areas within a neighbourhood") +
  theme_classic()

ggsave("plots/nations/lonely - rural urban.png", width = 190, height = 150, units = "mm")
