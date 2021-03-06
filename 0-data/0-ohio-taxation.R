# Ohio Taxation statistics:
# http://www.tax.ohio.gov/tax_analysis/tax_data_series/
#  publications_tds_property.aspx

# ---- start --------------------------------------------------------------

library("httr")
library("readxl")
library("rvest")
library("tidyverse")

folder_create <- function(x, y = "") {
  temp <- paste0(y, x)
  if (!file.exists(temp)) dir.create(temp, recursive = T)
  return(temp)
}

# Create a directory for the data
local_dir    <- folder_create("0-data/odt")
data_source  <- folder_create("/raw", local_dir)

tax_site <- paste0("http://www.tax.ohio.gov/tax_analysis/tax_data_series/",
                   "publications_tds_property.aspx")

# ---- cauv-explainations -------------------------------------------------

explainers   <- folder_create("/explainers", data_source)

# Should have all the explainers downloaded for future use!

cauvexp <- read_html("https://www.tax.ohio.gov/real_property/cauv.aspx")

link1 <- cauvexp %>% 
  html_nodes("a") %>% 
  html_text()

link2 <- cauvexp %>% 
  html_nodes("a") %>% 
  html_attr("href") %>% 
  paste0("http://www.tax.ohio.gov", .)

cauvexp <- data_frame(text = link1, url = link2) %>% 
  filter(grepl("explanation", tolower(text)))

tax_download <- purrr::pmap(cauvexp, function(text, url){
  Sys.sleep(sample(seq(0,1,0.25), 1))
  dfile <- paste0(explainers, "/", tolower(basename(text)), ".pdf")
  if (!file.exists(dfile)) download.file(url, dfile)
})

# ---- pd30 ---------------------------------------------------------------

pd30 <- folder_create("/pd30", data_source)

# pd30 assessed value and taxes levied
# http://www.tax.ohio.gov/tax_analysis/tax_data_series/
#  tangible_personal_property/pd30/pd30cy87.aspx
# http://www.tax.ohio.gov/tax_analysis/tax_data_series/
#  publications_tds_property/PD30CY11.aspx

tax_urls <- read_html(tax_site) %>% 
  html_nodes("ul:nth-child(11) li:nth-child(1) a") %>% 
  html_attr("href") %>% 
  paste0("http://www.tax.ohio.gov", .)

tax_urls <- read_html(tax_site) %>% 
  html_nodes("ul:nth-child(19) li:nth-child(3) a") %>% 
  html_attr("href") %>% 
  paste0("http://www.tax.ohio.gov", .) %>% 
  c(tax_urls, .)

tax_download <- purrr::map(tax_urls, function(x){
  Sys.sleep(sample(seq(0,1,0.25), 1))
  dlinks <- read_html(x) %>% 
    html_nodes("#dnn_ContentPane a") %>% 
    html_attr("href") %>% 
    na.omit() %>% 
    paste0("http://www.tax.ohio.gov", .)
  dfile <- paste0(pd30, "/", tolower(basename(dlinks)))
  purrr::map2(dfile, dlinks, function(x, y){
    if (!file.exists(x)) download.file(y, x)
  })
})

tax_files <- dir(pd30, pattern = "pd30", full.names = T)

tax_files <- tax_files[!grepl(".pdf", tax_files)]

