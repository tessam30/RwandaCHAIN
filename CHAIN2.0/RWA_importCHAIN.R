# Rwanda stunting analysis -----------------------------------------
# Compare CHAIN sector-level data to livelihood zones ---------------------
#
# RWA_compareCHAIN.R
#
# Script to translate CHAIN location data into livelihood zones.
# 
# Data are from the 2015 Comprehensive Food Security and Vulnerability Analysis
# by the World Food Programme
# Available at http://microdata.statistics.gov.rw/index.php/catalog/70
# Report: https://www.wfp.org/content/rwanda-comprehensive-food-security-and-vulnerability-analysis-march-2016
#
# Laura Hughes, lhughes@usaid.gov, 8 November 2016
# with Tim Essam (tessam@usaid.gov) and Nada Petrovic (npetrovic@usaid.gov)
#
# Copyright 2016 by Laura Hughes via MIT License
#
# -------------------------------------------------------------------------


# DEPENDS: previous functions to run: ----------------------------------------------
setwd('~/GitHub/Rwanda/R/')
source('RWA_WFP_00_setup.R')
source('RWA_WFP_03_importHH.R')
source('RWA_WFP_05_importGeo.R')
library(jsonlite)



# setup options -----------------------------------------------------------
ta_list = c('NS', 'WS') # technical areas: nutrition specific or wash-specific
intervention_list = c('PHP', 'HE')

# convert sectors to LZ ---------------------------------------------------

# translate sectors into livelihood zones.
# Note: relying on the WFP's classification of sectors and livelihood zones.
# Assumes a sector is in a SINGLE livelihood zone.  Appears based on maps to be mostly correct, with some exceptions in the Eastern Agro-pastoral zones.

lz_codebk = hh %>% 
  select(admin1, admin2, admin3, livelihood_zone) %>% 
  distinct()


admin3_codebk = RWA_admin3$df %>% 
  select(prov_id = Prov_ID, province = Province,
         dist_id = Dist_ID, district = District,
         sect_id = Sect_ID, sector = Sector) %>% 
  distinct()


# import sector-level data ------------------------------------------------

# Instructions on importing from json file directly:
# http://devgeocenter.org/rwanda-programs/content/?action=query&target=acts-locs
# remove '\' from file
# replace '"{' with '{'
# replace '}"' with '}'
# sed -n  's/\\//gpw output.json' intervention-location_2016-2-05.json
# sed -n  's/}"/}/gpw output2.json' output.json
# sed -n  's/"{/{/gpw intervention-location_2016-12-05.json' output2.json

# Import data from Baboyma's dataset
# sectors = jsonlite::fromJSON('~/GitHub/RwandaCHAIN/www/data/intervention-location_2016-12-05.json', flatten = T, simplifyMatrix = T, simplifyDataFrame = T)
# sectors = sectors$data

sectors = read.csv('~/GitHub/RwandaCHAIN/www/data/Rwanda - CHAIN Programs_2016-12-06.csv')

interventions = jsonlite::fromJSON('~/GitHub/RwandaCHAIN/www/data/intervention-location_2016-11-28.json', flatten = T, simplifyMatrix = T, simplifyDataFrame = T)

interventions = interventions %>% rename(intervention_name = intervention)


partners = jsonlite::fromJSON('~/GitHub/RwandaCHAIN/www/data/partner-list.json', flatten = T, simplifyMatrix = T, simplifyDataFrame = T)
partners = partners$data

# merge together names ----------------------------------------------------
sectors = left_join(sectors, interventions, c("intervention" = "icode",
                                              "techoffice" = "tacode"))

sectors = sectors %>% 
  select(-startdate, -enddate, -pcode) %>% 
  rename(techcode = techoffice,
         prov_id = province,
         dist_id = district,
         sect_id = sector)


sectors = left_join(sectors, partners, by = c("partner" = "pcode"))

# merge in geo names
sectors = left_join(sectors, admin3_codebk, by = c('prov_id', 'dist_id', 'sect_id'))

# remove dupl. info
chain = sectors %>% 
  select(province, district, sector,
         partner, techarea, intervention_name, 
         techoffice, activity, startdate.date, enddate.date) %>% 
  distinct()
  
# Filter out nutrition-related info ------------------------------------------
stunting_interv = sectors %>% 
  filter(techoffice %in% ta_list | intervention %in% intervention_list) %>% 
  select(techoffice, techarea, icode = intervention, intervention = intervention.y,
         province, district, sector, partner) %>% 
  distinct()

# Collapse down to the sector-level
stunting_interv_type = stunting_interv %>% 
  group_by(intervention, province, district, sector) %>% 
  summarise(n = n()) %>% 
  arrange(desc(n))

# total # partners in each region
stunting_interv_tot = stunting_interv %>% 
  group_by(province, district, sector) %>% 
  select(-intervention) %>%
  # distinct() %>% 
  summarise(n = n()) %>% 
  arrange(desc(n))

stunting_interv_IP = stunting_interv %>% 
  group_by(partner, province, district, sector) %>% 
  summarise(n = n()) %>% 
  arrange(desc(n))

total_interv_IP = sectors %>% 
  group_by(partner, province, district, sector) %>% 
  summarise(n = n()) %>% 
  arrange(desc(n))


# merge with geodata ------------------------------------------------------
admin3_plot = left_join(RWA_admin3$df, stunting_interv_tot, by = c('Prov_ID' = "province", "Dist_ID" = "district", "Sect_ID" = "sector"))

p = plot_map(admin3_plot, fill_var = 'n') + scale_fill_gradientn(colours = brewer.pal(9, 'YlGnBu'), na.value = grey15K)

save_plot('~/Creative Cloud Files/MAV/Projects/RWA_LAM-stunting_2016-09/exported_fromR/CHAINproj_intervention.pdf')

admin3_plot = left_join(RWA_admin3$df, stunting_interv_IP, by = c('Prov_ID' = "province", "Dist_ID" = "district", "Sect_ID" = "sector"))

p = plot_map(admin3_plot, fill_var = 'partner') + scale_fill_brewer(palette = 'Pastel1', na.value = 'white') + theme(legend.position = c(0.1, 0.8)) + 
  geom_path(aes(x = long, y = lat, order = order, group = group, fill = '1'), 
            data = RWA_admin2$df, colour = grey70K, size= 0.2) +
  facet_wrap(~partner)

save_plot('~/Creative Cloud Files/MAV/Projects/RWA_LAM-stunting_2016-09/exported_fromR/CHAINproj_IP.pdf')


admin3_plot = left_join( total_interv_IP, RWA_admin3$df, by = c("province" = 'Prov_ID',"district" =  "Dist_ID", "sector" = "Sect_ID"))
p = plot_map(admin3_plot, fill_var = 'partner') + scale_fill_brewer(palette = 'Pastel1', na.value = 'white') + theme(legend.position = c(0.1, 0.8)) + 
  geom_path(aes(x = long, y = lat, order = order, group = group, fill = '1'), 
            data = RWA_admin2$df, colour = grey70K, size= 0.2) +
  facet_wrap(~partner) + theme_blank() + theme(strip.text = element_text(family = 'Lato', colour = grey90K, size = 15))

save_plot('~/Creative Cloud Files/MAV/Projects/RWA_LAM-stunting_2016-09/exported_fromR/total_CHAINproj_IP', saveBoth = T)

