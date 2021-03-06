##
## Digital exclusion - from http://heatmap.thetechpartnership.com
##

# list of URLs for the data:
# "infrastructure": "https://lloyds-heatmap-prod.s3-eu-west-2.amazonaws.com:443/heatmap/metric_types/infrastructure_a2483dadcfed45d0b5c5443c3b340450.kmz"
# "broadband-10mbps": "https://lloyds-heatmap-prod.s3-eu-west-2.amazonaws.com:443/heatmap/metric_types/broadband-10mbps_c05efde3cb21463d9b40be9f0d8864de.kmz"
# "broadband-2mbps": "https://lloyds-heatmap-prod.s3-eu-west-2.amazonaws.com:443/heatmap/metric_types/broadband-2mbps_222f56c970ba4bb485b3001c45fe189d.kmz"
# "mobile-4g": "https://lloyds-heatmap-prod.s3-eu-west-2.amazonaws.com:443/heatmap/metric_types/mobile-4g_99d3965904124c7f9bc8fc0143638e2d.kmz"
# 
# "access": "https://lloyds-heatmap-prod.s3-eu-west-2.amazonaws.com:443/heatmap/metric_types/access_43bf632341bb46e5a24d13db8dde3638.kmz"
# "skill": "https://lloyds-heatmap-prod.s3-eu-west-2.amazonaws.com:443/heatmap/metric_types/skill_7990568e98dd45b5833bc04fa7a95ad4.kmz"
# "use": "https://lloyds-heatmap-prod.s3-eu-west-2.amazonaws.com:443/heatmap/metric_types/use_aecb2530c9a947d394aa346525ef79d5.kmz"
# 
# "age": "https://lloyds-heatmap-prod.s3-eu-west-2.amazonaws.com:443/heatmap/metric_types/age_493bb59c71c943febf238d1ee7dbbc5c.kmz"
# "education": "https://lloyds-heatmap-prod.s3-eu-west-2.amazonaws.com:443/heatmap/metric_types/education_4085071758db45ffae321d46727f1ec1.kmz"
# "income": "https://lloyds-heatmap-prod.s3-eu-west-2.amazonaws.com:443/heatmap/metric_types/income_5526bce0da784ad59c429a13056b6a2c.kmz"
# "health": "https://lloyds-heatmap-prod.s3-eu-west-2.amazonaws.com:443/heatmap/metric_types/health_3c4f762769fe4a5b960342c134e0a1ef.kmz"}
# 
# "digital": "https://lloyds-heatmap-prod.s3-eu-west-2.amazonaws.com:443/heatmap/metric_types/digital_fb6215e3d1124765a109ae4298a8eb4e.kmz"
# "social": "https://lloyds-heatmap-prod.s3-eu-west-2.amazonaws.com:443/heatmap/metric_types/social_b5e4926974754293a83f7911ef6b4b8f.kmz"
# "total": "https://lloyds-heatmap-prod.s3-eu-west-2.amazonaws.com:443/heatmap/metric_types/total_cbe51cfaefa14aac8dfde23ee145c4af.kmz"

library(tidyverse)
library(xml2)

source("init.r")

# set of digital exclusion indicators to extract from the .kml files (there is one .kml file for each of these)
indicators = c(
  infrastructure = "https://lloyds-heatmap-prod.s3-eu-west-2.amazonaws.com:443/heatmap/metric_types/infrastructure_a2483dadcfed45d0b5c5443c3b340450.kmz",
  access = "https://lloyds-heatmap-prod.s3-eu-west-2.amazonaws.com:443/heatmap/metric_types/access_43bf632341bb46e5a24d13db8dde3638.kmz",
  skill = "https://lloyds-heatmap-prod.s3-eu-west-2.amazonaws.com:443/heatmap/metric_types/skill_7990568e98dd45b5833bc04fa7a95ad4.kmz",
  use = "https://lloyds-heatmap-prod.s3-eu-west-2.amazonaws.com:443/heatmap/metric_types/use_aecb2530c9a947d394aa346525ef79d5.kmz"
)

##
## extract metrics from .kml files
##
for (i in 1:length(indicators)) {
  
  metric = indicators[i]
  
  # where to store the current indicator
  metric_path = file.path(data.dir.in, "digital-exclusion", names(metric))
  
  # download .kmz file into a temporary file and unzip its .kml file into the raw data folder
  tmp_kmz = tempfile()
  download.file(metric, tmp_kmz, mode = "wb")
  unzip(tmp_kmz, exdir = metric_path)
  unlink(tmp_kmz)
  
  # open the newly downloaded and extracted file
  kml = read_xml(file.path(metric_path, "doc.kml"))
  
  xml_ns_strip(kml)  # need to strip out the namespace before we can use xml_find_all()
  
  places = kml %>% xml_find_all("//Placemark")  # get all geographical entries
  
  # 'styleUrl' refers to the level of exclusion ()
  ratings = places %>% 
    xml_find_all("//styleUrl") %>% 
    xml_text()
  
  # save into dataframe
  if (!exists("digital")) {
    # dataframe doesn't already exist so create one with Local Authority codes
    la_codes = places %>% 
      xml_find_all("//name") %>% 
      xml_text()
    
    digital = tibble(la_codes)
  }
  
  # append ratings for current metric
  digital = bind_cols(digital, tibble(ratings))
  
  # rename new column to the name of the metric
  names(digital)[ names(digital) == "ratings" ] = names(metric)
  
  print(paste0("Processed ", names(metric)))
}

# convert metrics to integers
digital = digital %>% 
  mutate(infrastructure = as.integer(str_remove(infrastructure, "#")),
         access = as.integer(str_remove(access, "#")),
         skill = as.integer(str_remove(skill, "#")),
         use = as.integer(str_remove(use, "#")))

# calculate overall exclusion risks - one by summing, one by multiplying (we'll leave the splitting into quantiles for later)
digital = digital %>% 
  mutate(digital_total_sum = infrastructure + access + skill + use,
         digital_total_mult = infrastructure * access * skill * use)

# save
write_csv(digital, file.path(data.dir.processed, "digital exclusion.csv"))