pd30_vals <- map(tax_files, function(x){
  j5 <- gdata::read.xls(x)
  starts <- which(grepl("adams", tolower(j5[,1])))
  ends   <- which(grepl("wyandot", tolower(j5[,1])))
  j5 <- j5[starts:ends,]
  j5 <- j5[, colSums(is.na(j5)) < nrow(j5)]
  j5 <- j5[, !(is.na(j5[1,]))]
  j5 <- j5[, !(j5[1,] == "")]
  if (ncol(j5) == 10) {
    names(j5) <- c("county", "real_property_value",
                   "public_utility_property_value", "tangible_property_value",
                   "total_property_value", "real_property_tax",
                   "public_utility_property_tax", "tangible_property_tax",
                   "total_property_tax", "special_assessments")
  } else {
    j5 <- j5[,1:8]
    names(j5) <- c("county", "real_property_value",
                   "public_utility_property_value", "total_property_value",
                   "real_property_tax", "public_utility_property_tax",
                   "total_property_tax", "special_assessments")
  }
  j5 <- mutate_at(j5, vars(real_property_value:special_assessments),
                  funs(1000*as.numeric(gsub(",", "", gsub("\\$", "", .)))))
  j5$county <- tolower(j5$county)
  j5$county <- ifelse(j5$county == "putnum", "putnam", j5$county)
  j5$year <- as.numeric(substr(basename(x), 7, 8))
  # hack for creating a year variable
  j5$year <- ifelse(j5$year < 80, 2000 + j5$year, 1900 + j5$year)
  return(j5)
})

pd30_vals <- bind_rows(pd30_vals) %>% 
  mutate(county = ifelse(county == "guernesey", "guernsey", county))

pd30_vals <- arrange(pd30_vals, year, county)

write_csv(pd30_vals, paste0(local_dir, "/pd30.csv"))
write_rds(pd30_vals, paste0(local_dir, "/pd30.rds"))

# ---- pd31 ---------------------------------------------------------------

pd31 <- folder_create("/pd31", data_source)

# pd31 taxable value by class of property and county
# http://www.tax.ohio.gov/tax_analysis/tax_data_series/
#  tangible_personal_property/pd31/pd31cy85.aspx

tax_urls <- read_html(tax_site) %>% 
  html_nodes("ul:nth-child(17) li:nth-child(4) a") %>% 
  html_attr("href") %>% 
  paste0("http://www.tax.ohio.gov", .)

tax_download <- purrr::map(tax_urls, function(x){
  Sys.sleep(sample(seq(0,1,0.25), 1))
  dlinks <- read_html(x) %>% 
    html_nodes("#dnn_ContentPane a") %>% 
    html_attr("href") %>% 
    na.omit() %>% 
    paste0("http://www.tax.ohio.gov", .)
  dfile <- paste0(pd31, "/", tolower(basename(dlinks)))
  purrr::map2(dfile, dlinks, function(x, y){
    if (!file.exists(x)) download.file(y, x)
  })
})

tax_files <- dir(pd31, pattern = "pd31", full.names = T)

tax_files <- tax_files[!grepl(".pdf", tax_files)]

pd31_vals <- map(tax_files, function(x){
  j5 <- gdata::read.xls(x)
  starts <- which(grepl("adams", tolower(j5[,1])))
  # Problem with a missing start value, hack
  if (length(starts) == 0) j5 <- j5[,-1]
  starts <- which(grepl("adams", tolower(j5[,1])))
  ends   <- which(grepl("wyandot", tolower(j5[,1])))
  
  j5 <- j5[starts:ends,]
  j5 <- j5[, colSums(is.na(j5)) < nrow(j5)]
  j5 <- j5[, !(is.na(j5[1,]))]
  j5 <- mutate_all(j5, funs(gsub("\\%", "", .)))
  j5 <- j5[, !(j5[1,] == "")]
  j5 <- j5[complete.cases(j5),]
  
  # | 1 to 17 are 17 | 18 to 23 are 7 | 24 is 12    |
  # | 25 to 29 are 17 | 30 is 24 | 31 and 32 are 17 |
  if (ncol(j5) > 12) j5 <- j5[,1:12]
  if (ncol(j5) == 12) j5 <- j5[,c(1,2,4,6,8,10,12)]
  names(j5) <- c("county", "residential_taxable_value",
                 "agricultural_taxable_value", "industrial_taxable_value",
                 "commercial_taxable_value", "mineral_taxable_value",
                 "total_taxable_value")
  j5 <- j5 %>% 
    group_by(county) %>% 
    mutate_all(funs(as.numeric(gsub(",", "", gsub("\\$", "", .))))) %>% 
    ungroup()
  j5$county <- tolower(j5$county)
  j5$county <- ifelse(j5$county == "putnum", "putnam", j5$county)
  j5$year <- as.numeric(substr(basename(x), 7, 8))
  # hack for creating a year variable
  j5$year <- ifelse(j5$year < 80, 2000 + j5$year, 1900 + j5$year)
  return(j5)
})


