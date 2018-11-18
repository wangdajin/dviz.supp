library(tidycensus)
library(sf)
library(dplyr)
library(here)
library(ggplot2)

options(tigris_use_cache = TRUE)

##**********************
## US states geometries
##**********************


## projections
# ESRI:102003
# https://epsg.io/102003
crs_lower48 <- "+proj=aea +lat_1=29.5 +lat_2=45.5 +lat_0=37.5 +lon_0=-96 +x_0=0 +y_0=0 +ellps=GRS80 +datum=NAD83 +units=m +no_defs"

# EPSG:3338
# https://epsg.io/3338
crs_alaska <- "+proj=aea +lat_1=55 +lat_2=65 +lat_0=50 +lon_0=-154 +x_0=0 +y_0=0 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs "

# ESRI:102007
# https://epsg.io/102007
crs_hawaii <- "+proj=aea +lat_1=8 +lat_2=18 +lat_0=13 +lon_0=-157 +x_0=0 +y_0=0 +datum=NAD83 +units=m +no_defs"

## read shapefiles
# shapefiles from:
# https://www.census.gov/geo/maps-data/data/cbf/cbf_counties.html
us_counties_sp <- rgdal::readOGR(
  dsn = here::here("data-raw", "tidy_census", "US_shapes"),
  layer = "cb_2017_us_county_20m"
)

# aggregate individual counties into states
us_states_sp <- rgeos::gUnaryUnion(us_counties_sp, us_counties_sp$STATEFP)
# collect fips codes; they are the names of the objects after aggregation
us_states_sp$GEOID <- names(us_states_sp)
us_states_sp$GEOID <- as.character(us_states_sp$GEOID)
# convert to sf
us_states <- as(us_states_sp, "sf") %>%
  st_transform(crs_lower48) %>%
  filter(GEOID != "72") # remove Puerto Rico

us_lower48 <- filter(us_states, !GEOID %in% c("02", "15"))

## helper function to move geometries
place_geometry <- function(geometry, position, scale = 1) {
  (geometry - st_centroid(geometry)) * scale + 
    st_sfc(st_point(position))
}

bb <- st_bbox(us_lower48)

us_alaska <- filter(us_states, GEOID == "02")
# Alaska scaled down
us_alaska2 <- st_transform(us_alaska, crs_alaska)
st_geometry(us_alaska2) <- place_geometry(
  st_geometry(us_alaska2),
  c(bb$xmin + 0.08*(bb$xmax - bb$xmin),
    bb$ymin + 0.07*(bb$ymax - bb$ymin)),
  scale = 0.35
)
st_crs(us_alaska2) <- crs_lower48

# Alaska not scaled
us_alaska3 <- st_transform(us_alaska, crs_alaska)
st_geometry(us_alaska3) <- place_geometry(
  st_geometry(us_alaska3),
#  c(bb$xmin - 0.2*(bb$xmax - bb$xmin),
#    bb$ymin + 0.4*(bb$ymax - bb$ymin))
  c(bb$xmin + 0.2*(bb$xmax - bb$xmin),
    bb$ymin - 0.13*(bb$ymax - bb$ymin))
)
st_crs(us_alaska3) <- crs_lower48


us_hawaii <- filter(us_states, GEOID == "15")
us_hawaii2 <- st_transform(us_hawaii, crs_hawaii)
st_geometry(us_hawaii2) <- place_geometry(
  st_geometry(us_hawaii2),
  c(bb$xmin + 0.3*(bb$xmax - bb$xmin),
    bb$ymin + 0.*(bb$ymax - bb$ymin))
)
st_crs(us_hawaii2) <- crs_lower48

us_hawaii3 <- st_transform(us_hawaii, crs_hawaii)
st_geometry(us_hawaii3) <- place_geometry(
  st_geometry(us_hawaii3),
  c(bb$xmin + 0.7*(bb$xmax - bb$xmin),
    bb$ymin - 0.2*(bb$ymax - bb$ymin))
)
st_crs(us_hawaii3) <- crs_lower48

us_albers <- rbind(us_lower48, us_alaska2, us_hawaii2)
us_albers2 <- rbind(us_lower48, us_alaska3, us_hawaii3)

US_states_geoms <- list(
  lower48 = us_lower48,
  true_albers = us_states,
  us_albers = us_albers,
  albers_revised = us_albers2
)

devtools::use_data(US_states_geoms, overwrite = TRUE)


##*****************************************
## Median income, population density, etc.
##*****************************************

# get median income
income_acs <- get_acs(
  geography = "state", year = 2015,
  variables = "B19013_001", geometry = FALSE
) %>%
  rename(name = NAME, median_income = estimate, median_income_moe = moe) %>%
  select(-variable)

# get population
population_acs <- get_acs(
  geography = "state", year = 2015,
  variables = "B01003_001", geometry = FALSE
) %>%
  rename(name = NAME, population = estimate) %>% 
  select(-variable, -moe)

income_acs <- left_join(income_acs, population_acs)

US_income <- left_join(us_albers2, income_acs) %>%
  mutate(
    area = st_area(geometry)*1e-6, # area in square km
    popdens = population/area
  )

devtools::use_data(US_income, overwrite = TRUE)

library(cartogram)
US_income_cartogram <- cartogram_cont(US_income, 'population')

devtools::use_data(US_income_cartogram, overwrite = TRUE)