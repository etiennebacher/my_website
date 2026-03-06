// Simple numbering for non-book documents
#let equation-numbering = "(1)"
#let callout-numbering = "1"
#let subfloat-numbering(n-super, subfloat-idx) = {
  numbering("1a", n-super, subfloat-idx)
}

// Theorem configuration for theorion
// Simple numbering for non-book documents (no heading inheritance)
#let theorem-inherited-levels = 0

// Theorem numbering format (can be overridden by extensions for appendix support)
// This function returns the numbering pattern to use
#let theorem-numbering(loc) = "1.1"

// Default theorem render function
#let theorem-render(prefix: none, title: "", full-title: auto, body) = {
  if full-title != "" and full-title != auto and full-title != none {
    strong[#full-title.]
    h(0.5em)
  }
  body
}
// Some definitions presupposed by pandoc's typst output.
#let content-to-string(content) = {
  if content.has("text") {
    content.text
  } else if content.has("children") {
    content.children.map(content-to-string).join("")
  } else if content.has("body") {
    content-to-string(content.body)
  } else if content == [ ] {
    " "
  }
}

#let horizontalrule = line(start: (25%,0%), end: (75%,0%))

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

// Use nested show rule to preserve list structure for PDF/UA-1 accessibility
// See: https://github.com/quarto-dev/quarto-cli/pull/13249#discussion_r2678934509
#show terms: it => {
  show terms.item: item => {
    set text(weight: "bold")
    item.term
    block(inset: (left: 1.5em, top: -0.4em))[#item.description]
  }
  it
}

// Prevent breaking inside definition items, i.e., keep term and description together.
#show terms.item: set block(breakable: false)

// Some quarto-specific definitions.

#show raw.where(block: true): set block(
    fill: luma(230),
    width: 100%,
    inset: 8pt,
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let fields = old_block.fields()
  let _ = fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.abs
  }
  block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == str {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == content {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => {
          let subfloat-idx = quartosubfloatcounter.get().first() + 1
          subfloat-numbering(n-super, subfloat-idx)
        })
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => block({
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          })

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != str {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let children = old_title_block.body.body.children
  let old_title = if children.len() == 1 {
    children.at(0)  // no icon: title at index 0
  } else {
    children.at(1)  // with icon: title at index 1
  }

  // TODO use custom separator if available
  // Use the figure's counter display which handles chapter-based numbering
  // (when numbering is a function that includes the heading counter)
  let callout_num = it.counter.display(it.numbering)
  let new_title = if empty(old_title) {
    [#kind #callout_num]
  } else {
    [#kind #callout_num: #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block,
    block_with_new_content(
      old_title_block.body,
      if children.len() == 1 {
        new_title  // no icon: just the title
      } else {
        children.at(0) + new_title  // with icon: preserve icon block + new title
      }))

  align(left, block_with_new_content(old_callout,
    block(below: 0pt, new_title_block) +
    old_callout.body.children.at(1)))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black, body_background_color: white) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color,
        width: 100%,
        inset: 8pt)[#if icon != none [#text(icon_color, weight: 900)[#icon] ]#title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: body_background_color, width: 100%, inset: 8pt, body))
      }
    )
}