pd31_vals <- bind_rows(pd31_vals) %>% 
  mutate(county = ifelse(county == "guernesey", "guernsey", county))

pd31_vals <- arrange(pd31_vals, year, county)

write_csv(pd31_vals, paste0(local_dir, "/pd31.csv"))
write_rds(pd31_vals, paste0(local_dir, "/pd31.rds"))

# ---- pr6 ----------------------------------------------------------------

pr6 <- folder_create("/pr6", data_source)

# pr6 tax rates by county
# http://www.tax.ohio.gov/tax_analysis/tax_data_series/
#  all_property_taxes/pr6/pr6cy88.aspx
# http://www.tax.ohio.gov/tax_analysis/tax_data_series/
#  all_property_taxes/pr6/pr6cy09.aspx

tax_urls <- read_html(tax_site) %>%
  html_nodes("ul:nth-child(11) li:nth-child(3) a") %>%
  html_attr("href") %>%
  paste0("http://www.tax.ohio.gov", .)

tax_urls <- read_html(tax_site) %>%
  html_nodes("ul:nth-child(19) li:nth-child(5) a") %>%
  html_attr("href") %>%
  paste0("http://www.tax.ohio.gov", .) %>%
  c(tax_urls, .)

# HACK\ for a screwup
tax_urls[28] <- paste0("http://www.tax.ohio.gov/tax_analysis/tax_data_series/",
                       "publications_tds_property/PR6CY15.aspx")

tax_download <- purrr::map(tax_urls, function(x){
  Sys.sleep(sample(seq(0,1,0.25), 1))
  dlinks <- read_html(x) %>%
    html_nodes("#dnn_ContentPane a") %>%
    html_attr("href") %>%
    na.omit() %>%
    paste0("http://www.tax.ohio.gov", .)
  dfile <- paste0(pr6, "/", tolower(basename(dlinks)))
  purrr::map2(dfile, dlinks, function(x, y){
    if (!file.exists(x)) download.file(y, x)
  })
})

tax_files <- dir(pr6, pattern = "pr6", full.names = T)

tax_files <- tax_files[!grepl(".pdf", tax_files)]

pr6_vals <- map(tax_files, function(x){
  j5 <- gdata::read.xls(x)
  starts <- which(grepl("adams", tolower(j5[,1])))
  # Problem with a missing start value, hack
  if (length(starts) == 0) j5 <- j5[,-1]
  starts <- which(grepl("adams", tolower(j5[,1])))
  ends   <- which(grepl("wyandot", tolower(j5[,1])))
  
  j5 <- j5[starts:ends,]
  j5 <- j5[, colSums(is.na(j5)) < nrow(j5)]
  j5 <- j5[, !(is.na(j5[1,]))]
  j5 <- mutate_all(j5, funs(gsub("\\%", "", .)))
  j5 <- j5[, !(j5[1,] == "")]
  names(j5) <- c("county", "res_ag_gross_millage", "res_ag_net_millage",
                 "public_gross_millage", "public_net_millage",
                 "tangible_millage")
  j5 <- j5 %>% 
    group_by(county) %>% 
    mutate_all(funs(as.numeric(gsub(",", "", gsub("\\$", "", .))))) %>% 
    ungroup()
  j5$county <- tolower(j5$county)
  j5$county <- ifelse(j5$county == "putnum", "putnam", j5$county)
  j5$year <- as.numeric(substr(basename(x), 6, 7))
  # hack for creating a year variable
  j5$year <- ifelse(j5$year < 80, 2000 + j5$year, 1900 + j5$year)
  return(j5)
})

pr6_vals <- bind_rows(pr6_vals) %>% 
  mutate(county = ifelse(county == "guernesey", "guernsey", county))

pr6_vals <- arrange(pr6_vals, year, county)

