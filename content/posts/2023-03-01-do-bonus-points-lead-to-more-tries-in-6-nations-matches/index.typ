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
  title: "Do bonus points lead to more tries in 6 Nations matches?",
  description: "A small post where rugby is an excuse to do some webscraping and some ggplot-ing.",
  date: datetime(year: 2023, month: 03, day: 01),
  lang: "en",
)

= Do bonus points lead to more tries in 6 Nations matches?
<do-bonus-points-lead-to-more-tries-in-6-nations-matches>
The 6 Nations is a rugby tournament that takes place every year in February-March between the six strongest national teams in Europe: England, France, Ireland, Italy, Scotland, and Wales. Each team plays against the other five. A victory gives 4 points, a draw gives 2 points, and a loss gives 0 point.

In 2017, bonus points were introduced:

- a try bonus point: you get one extra point if you score 4 tries or more during the match, whatever the final result;
- a losing bonus point: you get one extra point if you lose the match by 7 points or less.

Therefore, a victory can now give you 5 points maximum and a loss can give you 1 point. Additionally, a team that makes the Grand Slam (wins all 5 matches) gets a bonus of 3 points#footnote[This is to ensure that a team that makes the Grand Slam also wins the tournament.].

The idea behind these new rules were to improve the drama by pushing teams to score more tries. In this post, I'd like to check if we saw an increase in the number of tries since 2017.

I'm not going to make a deep exploration or to find whether or not there is a true causal effect between this new rule and the number of tries. It's just a good pretext to do some scraping and some graphs.

= Getting the data
<getting-the-data>
#block[
```r
library(rvest)
library(tidyverse)
```

#block[
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

]
```r
library(patchwork)
```

]
I didn't find a clean dataset with the results for the latest editions, so we can scrape the #link("https://www.espn.co.uk/rugby/table/_/league/180659/season/2022")[ESPN website] instead. It only goes back to 2008 but it will do the job.

The URLs are identical except for the tournament year. Once we get the HTML for one year, we can extract the table with its CSS classes, and then format it nicely with `html_table()`.

#block[
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

#block[
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

]
]
We can then aggregate this list into a single dataframe.

#block[
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

]
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

#block[
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

]
#box(image("patchwork.png"))

The dashed lines before and after 2017 show the average number of tries per country and per tournament. We can see that, on average, all teams scored more tries after 2017 than before 2017.

However, this change is very heterogenous: some countries had a large increase (Ireland, Scotland), some had a moderate change (France, England), and other didn't seem to be affected a lot (Wales, Italy).
