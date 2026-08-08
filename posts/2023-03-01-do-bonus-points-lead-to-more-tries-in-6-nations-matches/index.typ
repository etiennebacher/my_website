#import "/.calepin/calepin.typ" as calepin

#set document(title: [Do bonus points lead to more tries in 6 Nations matches?])
#metadata((
  title: "Do bonus points lead to more tries in 6 Nations matches?",
  kind: "post",
  date: "2023-03-01",
  summary: "A small post where rugby is an excuse to do some webscraping and some ggplot-ing.",
)) <website-metadata>

// Code blocks in these posts are already-rendered output from the original
// Quarto build, not live chunks. Keep Calepin from executing them.
#calepin.setup(eval: false, fenced-chunks: false)

#title()

The 6 Nations is a rugby tournament that takes place every year in February-March between the six strongest national teams in Europe: England, France, Ireland, Italy, Scotland, and Wales. Each team plays against the other five. A victory gives 4 points, a draw gives 2 points, and a loss gives 0 point.

In 2017, bonus points were introduced:

- a try bonus point: you get one extra point if you score 4 tries or more during the match, whatever the final result;
- a losing bonus point: you get one extra point if you lose the match by 7 points or less.

Therefore, a victory can now give you 5 points maximum and a loss can give you 1 point. Additionally, a team that makes the Grand Slam (wins all 5 matches) gets a bonus of 3 points#calepin.elements.sidenote[This is to ensure that a team that makes the Grand Slam also wins the tournament.].

The idea behind these new rules were to improve the drama by pushing teams to score more tries. In this post, I'd like to check if we saw an increase in the number of tries since 2017.

I'm not going to make a deep exploration or to find whether or not there is a true causal effect between this new rule and the number of tries. It's just a good pretext to do some scraping and some graphs.

= Getting the data
<getting-the-data>
```r
library(rvest)
library(tidyverse)
```

```
── Attaching core tidyverse packages ──────────────────────── tidyverse 2.0.0 ──
✔ dplyr     1.2.0.9000     ✔ readr     2.1.6     
✔ forcats   1.0.1          ✔ stringr   1.6.0     
✔ ggplot2   4.0.2          ✔ tibble    3.3.1     
✔ lubridate 1.9.5          ✔ tidyr     1.3.2     
✔ purrr     1.2.1          
── Conflicts ────────────────────────────────────────── tidyverse_conflicts() ──
✖ dplyr::filter()         masks stats::filter()
✖ readr::guess_encoding() masks rvest::guess_encoding()
✖ dplyr::lag()            masks stats::lag()
ℹ Use the conflicted package (<http://conflicted.r-lib.org/>) to force all conflicts to become errors
```

```r
library(patchwork)
```

I didn't find a clean dataset with the results for the latest editions, so we can scrape the #link("https://www.espn.co.uk/rugby/table/_/league/180659/season/2022")[ESPN website] instead. It only goes back to 2008 but it will do the job.

The URLs are identical except for the tournament year. Once we get the HTML for one year, we can extract the table with its CSS classes, and then format it nicely with `html_table()`.

```r
results <- list()
for (i in 2008:2022) {
  print(paste0("Scraping year ", i))
  html <- read_html(
    paste0("https://www.espn.co.uk/rugby/table/_/league/180659/season/", i)
  )
  countries <- html |> 
    html_element(css = "div.ResponsiveTable.ResponsiveTable--fixed-left > div.flex > table") |>
    html_table() 
  names(countries) <- "country"

  res <- html |> 
    html_element(css = "div.Table__ScrollerWrapper") |> 
    html_table()
  
  results[[as.character(i)]] <- bind_cols(countries, res) |> 
    mutate(year = i)
}
```

```
[1] "Scraping year 2008"
[1] "Scraping year 2009"
[1] "Scraping year 2010"
[1] "Scraping year 2011"
[1] "Scraping year 2012"
[1] "Scraping year 2013"
[1] "Scraping year 2014"
[1] "Scraping year 2015"
[1] "Scraping year 2016"
[1] "Scraping year 2017"
[1] "Scraping year 2018"
[1] "Scraping year 2019"
[1] "Scraping year 2020"
[1] "Scraping year 2021"
[1] "Scraping year 2022"
```