write_csv(pr6_vals, paste0(local_dir, "/pr6.csv"))
write_rds(pr6_vals, paste0(local_dir, "/pr6.rds"))

# ---- td1 ----------------------------------------------------------------

td1 <- folder_create("/td1", data_source)

# td1 delinquent property taxes by county
# http://www.tax.ohio.gov/tax_analysis/tax_data_series/
#  all_property_taxes/td1/td1cy87.aspx
# http://www.tax.ohio.gov/tax_analysis/tax_data_series/
#  publications_tds_property/TD1CY11.aspx

tax_urls <- read_html(tax_site) %>% 
  html_nodes("ul:nth-child(11) li:nth-child(4) a") %>% 
  html_attr("href") %>% 
  paste0("http://www.tax.ohio.gov", .)

tax_urls <- read_html(tax_site) %>% 
  html_nodes("ul:nth-child(19) li:nth-child(6) a") %>% 
  html_attr("href") %>% 
  paste0("http://www.tax.ohio.gov", .) %>% 
  c(tax_urls, .)

tax_download <- purrr::map(tax_urls, function(x){
  Sys.sleep(sample(seq(0,1,0.25), 1))
  dlinks <- read_html(x) %>% 
    html_nodes("#dnn_ContentPane a") %>% 
    html_attr("href") %>% 
    na.omit() %>% 
    paste0("http://www.tax.ohio.gov", .)
  dfile <- paste0(td1, "/", tolower(basename(dlinks)))
  purrr::map2(dfile, dlinks, function(x, y){
    if (!file.exists(x)) download.file(y, x)
  })
})

tax_files <- dir(td1, pattern = "td1", full.names = T)

tax_files <- tax_files[!grepl(".pdf", tax_files)]

# need to double check the varaibles across years and the names but seems
# to be OK

td1_vals <- map(tax_files, function(x){
  j5 <- gdata::read.xls(x)
  starts <- which(grepl("adams", tolower(j5[,1])))
  ends   <- which(grepl("wyandot", tolower(j5[,1])))
  j5 <- j5[starts:ends,]
  j5 <- j5[, colSums(is.na(j5)) < nrow(j5)]
  j5 <- j5[, !(is.na(j5[1,]))]
  j5 <- mutate_all(j5, funs(gsub("\\%", "", .)))
  j5 <- j5[, !(j5[1,] == "")]
  
  if (ncol(j5) == 5) {
    names(j5) <- c("county", "tangible_property_delinquent",
                   "real_property_delinquent",
                   "special_delinquent", "total_delinquent")
  } else if (ncol(j5) == 4) {
    names(j5) <- c("county", "real_property_delinquent",
                   "special_delinquent", "total_delinquent")
  }
  # else {
  #   names(j5) <- c("county", "residential_tax_value", "ag_tax_value",
  #                  "indstr_tax_value", "commercial_tax_value",
  #                  "mineral_tax_value","total_tax_value")
  # }
  j5 <- j5 %>% 
    group_by(county) %>% 
    mutate_all(funs(as.numeric(gsub(",", "", gsub("\\$", "", .))))) %>% 
    ungroup()
  j5$county <- tolower(j5$county)
  j5$county <- ifelse(j5$county == "putnum", "putnam", j5$county)
  j5$year <- as.numeric(substr(basename(x), 6, 7))
  # hack for creating a year variable
  j5$year <- ifelse(j5$year < 80, 2000 + j5$year, 1900 + j5$year)
  return(j5)
})

td1_vals <- bind_rows(td1_vals) %>% 
  mutate(county = ifelse(county == "guernesey", "guernsey", county))

td1_vals <- arrange(td1_vals, year, county)

write_csv(td1_vals, paste0(local_dir, "/td1.csv"))
write_rds(td1_vals, paste0(local_dir, "/td1.rds"))


# ---- dte27 --------------------------------------------------------------

dte27 <- folder_create("/dte27", data_source)