#let article(
  title: none,
  subtitle: none,
  authors: none,
  keywords: (),
  date: none,
  abstract-title: none,
  abstract: none,
  thanks: none,
  cols: 1,
  lang: "en",
  region: "US",
  font: none,
  fontsize: 11pt,
  title-size: 1.5em,
  subtitle-size: 1.25em,
  heading-family: none,
  heading-weight: "bold",
  heading-style: "normal",
  heading-color: black,
  heading-line-height: 0.65em,
  mathfont: none,
  codefont: none,
  linestretch: 1,
  sectionnumbering: none,
  linkcolor: none,
  citecolor: none,
  filecolor: none,
  toc: false,
  toc_title: none,
  toc_depth: none,
  toc_indent: 1.5em,
  doc,
) = {
  // Set document metadata for PDF accessibility
  set document(title: title, keywords: keywords)
  set document(
    author: authors.map(author => content-to-string(author.name)).join(", ", last: " & "),
  ) if authors != none and authors != ()
  set par(
    justify: true,
    leading: linestretch * 0.65em
  )
  set text(lang: lang,
           region: region,
           size: fontsize)
  set text(font: font) if font != none
  show math.equation: set text(font: mathfont) if mathfont != none
  show raw: set text(font: codefont) if codefont != none

  set heading(numbering: sectionnumbering)

  show link: set text(fill: rgb(content-to-string(linkcolor))) if linkcolor != none
  show ref: set text(fill: rgb(content-to-string(citecolor))) if citecolor != none
  show link: this => {
    if filecolor != none and type(this.dest) == label {
      text(this, fill: rgb(content-to-string(filecolor)))
    } else {
      text(this)
    }
   }

  place(
    top,
    float: true,
    scope: "parent",
    clearance: 4mm,
    block(below: 1em, width: 100%)[

      #if title != none {
        align(center, block(inset: 2em)[
          #set par(leading: heading-line-height) if heading-line-height != none
          #set text(font: heading-family) if heading-family != none
          #set text(weight: heading-weight)
          #set text(style: heading-style) if heading-style != "normal"
          #set text(fill: heading-color) if heading-color != black

          #text(size: title-size)[#title #if thanks != none {
            footnote(thanks, numbering: "*")
            counter(footnote).update(n => n - 1)
          }]
          #(if subtitle != none {
            parbreak()
            text(size: subtitle-size)[#subtitle]
          })
        ])
      }

      #if authors != none and authors != () {
        let count = authors.len()
        let ncols = calc.min(count, 3)
        grid(
          columns: (1fr,) * ncols,
          row-gutter: 1.5em,
          ..authors.map(author =>
              align(center)[
                #author.name \
                #author.affiliation \
                #author.email
              ]
          )
        )
      }

      #if date != none {
        align(center)[#block(inset: 1em)[
          #date
        ]]
      }

      #if abstract != none {
        block(inset: 2em)[
        #text(weight: "semibold")[#abstract-title] #h(1em) #abstract
        ]
      }
    ]
  )

  if toc {
    let title = if toc_title == none {
      auto
    } else {
      toc_title
    }
    block(above: 0em, below: 2em)[
    #outline(
      title: toc_title,
      depth: toc_depth,
      indent: toc_indent
    );
    ]
  }

  doc
}

#set table(
  inset: 6pt,
  stroke: none
)
#let brand-color = (:)
#let brand-color-background = (:)
#let brand-logo = (:)

#set page(
  paper: "us-letter",
  margin: (x: 1.25in, y: 1.25in),
  numbering: "1",
  columns: 1,
)

#show: doc => article(
  toc_title: [Table of contents],
  toc_depth: 3,
  doc,
)
#import "../index.typ": template, tufted
#import "@preview/lilaq:0.5.0" as lq
// 如需生成 RSS feed，必须填写 title、description 和 date 元数据
#show: template.with(
  title: "Visualize data on Nobel laureates per country",
  description: "A post where I make animated graphs and maps to visualize the repartition of Nobel laureates per country.",
  date: datetime(year: 2020, month: 10, day: 18),
  lang: "en",
)

= Visualize data on Nobel laureates per country
<visualize-data-on-nobel-laureates-per-country>
The Nobel laureates of 2020 were announced last week, and I thought it would be interesting to visualize the repartition of laureates per country, as there are several ways to do so. I'm going to use #link("https://www.kaggle.com/nobelfoundation/nobel-laureates")[this dataset] available on Kaggle, which contains information on the year, category, name of the laureate, country, city and date of birth and death, among other things. Notice that this dataset goes from 1901 to 2016 and therefore doesn't contain the most recent laureates.

But first of all, we need to load all the packages we will use in this analysis:

#block[
```r
library(tidyverse)
library(janitor)
library(ggthemes)
library(gganimate)
library(here)
library(tmap)
library(countrycode)
library(echarts4r)
```

]
== Import and clean data
<import-and-clean-data>
Now, we can import the dataset. To remove the capital letters and transform the column names in snake case (i.e names such as "column\_name" instead of "Column Name"), we can use the function `clean_names()` of the package `{janitor}` #footnote[This function is very useful even when column names are much more messy.]:

#block[
```r
nobel_laureates_raw <- read_csv("nobel-laureates.csv") %>%
  janitor::clean_names()
```

]
The first thing that we have to correct before doing visualization concerns the country names. Indeed, many countries have changed since 1901. For example, Czechoslovakia no longer exists, as well as Prussia. In this dataset, the columns containing country names display first the official name at the time, and then put the current name of the country between brackets.

#block[
#block[
```
# A tibble: 6 × 2
  birth_country     death_country
  <chr>             <chr>        
1 Netherlands       Germany      
2 France            France       
3 Prussia (Poland)  Germany      
4 Switzerland       Switzerland  
5 France            France       
6 Prussia (Germany) Germany      
```

]
]
Since we only want the current country names, we must modify these columns so that:

