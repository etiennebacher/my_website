#####################################################################
## Analyzing the countries of birth and work of Nobel Laureates ##
#####################################################################

library(tidyverse)
library(janitor)
library(ggthemes)
library(gganimate)
library(here)
library(tmap)
library(countrycode)
library(echarts4r)


###########################
## Import the list of Nobel laureates and clean country names##
###########################

nobel_laureates_raw <- read_csv(here("content/post/nobel-laureates/nobel-laureates.csv")) %>%
  janitor::clean_names()


clean_country_names <- function(data, variable) {
  data <- data %>%
    mutate(
      x = gsub(
        "(?<=\\()[^()]*(?=\\))(*SKIP)(*F)|.",
        "",
        {{variable}},
        perl = T
      ),
      x = ifelse(x == "", {{variable}}, x)
    ) %>%
    select(- {{variable}}) %>%
    rename({{variable}} := "x")
}

# difference between dataset on first and second line
nobel_laureates <- clean_country_names(nobel_laureates_raw, birth_country)
nobel_laureates <- clean_country_names(nobel_laureates, death_country)




###########################
## Plot the number of laureates ##
###########################

##########
## Total per country ##
##########

nobel_per_country <- nobel_laureates %>%
  select(birth_country, full_name) %>%
  distinct() %>%
  group_by(birth_country) %>%
  count(sort = TRUE) %>%
  ungroup() %>%
  drop_na()


nobel_per_country %>%
  select(birth_country, n) %>%
  top_n(20) %>%
  mutate(birth_country = reorder(birth_country, n)) %>%
  ggplot(aes(x = birth_country, y = n)) +
  geom_col() +
  coord_flip() +
  xlab("Country") +
  ylab("") +
  geom_text(aes(label = n), nudge_y = 10) +
  ggthemes::theme_clean()


##########
## Evolution per country ##
##########

# The 20 countries with the most nobels
top_20 <- nobel_per_country %>%
  top_n(10) %>%
  select(birth_country) %>%
  unlist(use.names = FALSE)


nobel_per_country_year <- nobel_laureates %>%
  select(year, birth_country) %>%
  group_by(year, birth_country) %>%
  count(sort = TRUE) %>%
  ungroup() %>%
  drop_na() %>%
  arrange(birth_country, year) %>%
  complete(year, birth_country) %>%
  mutate(n = ifelse(is.na(n), 0, n),
         year = as.integer(year)) %>%
  filter(birth_country %in% top_20) %>%
  group_by(birth_country) %>%
  mutate(n_cumul = cumsum(n)) %>%
  arrange(birth_country)


# Evolution in time

plot_evol <- nobel_per_country_year %>%
  select(birth_country, year, n_cumul) %>%
  filter((year %% 2) != 0) %>%
  ggplot(aes(x = reorder(birth_country, n_cumul), y = n_cumul)) +
  geom_col() +
  coord_flip() +
  xlab("Country") +
  ylab("") +
  geom_text(aes(label = as.character(round(n_cumul, 0))), nudge_y = 10) +
  ggthemes::theme_clean() +
  transition_time(year) +
  ggtitle("Year: {frame_time}") +
  ease_aes('linear', interval = 2)

# animate(plot_evol, duration = 15, fps = 20)


###########################
## Maps ##
###########################

##########
## Static ##
##########

data(World)

# Create ISO code
nobel_per_country <- nobel_per_country %>%
  mutate(
    iso_birth = countrycode(birth_country, origin = "country.name", destination = "iso3c"),
    iso_birth = case_when(
      birth_country == "Scotland" | birth_country == "Northern Ireland" ~ "GBR",
      TRUE ~ iso_birth
    )
  )


World <- World %>%
  full_join(nobel_per_country, by = c("iso_a3" = "iso_birth")) %>%
  rename("number" = "n") %>%
  mutate(number = ifelse(is.na(number), 0, number))



tm_shape(World, projection = 4326) +
  tm_fill("number", breaks = c(0, 5, 10, 50, 200, Inf), palette = "YlOrBr") +
  tm_polygons() +
  tm_legend(title = "Nobel prizes per country", legend.title.size = 10^(-4)) +
  tm_layout(legend.outside = TRUE)




##########
## Interactive ##
##########


### echarts

# Without timeline

nobel_per_country_echarts <- e_country_names(data = nobel_per_country,
                                             input = iso_birth,
                                             type = "iso3c")

nobel_per_country_echarts %>%
  e_charts(iso_birth) %>%
  e_map(n) %>%
  e_visual_map(max = max(nobel_per_country_echarts$n))


# With timeline

nobel_per_country_year <- nobel_per_country_year %>%
  mutate(
    iso_birth = countrycode(birth_country, origin = "country.name", destination = "iso3c"),
    iso_birth = case_when(
      birth_country == "Scotland" | birth_country == "Northern Ireland" ~ "GBR",
      TRUE ~ iso_birth
    )
  )


nobel_per_country_year_echarts <- e_country_names(data = nobel_per_country_year,
                                                  input = iso_birth,
                                                  type = "iso3c")

nobel_per_country_year_echarts %>%
  group_by(year) %>%
  e_charts(iso_birth, timeline = TRUE) %>%
  e_map(n_cumul) %>%
  e_visual_map() %>%
  e_timeline_opts(
    playInterval = 500
  )