# dte27: property tax rates
# Property Tax Rate Abstract by Taxing District 
# Aggregate Property Tax Rate Abstract 
# Millage Rates by School District
# Millage Rates by Joint Vocational School District
# http://www.tax.ohio.gov/tax_analysis/tax_data_series/
#  all_property_taxes/dte27/dte27cy87.aspx
# http://www.tax.ohio.gov/tax_analysis/tax_data_series/
#  publications_tds_property/dte27CY11.aspx

tax_urls <- read_html(tax_site) %>% 
  html_nodes("ul:nth-child(7) a") %>% 
  #html_nodes("ul:nth-child(7) li:nth-child(2) a") %>% 
  html_attr("href") %>% 
  paste0("http://www.tax.ohio.gov", .)


tax_download <- purrr::map(tax_urls, function(x){
  Sys.sleep(sample(seq(0,1,0.25), 1))
  dlinks <- read_html(x) %>% 
    html_nodes("#dnn_ContentPane a") %>% 
    html_attr("href") %>% 
    na.omit() %>% 
    paste0("http://www.tax.ohio.gov", .)
  # Hack, remove the email addresses
  dlinks <- dlinks[!grepl("mailto", dlinks)]
  
  dfile <- paste0(dte27, "/", tolower(basename(dlinks)))
  purrr::map2(dfile, dlinks, function(x, y){
    if (!file.exists(x)) download.file(y, x)
  })
})

######
# SD files - PROBLEM with the 2005 SD excel file... it don't work.
sd_files <- dir(dte27, pattern = "sd_rates", full.names = T)
sd_files <- sd_files[!grepl(".pdf", sd_files)]
sd_files <- sd_files[!grepl("2005", sd_files)]