- if the name doesn't have brackets (i.e the country hasn't changed in time), we let it as-is;

- if the name has brackets (i.e the country has changed), we only want to keep the name between brackets.

Since I must do this for two columns (`birth_country` and `death_country`), I created a function (and this was the perfect example of losing way too much time by making a function to save time…):

#block[
```r
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
```

]
This function takes a dataset (`data`), and creates a new column (`x`) that will take the name between brackets if original variable has brackets, or the unique name if the original variable doesn't have brackets. Then, `x` is renamed as the variable we specified first. I must admit that regular expressions (such as the one in `gsub()`) continue to be a big mystery for me, and I thank StackOverflow for providing many examples.

Now, we apply this function to our columns with countries:

#block[
```r
nobel_laureates <- clean_country_names(nobel_laureates_raw, birth_country)
nobel_laureates <- clean_country_names(nobel_laureates, death_country)
```

]
The country names are now cleaned:

#block[
#block[
```
# A tibble: 6 × 2
  birth_country death_country
  <chr>         <chr>        
1 Netherlands   Germany      
2 France        France       
3 Poland        Germany      
4 Switzerland   Switzerland  
5 France        France       
6 Germany       Germany      
```

]
]
From now on, there are several ways to visualize the repartition of Nobel laureates per country. We could do a static bar plot, an animated bar plot to see the evolution in time, a static map, or an interactive map.

== Plot the data
<plot-the-data>
=== Static plot
<static-plot>
First of all, we need to compute the number of Nobel laureates per country:

#block[
```r
nobel_per_country <- nobel_laureates %>%
  select(birth_country, full_name) %>%
  distinct() %>%
  group_by(birth_country) %>%
  count(sort = TRUE) %>%
  ungroup() %>%
  drop_na()
```

]
Then we can plot this number, only for the first 20 countries (so that the plot can be readable):

```r
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
```

#box(image("index_files/figure-typst/unnamed-chunk-9-1.svg"))

We can also check the repartition per country and per category:

```r
# The 20 countries with the most nobels
top_20 <- nobel_per_country %>%
  top_n(10) %>%
  select(birth_country) %>%
  unlist(use.names = FALSE)

nobel_laureates %>%
  select(birth_country, full_name, category) %>%
  distinct() %>%
  group_by(birth_country, category) %>%
  mutate(n = n()) %>%
  ungroup() %>%
  drop_na() %>%
  select(- full_name) %>%
  distinct() %>%
  filter(birth_country %in% top_20) %>%
  ggplot(aes(x = birth_country, y = n)) +
  geom_col() +
  coord_flip() +
  xlab("Country") +
  ylab("") +
  geom_text(aes(label = n), nudge_y = 10) +
  ggthemes::theme_clean() +
  facet_wrap(~category)
```

#box(image("index_files/figure-typst/unnamed-chunk-10-1.svg"))

=== Animated plots
<animated-plots>
To observe the evolution of this number in time, one way would be to plot lines with `year` in x-axis. But we could also keep the first plot we made and animate it with `{gganimate}`.

First, we compute the cumulated sum of Nobel laureates. Indeed, the number of laureates per year is useless for us, we want to see the evolution of the total number:

#block[
```r
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
```

]
Then, we use almost the same code as for the first plot, but we add arguments at the end that tell how we want the animation to be:

```r
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

animate(plot_evol, duration = 15, fps = 20)
```

#box(image("index_files/figure-typst/unnamed-chunk-12-1.gif"))

This allows us to see that the USA have seen their number of Nobel laureates surge from the 1960's and 1970's, which corresponds more or less to the creation of the so-called "Nobel Prize in Economics" in 1969. The plot per category also indicates that this prize plays a major role in the domination of the USA.

== Maps
<maps>
=== Static maps
<static-maps>
To create maps, we rely on the package `{tmap}`. In addition to its functions, this package also gives access to a dataset that we will use to show the number of laureates per country.

#block[
```r
data(World)
```

]
We need to merge our dataset of Nobel laureates with this dataset. But the country names differ. Therefore, we have to use ISO codes instead. `World` already contains ISO codes, so we only have to create those for our dataset. This can be done very easily with the package `{countrycode}`. However, some countries in our dataset don't have ISO codes, such as Scotland, Northern Ireland or Czechoslovakia. The two former can be recoded as United Kingdom, but Czechoslovakia was located on current Slovakia, Czech Republic and Ukraine, so we drop it of our dataset.

