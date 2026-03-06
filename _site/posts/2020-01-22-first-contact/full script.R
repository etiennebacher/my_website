library(here)
library(readxl)
library(dplyr)
library(tidyr)
library(Hmisc)
library(ggplot2)

## Import

base1 <- read_excel(here("Bases_Used/Base_Excel.xlsx"), sheet = "Base1")
base2 <- read_excel(here("Bases_Used/Base_Excel.xlsx"), sheet = "Base2")
base3 <- read_excel(here("Bases_Used/Base_Excel.xlsx"), sheet = "Base3")
base4 <- read.table(here("Bases_Used/Base_Text.txt"), header = TRUE)

## Merge

base_created <- bind_rows(base1, base2) %>%
  left_join(base_created, base3, by = "hhid")
base_created

colnames(base_created)[2] <- "indid"
colnames(base4)[2] <- "indid"
base_created$year <- 2019
base4$year <- 2020

base_created2 <- bind_rows(base_created, base4) %>% 
  group_by(hhid, indid) %>% 
  arrange(hhid, indid, year) %>%
  ungroup() %>%
  fill(select_if(., ~ any(is.na(.))) %>% 
         names(),
       .direction = 'down') %>%
  select(hhid, indid, year, everything()) %>%
  unite(hhind, c(hhid, indid), sep = "", remove = FALSE) 
base_created2

## Clean and correct

unique(base_created2$location)
base_created2[base_created2 == "England_error"] <- "England"
base_created2[base_created2 == "Spain_error"] <- "Spain"
unique(base_created2$location)

base_created2$gender <- recode(base_created2$gender, `2` = 0)

var.labels <- c(hhind = "individual's ID",
                hhid = "household's ID",
                indid = "individual's ID in the household",
                year = "year",
                surname = "surname",
                name = "name",
                gender = "1 if male, 0 if female",
                wage = "wage",
                location = "location")
base_created2 <- upData(base_created2, labels = var.labels)
contents(base_created2)

write.xlsx(base_created2, file = paste(base_created_dir, "modified_base.xlsx", sep = ""))

## Stats

table(base_created2$gender, base_created2$year)
table(base_created2$location, base_created2$year)
summary(base_created2)
base_created2 %>%
  group_by(location) %>%
  summarize_at(.vars = "wage", .funs = "mean")
  
## Plots

hist1 <- ggplot(data = base_created2, 
                mapping = aes(wage, fill = factor(year))) +
  geom_histogram(bins = 10)
hist1

hist2 <- ggplot(data = base_created2, 
                mapping = aes(wage)) +
  geom_histogram(bins = 10) +
  facet_grid(cols = vars(year), scales = "fixed")
hist2

ggsave(paste(figdir, "plot1.pdf", sep = ""), plot = hist1)