dte27_sd_vals <- map(sd_files, function(x){
  print(x)
  j5 <- tryCatch(read_xls(x),
                 error = function(e) gdata::read.xls(e))
  starts2 <- apply(j5, 2, function(x) which(grepl("adams", tolower(x))))
  starts <- min(unlist(starts2))
  j5 <- tryCatch(read_xls(x, skip = starts, col_names = F),
                 error = function(e) gdata::read.xls(e, skip = starts,
                                                     header = F))
  # starts <- which(grepl("adams", tolower(j5[[1]])))
  # if (is_empty(starts))
  ends2 <- apply(j5, 2, function(x) which(grepl("wyandot", tolower(x))))
  ends  <- max(unlist(ends2))
  # ends   <- which(grepl("wyandot", tolower(j5[[1]])))
  
  
  # TIBBLE PROBLEMS?
  j5 <- j5[1:max(ends),]
  j5 <- j5[, colSums(is.na(j5)) < nrow(j5)]
  # j5 <- j5[, !(is.na(j5[1,]))]
  # j5 <- mutate_all(j5, funs(gsub("\\%", "", .)))
  # j5 <- j5[, !(j5[1,] == "")]
  
  if (ncol(j5) == 29) {
    names(j5) <- c("county", "school_district", "political_unit", "info_number",
                   "total_rate_gross", "total_rate_class1", "total_rate_class2",
                   "qualifying_nonbusiness_class1", "emergency_rate",
                   "sub_levy_rate", "current_expense_rate_gross",
                   "current_expense_rate_class1", "current_expense_rate_class2",
                   "bond_rate", "general_fund_millage", "recreation_rate_gross",
                   "recreation_rate_class1", "recreation_rate_class2",
                   "improvement_rate_gross", "improvement_rate_class1",
                   "improvement_rate_class2", "library_rate_gross",
                   "library_rate_class1", "library_rate_class2",
                   "safety_rate_gross", "safety_rate_class1",
                   "safety_rate_class2", "mill_floor_rate_class1",
                   "mill_floor_rate_class2")
  } else if (ncol(j5) == 27) {
    names(j5) <- c("political_unit", "county", "school_district", "total_rate_gross",
                   "total_rate_class1", "total_rate_class2",
                   "emergency_rate",
                   "current_expense_rate_gross", "current_expense_rate_class1",
                   "current_expense_rate_class2", "bond_rate",
                   "general_fund_millage", "recreation_rate_gross",
                   "recreation_rate_class1", "recreation_rate_class2",
                   "improvement_rate_gross", "improvement_rate_class1",
                   "improvement_rate_class2", "library_rate_millage",
                   "acquisition_rate", "sub_levy_rate",
                   "safety_rate_gross", "safety_rate_class1",
                   "safety_rate_class2", "mill_floor_rate_class1",
                   "mill_floor_rate_class2", "credit_qualify_rate_class1")
  } else if (ncol(j5) == 25) {
    names(j5) <- c("political_unit", "county", "school_district", "total_rate_gross",
                   "total_rate_class1", "total_rate_class2",
                   "mill_floor_rate_class1", "mill_floor_rate_class2",
                   "emergency_rate",
                   "current_expense_rate_gross", "current_expense_rate_class1",
                   "current_expense_rate_class2", "bond_rate",
                   "general_fund_millage", "recreation_rate_gross",
                   "recreation_rate_class1", "recreation_rate_class2",
                   "improvement_rate_gross", "improvement_rate_class1",
                   "improvement_rate_class2", "library_rate_gross",
                   "library_rate_class1", "library_rate_class2",
                   "acquisition_rate", "sub_levy_rate")
  } else if (ncol(j5) == 23) {
    names(j5) <- c("political_unit", "county", "school_district", "total_rate_gross",
                   "total_rate_class1", "total_rate_class2",
                   "mill_floor_rate_class1", "mill_floor_rate_class2",
                   "emergency_rate",
                   "current_expense_rate_gross", "current_expense_rate_class1",
                   "current_expense_rate_class2", "bond_rate",
                   "general_fund_millage", "recreation_rate_gross",
                   "recreation_rate_class1", "recreation_rate_class2",
                   "improvement_rate_gross", "improvement_rate_class1",
                   "improvement_rate_class2", "library_millage",
                   "acquisition_rate", "sub_levy_rate")
  } else if (ncol(j5) == 22) {
    names(j5) <- c("political_unit", "county", "school_district", "total_rate_gross",
                   "total_rate_class1", "total_rate_class2",
                   "mill_floor_rate_class1", "mill_floor_rate_class2",
                   "emergency_rate",
                   "current_expense_rate_gross", "current_expense_rate_class1",
                   "current_expense_rate_class2", "bond_rate",
                   "general_fund_millage", "recreation_rate_gross",
                   "recreation_rate_class1", "recreation_rate_class2",
                   "improvement_rate_gross", "improvement_rate_class1",
                   "improvement_rate_class2", "library_millage",
                   "acquisition_rate")
  } else if (ncol(j5) == 21) {
    names(j5) <- c("county", "school_district", "total_rate_gross",
                   "total_rate_class1", "total_rate_class2", "emergency_rate",
                   "current_expense_rate_gross", "current_expense_rate_class1",
                   "current_expense_rate_class2", "bond_rate",
                   "general_fund_millage", "recreation_rate_gross",
                   "recreation_rate_class1", "recreation_rate_class2",
                   "improvement_rate_gross", "improvement_rate_class1",
                   "improvement_rate_class2", "library_millage",
                   "library_rate_gross", "library_rate_class1",
                   "library_rate_class2")
  } else if (ncol(j5) == 20 & !is.numeric(unlist(j5[1,1]))) {
    names(j5) <- c("county", "sd_number", "school_district", "total_rate_gross",
                   "total_rate_class1", "total_rate_class2", "emergency_rate",
                   "current_expense_rate_gross", "current_expense_rate_class1",
                   "current_expense_rate_class2", "bond_rate",
                   "general_fund_millage", "recreation_rate_gross",
                   "recreation_rate_class1", "recreation_rate_class2",
                   "improvement_rate_gross", "improvement_rate_class1",
                   "improvement_rate_class2", "library_millage",
                   "acquisition_rate")
  } else if (ncol(j5) == 20 & is.numeric(unlist(j5[1,1]))) {
    names(j5) <- c("sd_number", "county", "school_district", "total_rate_gross",
                   "total_rate_class1", "total_rate_class2", "emergency_rate",
                   "current_expense_rate_gross", "current_expense_rate_class1",
                   "current_expense_rate_class2", "bond_rate",
                   "general_fund_millage", "recreation_rate_gross",
                   "recreation_rate_class1", "recreation_rate_class2",
                   "improvement_rate_gross", "improvement_rate_class1",
                   "improvement_rate_class2", "library_millage",
                   "acquisition_rate")
  } else if (ncol(j5) == 19) {
    names(j5) <- c("county", "sd_number", "school_district", "total_rate_gross",
                   "total_rate_class1", "total_rate_class2", "emergency_rate",
                   "current_expense_rate_gross", "current_expense_rate_class1",
                   "current_expense_rate_class2", "bond_rate",
                   "general_fund_millage", "recreation_rate_gross",
                   "recreation_rate_class1", "recreation_rate_class2",
                   "improvement_rate_gross", "improvement_rate_class1",
                   "improvement_rate_class2", "library_millage")
  }
  
  j5 <- j5 %>% 
    mutate_at(vars(-county, -school_district), parse_number) %>% 
    mutate(county = tolower(county),
           school_district = tolower(school_district),
           county = if_else(county == "putnum", "putnam", county),
           year = parse_number(basename(x))) %>% 
    mutate(year = case_when(year > 1900 ~ year,
                            year > 80 ~ 1900 + year,
                            year < 80 ~ 2000 + year))
  
  return(j5)
})

