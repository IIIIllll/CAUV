# Providing a calculation/projection of the Yields in Ohio

# ---- start --------------------------------------------------------------

library("tidyverse")
library("zoo")

# Create a directory for the data
local_dir <- "2-calc"
yields    <- paste0(local_dir, "/yields")
if (!file.exists(local_dir)) dir.create(local_dir, recursive = T)
if (!file.exists(yields)) dir.create(yields, recursive = T)

j5 <- read_rds("1-tidy/yields/ohio_yields.rds")

# Add on an additional year for Yields:
yield_proj <- tibble(year = max(j5$year) + 1) %>% 
  bind_rows(j5) %>% 
  arrange(year)

# For a tax year, Ohio will use state-wide yields for the previous 11 to 1 years
#  of official USDA data. For example, the 2019 tax year will use yield data 
#  from 2009 to 2018.

# Simple averages based on yields over a ten-year average with one year lag
#  since ODT adjusted in 2015 (it was a 2 year lag). Then, adjusted to base
#  rate in 1984.
yield_calc <- function(crop, year) {
  ifelse(year > 2014,
         rollapplyr(lag(crop), 10, mean, fill = NA),
         rollapplyr(lag(crop, 2), 10, mean, fill = NA))
}

# ---- calc ---------------------------------------------------------------

ohio_yield <- yield_proj %>% 
  arrange(year) %>% 
  fill(corn_grain_yield, soy_yield, wheat_yield) %>% 
  
  mutate(corn_yield_cauv  = yield_calc(corn_grain_yield, year),
         corn_yield_adj_cauv = corn_yield_cauv / corn_grain_yield[year==1984],
         corn_yield_adj_odt = corn_yield_odt / corn_grain_yield[year==1984],
         soy_yield_cauv   = yield_calc(soy_yield, year),
         soy_yield_adj_cauv = soy_yield_cauv / soy_yield[year==1984],
         soy_yield_adj_odt = soy_yield_odt / soy_yield[year==1984],
         wheat_yield_cauv = yield_calc(wheat_yield, year),
         wheat_yield_adj_cauv = wheat_yield_cauv / wheat_yield[year==1984],
         wheat_yield_adj_odt = wheat_yield_odt / wheat_yield[year==1984]) %>% 
  select(year, corn_yield_cauv:wheat_yield_adj_odt)

ohio <- left_join(yield_proj, ohio_yield)


write.csv(ohio, paste0(yields, "/ohio_forecast_crops.csv"),
          row.names = F)
write_rds(ohio, paste0(yields, "/ohio_forecast_crops.rds"))

# ---- corn ---------------------------------------------------------------

ohio %>% 
  filter(year > 2005) %>% 
  select("Year" = year, "ODT Yield" = corn_yield_odt,
         "USDA Yield" = corn_grain_yield,
         "Projected Yield" = corn_yield_cauv) %>% 
  knitr::kable()

# ---- soy ----------------------------------------------------------------

ohio %>% 
  filter(year > 2005) %>% 
  select("Year" = year, "ODT Yield" = soy_yield_odt,
         "USDA Yield" = soy_yield, "Projected Yield" = soy_yield_cauv) %>% 
  knitr::kable()

# ---- wheat --------------------------------------------------------------

ohio %>% 
  filter(year > 2005) %>% 
  select("Year" = year, "ODT Yield" = wheat_yield_odt,
         "USDA Yield" = wheat_yield,
         "Projected Yield" = wheat_yield_cauv) %>% 
  knitr::kable()