#block[
```r
nobel_per_country <- nobel_per_country %>%
  mutate(
    iso_birth = countrycode(birth_country, origin = "country.name", destination = "iso3c"),
    iso_birth = case_when(
      birth_country == "Scotland" | birth_country == "Northern Ireland" ~ "GBR",
      TRUE ~ iso_birth
    )
  )
```

]
We can now merge the two datasets based on their ISO codes…

#block[
```r
World <- World %>%
  full_join(nobel_per_country, by = c("iso_a3" = "iso_birth")) %>%
  rename("number" = "n") %>%
  mutate(number = ifelse(is.na(number), 0, number))
```

]
… and we can build the map and fill the countries with the number of laureates:

```r
tm_shape(World, crs = 4326) +
  tm_polygons(fill = "number", fill.scale = tm_scale_intervals(
    breaks = c(0, 5, 10, 50, 200, Inf),
    values = "YlOrBr"
  )) +
  tm_legend(title = "Nobel prizes per country", legend.title.size = 10^(-4)) +
  tm_layout(legend.outside = TRUE)
```

#box(image("index_files/figure-typst/unnamed-chunk-16-1.svg"))

=== Interactive maps
<interactive-maps>
Finally, we will make interactive maps with `{echarts4r}`. Firstly, let's make an identical map as the one above but with a few interactive features.

`{echarts4r}` uses specific country names, so we use once again `{countrycode}` to modify the names in our dataset.

#block[
```r
nobel_per_country_echarts <- e_country_names(data = nobel_per_country,
                                             input = iso_birth,
                                             type = "iso3c")
```

]
Now we can plot the map:

```r
nobel_per_country_echarts %>%
  e_charts(iso_birth) %>%
  e_map(n, roam = TRUE) %>%
  e_visual_map(max = max(nobel_per_country_echarts$n))
```

#box(image("index_files/figure-typst/unnamed-chunk-18-1.png"))

Hovering the countries gives us their name, and the number of laureates in the legend. We can also zoom in and out. We could see the evolution of laureates in time with `timeline = TRUE`:

```r
nobel_per_country_year_map <- nobel_laureates %>%
  select(year, birth_country) %>%
  group_by(year, birth_country) %>%
  count(sort = TRUE) %>%
  ungroup() %>%
  drop_na() %>%
  arrange(birth_country, year) %>%
  complete(year, birth_country) %>%
  mutate(n = ifelse(is.na(n), 0, n),
         year = as.integer(year)) %>%
  group_by(birth_country) %>%
  mutate(n_cumul = cumsum(n)) %>%
  arrange(birth_country)

nobel_per_country_year_map <- nobel_per_country_year_map %>%
  mutate(
    iso_birth = countrycode(birth_country, origin = "country.name", destination = "iso3c"),
    iso_birth = case_when(
      birth_country == "Scotland" | birth_country == "Northern Ireland" ~ "GBR",
      TRUE ~ iso_birth
    )
  )

nobel_per_country_year_echarts <- e_country_names(data = nobel_per_country_year_map,
                                                  input = iso_birth,
                                                  type = "iso3c")

nobel_per_country_year_echarts %>%
  group_by(year) %>%
  e_charts(iso_birth, timeline = TRUE) %>%
  e_map(n_cumul, roam = TRUE) %>%
  e_visual_map(max = 257) %>%
  e_timeline_opts(
    playInterval = 250,
    symbol = "none"
  )
```

#box(image("index_files/figure-typst/unnamed-chunk-19-1.png"))

And that's it! I used data about Nobel laureates to present a few plots and maps made with `{ggplot2}`, `{gganimate}`, `{tmap}`, and `{echarts4r}`. I used these packages but there are countless ways to make plots or maps, whether static or interactive, with R:

- plots: base R, `{highcharter}`, `{charter}`, `{plotly}`, etc.

- maps: base R, `{leaflet}`, `{sf}`, `{ggmap}`, etc.

I hope you enjoyed it!