# 2003 to 2007 the sd_number is actually the political_unit
sd_vals <- dte27_sd_vals %>% 
  bind_rows() %>% 
  mutate(political_unit = if_else(year %in% 2003:2007, sd_number,
                                  political_unit),
         sd_number = if_else(year > 2002, NA_real_, sd_number),
         county = ifelse(county == "guernesey", "guernsey", county)) %>% 
  select(year, county, school_district, sd_number,
         political_unit, info_number, everything()) %>% 
  arrange(year, county)


write_csv(sd_vals, paste0(local_dir, "/dte27_sd.csv"))
write_rds(sd_vals, paste0(local_dir, "/dte27_sd.rds"))


######
# tdrate files - PROBLEM with the 2005 SD excel file... it don't work.
td_files <- dir(dte27, pattern = "tdrate", full.names = T)
td_files <- td_files[!grepl(".exe", td_files)]
td_files <- td_files[!grepl("zip", td_files)]

dte27_td_vals <- map(td_files, function(x){
  print(x)
  j5 <- tryCatch(read_xls(x),
                 error = function(e) gdata::read.xls(e))
  starts2 <- apply(j5, 2, function(x) which(grepl("county", tolower(x))))
  starts <- min(unlist(starts2))
  j5 <- tryCatch(read_xls(x, skip = starts + 1, col_names = F),
                 error = function(e) gdata::read.xls(e, skip = starts + 1,
                                                     header = F))
  ends2 <- apply(j5, 2, function(x) which(grepl("wyandot", tolower(x))))
  ends  <- max(unlist(ends2))
  
  # j5 <- j5[1:max(ends),]
  j5 <- j5[, colSums(is.na(j5)) < nrow(j5)]
  
  if (ncol(j5) == 12) {
    names(j5) <- c("county", "countno", "distno", "distname",
                   "gross", "class1_rate", "class2_rate", "tax50k", "tax75k",
                   "tax100k", "tax150k", "tax200k")
  } else if (ncol(j5) == 11) {
    names(j5) <- c("countno", "distno", "distname",
                   "gross", "class1_rate", "class2_rate", "tax50k", "tax75k",
                   "tax100k", "tax150k", "tax200k")
  }  else if (ncol(j5) == 7) {
    names(j5) <- c("countno", "distno", "distname", "gross",
                   "class1_rate", "class2_rate", "tax100k")
  }
  
  j5 <- j5 %>% 
    mutate(year = parse_number(basename(x))) %>% 
    mutate(year = case_when(year > 1900 ~ year,
                            year > 80 ~ 1900 + year,
                            year < 80 ~ 2000 + year))
  
  return(j5)
})
