install.packages("tigris")

library(dplyr)
library(tigris)
library(sf)

options(tigris_use_cache = FALSE)

# states <- tigris::states(cb = TRUE, progress_bar = TRUE, refresh = TRUE)

states <- 

saveRDS(states, file = "data/states.rds")
  
county_state_fips <- lapply(states$STATEFP, function(state_fp) { 
  state <- states |> filter(STATEFP == state_fp)
  counties <- tigris::list_counties(state = state_fp) 
  return(data.frame(county_name = counties$county, state_name = state$NAME, state_fips = state_fp, geoid_co = paste0(state_fp, counties$county_code)))
}) |> dplyr::bind_rows()

saveRDS(county_state_fips, file = "data/county_state_fips.rds")