#html.elem("details")[
  #html.elem("summary")[
    Session Info
  ]

  This is my session info, so that you can see the versions of packages used. This is useful if the results in my post are no longer reproducible because packages changed. The packages with a star are those explicitely called in the script.


  ::: {.cell}
  ::: {.cell-output .cell-output-stdout}
  
  ```
  ─ Session info ───────────────────────────────────────────────────────────────
   setting  value
   version  R version 4.5.0 (2025-04-11)
   os       Ubuntu 24.04.4 LTS
   system   x86_64, linux-gnu
   ui       X11
   language (EN)
   collate  en_US.UTF-8
   ctype    en_US.UTF-8
   tz       Europe/Paris
   date     2026-03-03
   pandoc   3.6.3 @ /usr/share/positron/resources/app/quarto/bin/tools/x86_64/ (via rmarkdown)
   quarto   1.9.27 @ /opt/quarto/bin/quarto
  
  ─ Packages ───────────────────────────────────────────────────────────────────
   package        * version    date (UTC) lib source
   abind            1.4-8      2024-09-12 [1] RSPM
   base64enc        0.1-6      2026-02-02 [1] RSPM
   bit              4.6.0      2025-03-06 [1] RSPM
   bit64            4.6.0-1    2025-01-16 [1] RSPM
   chromote         0.5.1      2025-04-24 [1] RSPM
   class            7.3-23     2025-01-01 [2] CRAN (R 4.5.0)
   classInt         0.4-11     2025-01-08 [1] RSPM
   cli              3.6.5      2025-04-23 [1] RSPM (R 4.5.0)
   codetools        0.2-20     2024-03-31 [2] CRAN (R 4.5.0)
   colorspace       2.1-2      2025-09-22 [1] RSPM (R 4.5.0)
   cols4all         0.10       2025-10-27 [1] RSPM
   countrycode    * 1.6.1      2025-03-31 [1] RSPM
   crayon           1.5.3      2024-06-20 [1] RSPM
   crosstalk        1.2.2      2025-08-26 [1] RSPM (R 4.5.0)
   data.table       1.18.2.1   2026-01-27 [1] RSPM
   DBI              1.2.3      2024-06-02 [1] RSPM
   digest           0.6.39     2025-11-19 [1] RSPM (R 4.5.0)
   dplyr          * 1.2.0.9000 2026-03-01 [1] Github (tidyverse/dplyr@8730221)
   e1071            1.7-17     2025-12-18 [1] RSPM
   echarts4r      * 0.4.3      2022-01-03 [1] CRAN (R 4.5.0)
   evaluate         1.0.5      2025-08-27 [1] RSPM (R 4.5.0)
   farver           2.1.2      2024-05-13 [1] RSPM
   fastmap          1.2.0      2024-05-15 [1] RSPM
   forcats        * 1.0.1      2025-09-25 [1] RSPM (R 4.5.0)
   generics         0.1.4      2025-05-09 [1] RSPM (R 4.5.0)
   gganimate      * 1.0.11     2025-09-04 [1] RSPM
   ggplot2        * 4.0.2      2026-02-03 [1] RSPM
   ggthemes       * 5.2.0      2025-11-30 [1] RSPM
   glue             1.8.0      2024-09-30 [1] RSPM
   gtable           0.3.6      2024-10-25 [1] RSPM
   here           * 1.0.2      2025-09-15 [1] RSPM (R 4.5.0)
   hms              1.1.4      2025-10-17 [1] RSPM (R 4.5.0)
   htmltools        0.5.9      2025-12-04 [1] RSPM
   htmlwidgets      1.6.4      2023-12-06 [1] RSPM
   httpuv           1.6.16     2025-04-16 [1] RSPM (R 4.5.0)
   janitor        * 2.2.1      2024-12-22 [1] RSPM
   jsonlite         2.0.0      2025-03-27 [1] RSPM (R 4.5.0)
   KernSmooth       2.23-26    2025-01-01 [2] CRAN (R 4.5.0)
   knitr            1.51       2025-12-20 [1] RSPM
   labeling         0.4.3      2023-08-29 [1] RSPM
   later            1.4.6      2026-02-13 [1] RSPM
   lattice          0.22-9     2026-02-09 [1] RSPM
   leafem           0.2.5      2025-08-28 [1] RSPM
   leaflegend       1.2.1      2024-05-09 [1] RSPM
   leaflet          2.2.3      2025-09-04 [1] RSPM
   leafsync         0.1.0      2019-03-05 [1] RSPM
   lifecycle        1.0.5      2026-01-08 [1] RSPM (R 4.5.0)
   logger           0.4.1      2025-09-11 [1] RSPM
   lubridate      * 1.9.5      2026-02-04 [1] RSPM (R 4.5.0)
   lwgeom           0.2-15     2026-01-12 [1] RSPM
   magick           2.9.1      2026-02-28 [1] RSPM
   magrittr         2.0.4      2025-09-12 [1] RSPM (R 4.5.0)
   maptiles         0.11.0     2025-12-12 [1] RSPM
   microbenchmark   1.5.0      2024-09-04 [1] RSPM
   mime             0.13       2025-03-17 [1] RSPM
   otel             0.2.0      2025-08-29 [1] RSPM (R 4.5.0)
   pillar           1.11.1     2025-09-17 [1] RSPM (R 4.5.0)
   pkgconfig        2.0.3      2019-09-22 [1] RSPM
   png              0.1-8      2022-11-29 [1] RSPM
   prettyunits      1.2.0      2023-09-24 [1] RSPM
   processx         3.8.6      2025-02-21 [1] RSPM
   progress         1.2.3      2023-12-06 [1] RSPM
   promises         1.5.0      2025-11-01 [1] RSPM (R 4.5.0)
   proxy            0.4-29     2025-12-29 [1] RSPM
   ps               1.9.1      2025-04-12 [1] CRAN (R 4.5.0)
   purrr          * 1.2.1      2026-01-09 [1] RSPM (R 4.5.0)
   R6               2.6.1      2025-02-15 [1] RSPM
   raster           3.6-32     2025-03-28 [1] RSPM
   RColorBrewer     1.1-3      2022-04-03 [1] RSPM
   Rcpp             1.1.1      2026-01-10 [1] RSPM (R 4.5.0)
   readr          * 2.1.6      2025-11-14 [1] RSPM (R 4.5.0)
   rlang            1.1.7.9000 2026-03-01 [1] Github (r-lib/rlang@74733f3)
   rmarkdown        2.30       2025-09-28 [1] RSPM
   rprojroot        2.1.1      2025-08-26 [1] RSPM (R 4.5.0)
   s2               1.1.9      2025-05-23 [1] RSPM
   S7               0.2.1      2025-11-14 [1] RSPM
   scales           1.4.0      2025-04-24 [1] RSPM
   sessioninfo      1.2.3      2025-02-05 [1] RSPM
   sf               1.0-24     2026-01-13 [1] RSPM
   shiny            1.12.1     2025-12-09 [1] RSPM
   snakecase        0.11.1     2023-08-27 [1] RSPM
   sp               2.2-1      2026-02-13 [1] RSPM (R 4.5.0)
   spacesXYZ        1.6-0      2025-06-06 [1] RSPM
   stars            0.7-1      2026-02-13 [1] RSPM
   stringi          1.8.7      2025-03-27 [1] RSPM
   stringr        * 1.6.0      2025-11-04 [1] RSPM (R 4.5.0)
   terra            1.8-93     2026-01-12 [1] RSPM
   tibble         * 3.3.1      2026-01-11 [1] RSPM (R 4.5.0)
   tidyr          * 1.3.2      2025-12-19 [1] CRAN (R 4.5.0)
   tidyselect       1.2.1      2024-03-11 [1] RSPM
   tidyverse      * 2.0.0      2023-02-22 [1] RSPM
   timechange       0.4.0      2026-01-29 [1] RSPM (R 4.5.0)
   tmap           * 4.2        2025-09-10 [1] RSPM
   tmaptools        3.3        2025-07-24 [1] RSPM
   tweenr           2.0.3      2024-02-26 [1] RSPM
   tzdb             0.5.0      2025-03-15 [1] RSPM
   units            1.0-0      2025-10-09 [1] RSPM
   utf8             1.2.6      2025-06-08 [1] RSPM (R 4.5.0)
   vctrs            0.7.1      2026-01-23 [1] RSPM
   vroom            1.7.0      2026-01-27 [1] RSPM
   webshot          0.5.5      2023-06-26 [1] RSPM
   webshot2         0.1.2      2025-04-23 [1] RSPM
   websocket        1.4.4      2025-04-10 [1] RSPM
   withr            3.0.2      2024-10-28 [1] RSPM
   wk               0.9.5      2025-12-18 [1] RSPM
   xfun             0.56       2026-01-18 [1] RSPM
   XML              3.99-0.22  2026-02-10 [1] RSPM
   xtable           1.8-4      2019-04-21 [1] RSPM
   yaml             2.3.12     2025-12-10 [1] RSPM
  
   [1] /home/etienne/R/x86_64-pc-linux-gnu-library/4.5
   [2] /opt/R/4.5.0/lib/R/library
   * ── Packages attached to the search path.
  
  ──────────────────────────────────────────────────────────────────────────────
  ```
  
  
  :::
  :::

]