We can then aggregate this list into a single dataframe.

```r
all_results <- data.table::rbindlist(results) |>
  mutate(
    country = case_when(
      grepl("Wales", country) ~ "Wales",
      grepl("England", country) ~ "England",
      grepl("Italy", country) ~ "Italy",
      grepl("France", country) ~ "France",
      grepl("Scotland", country) ~ "Scotland",
      grepl("Ireland", country) ~ "Ireland"
    )
  )
```

= Plotting the data
<plotting-the-data>
First, let's see the total number of tries for each year.

```r
FONT <- "Cinzel"

showtext::showtext_auto()
sysfonts::font_add_google(FONT)

theme_custom <- function(...) {
  theme_light() +
  theme(
    panel.grid.minor = element_blank(),
    text = element_text(family = FONT)
  )
}

labs <- list(
  x = "Year",
  y = "Tries per year"
)

all_results |> 
  summarise(tries_per_year = sum(TF), .by = year) |> 
  ggplot(aes(year, tries_per_year)) +
  geom_point(color = "black", fill = "#99b3e6", shape = 21, size = 2.5) +
  geom_vline(xintercept = 2016.5, linetype = "dashed") +
  ylim(c(0, 100)) +
  labs(
    title = "Number of tries per tournament",
    x = labs$x,
    y = labs$y
  ) +
  theme_custom() +
  theme(
    axis.title = element_text(size = 28),
    axis.text = element_text(size = 25),
    plot.title = element_text(size = 35)
  )
```

#box(image("index_files/figure-typst/unnamed-chunk-4-1.svg"))

We see an increase in the number of tries, but this upward trend started before 2017, putting into question the real causal effect of this new rule. Was this increase similar for all countries?

```r
plots <- list()
for (i in unique(all_results$country)) {
  
  main_color <- switch(i,
    "Ireland" = "#339966",
    "France" = "#0044cc",
    "England" = "white",
    "Wales" = "#cc0000",
    "Scotland" = "#00004d",
    "Italy" = "#1a1aff"
  )
  
  text_color <- switch(i,
    "Ireland" = "white",
    "France" = "white",
    "England" = "red",
    "Wales" = "white",
    "Scotland" = "white",
    "Italy" = "white"
  )
  
  plots[[i]] <-
    all_results |>
    filter(country == i) |>
    mutate(after = as.numeric(year >= 2017)) |>
    rename(tries_per_year = TF) |>
    mutate(
      mean = mean(tries_per_year), .by = after
    ) |>
    mutate(
      mean_before = ifelse(after == 0, mean, NA),
      mean_after = ifelse(after == 1, mean, NA)
    ) |>
    ggplot(aes(year, tries_per_year)) +
    geom_point(
      color = "black", 
      fill = ifelse(main_color == "white", text_color, main_color), 
      alpha = 0.3, 
      shape = 21, 
      size = 2.5
    ) +
    geom_line(
      aes(y = mean_before), 
      linetype = "longdash", 
      color = ifelse(main_color == "white", text_color, main_color), 
      linewidth = 0.8
    ) +
    geom_line(
      aes(y = mean_after), 
      linetype = "longdash", 
      color = ifelse(main_color == "white", text_color, main_color), 
      linewidth = 0.8
    ) +
    geom_vline(xintercept = 2016.5, linetype = "dotted") +
    ylim(c(0, 30)) +
    labs(
      x = labs$x,
      y = labs$y
    ) +
    facet_grid(. ~ country) +
    theme_custom() +
    theme(
      strip.background = element_rect(fill = main_color, color = "black"),
      strip.text = element_text(size = 36, colour = text_color),
      axis.title = element_text(size = 28),
      axis.text = element_text(size = 25)
    )
}

wrap_plots(plots, ncol = 2)
```

#box(image("patchwork.png"))

The dashed lines before and after 2017 show the average number of tries per country and per tournament. We can see that, on average, all teams scored more tries after 2017 than before 2017.

However, this change is very heterogenous: some countries had a large increase (Ireland, Scotland), some had a moderate change (France, England), and other didn't seem to be affected a lot (Wales, Italy).
