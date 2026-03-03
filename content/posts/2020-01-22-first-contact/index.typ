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
  title: "First contact with the data on R",
  description: "A blog post describing the first steps of data cleaning and analysis using R.",
  date: datetime(year: 2020, month: 01, day: 22),
  lang: "en",
)

= First contact with the data on R
<first-contact-with-the-data-on-r>
Note:
In this and future articles, you will see some arrows below R code. If you click on it, it will display the Stata code equivalent to the R code displayed. However, since those are two different softwares, they are not completely equivalent and some of the Stata code may not fully correspond to the R code. Consider it more like a reference point not to be lost rather than like an exact equivalent.

In this post, you will see how to import and treat data, make descriptive statistics and a few plots. I will also show you a personal method to organize one's work.

== Files used and organization of the project
<files-used-and-organization-of-the-project>
First of all, you need to create a project. In RStudio, you can do "File", "New Project" and then choose the location of the project and its name. In the folder that contains the project, I have several sub-folders: Figures, Bases\_Used, Bases\_Created. To be able to save or use files in these particular sub-folders, I use the package #strong[`here`]. The command #strong[`here()`] shows the path to your project and you just need to complete the path to access to your datasets or other files.

#block[
```r
# if you've never installed this package before, do:
# install.packages("here")
library(here)
```

]
Why is this package important? Your code must be reproducible, either for your current collaborators to work efficiently with you or for other people to check your code and to use it in the future. Using paths that work only for your computer (like "/home/Mr X/somefolder/somesubfolder/Project") makes it longer and more annoying to use your code since it requires to manually change paths in order to import data or other files. The package #strong[`here`] makes it much easier to reproduce your code since it automatically detects the path to access to your data. You only need to keep the same structure between R files and datasets. You will see in the next part how to use it.

== Import data
<import-data>
We will use data contained in Excel (#strong[`.xlsx`]) and text (#strong[`.txt`]) files. You can find these files (and the full R script corresponding to this post) #link("https://github.com/etiennebacher/personal_website/tree/master/_posts/2020-01-22-first-contact/")[here]. To import Excel data, we will need the #strong[`readxl`] package.

#block[
```r
library(readxl)
```

]
We use the #strong[`read_excel`] function of this package to import excel files and the function #strong[`read.table`] (in base R) to import the data:

#block[
```r
base1 <- read_excel(here("Bases_Used/Base_Excel.xlsx"), sheet = "Base1")
base2 <- read_excel(here("Bases_Used/Base_Excel.xlsx"), sheet = "Base2")
base3 <- read_excel(here("Bases_Used/Base_Excel.xlsx"), sheet = "Base3")
base4 <- read.table(here("Bases_Used/Base_Text.txt"), header = TRUE)
```

]
#html.elem("details")[
  #html.elem("summary")[
    Stata
  ]

  ```stata
  cd "/path/to/Bases_Used"
  import excel using Base_Excel, sheet("Base1") firstrow
  ```
]
As you can see, if your project is in a folder and if you stored you datasets in the Bases\_Used subfolder, this code will work automatically since #strong[`here`] detects the path. Now, we have stored the four datasets in four objects called #strong[`data.frames`]. To me, this simple thing is an advantage on Stata where storing multiple datasets in the same time is not intuitive at all.

== Merge dataframes
<merge-dataframes>
We want to have a unique dataset to make descriptive statistics and econometrics (we will just do descriptive statistics in this post). Therefore, we will merge these datasets together, first by using the #strong[`dplyr`] package. This package is one of the references for data manipulation. It is extremely useful and much more easy to use than base R. You may find a cheatsheet (i.e.~a recap of the functions) for this package #link("https://rstudio.com/resources/cheatsheets/")[here], along with cheatsheets of many other great packages.

First, we want to regroup #strong[`base1`] and #strong[`base2`]. To do so, we just need to put one under the other and to "stick" them together with #strong[`bind_rows`] and we observe the result:

#block[
```r
library(dplyr)
base_created <- bind_rows(base1, base2)
base_created
```

#block[
```
# A tibble: 23 × 6
    hhid indidy1 surname   name     gender  wage
   <dbl>   <dbl> <chr>     <chr>     <dbl> <dbl>
 1     1       1 BROWN     Robert        1  2000
 2     1       2 JONES     Michael       1  2100
 3     1       3 MILLER    William       1  2300
 4     1       4 DAVIS     David         1  1800
 5     2       1 RODRIGUEZ Mary          2  3600
 6     2       2 MARTINEZ  Patricia      2  3500
 7     2       3 WILSON    Linda         2  1900
 8     2       4 ANDERSON  Richard       1  1900
 9     3       1 THOMAS    Charles       1  1800
10     3       2 TAYLOR    Barbara       2  1890
# ℹ 13 more rows
```

]
]
#html.elem("details")[
  #html.elem("summary")[
    Stata
  ]

  ```stata
  preserve

  *** Open base #2 and bind the rows
  clear all
  import excel using Base_Excel, sheet("Base2") firstrow
  tempfile base2
  save  `base2'
  restore
  append using `base2'
  ```
]
As you can see, we obtain a dataframe with 6 columns (like each table separately) and 23 rows: 18 in the first table, 5 in the second table. Now, we merge this dataframe with #strong[`base3`]. #strong[`base_created`] and #strong[`base3`] only have one column in common (#strong[`hhid`]) so we will need to specify that we want to merge these two bases by this column:

#block[
```r
base_created <- left_join(base_created, base3, by = "hhid")
base_created
```

#block[
```
# A tibble: 23 × 7
    hhid indidy1 surname   name     gender  wage location
   <dbl>   <dbl> <chr>     <chr>     <dbl> <dbl> <chr>   
 1     1       1 BROWN     Robert        1  2000 France  
 2     1       2 JONES     Michael       1  2100 France  
 3     1       3 MILLER    William       1  2300 France  
 4     1       4 DAVIS     David         1  1800 France  
 5     2       1 RODRIGUEZ Mary          2  3600 England 
 6     2       2 MARTINEZ  Patricia      2  3500 England 
 7     2       3 WILSON    Linda         2  1900 England 
 8     2       4 ANDERSON  Richard       1  1900 England 
 9     3       1 THOMAS    Charles       1  1800 Spain   
10     3       2 TAYLOR    Barbara       2  1890 Spain   
# ℹ 13 more rows
```

]
]
#html.elem("details")[
  #html.elem("summary")[
    Stata
  ]

  ```stata
  preserve

  *** Open base #3 and merge
  clear all
  cd ..\Bases_Used
  import excel using Base_Excel, sheet("Base3") firstrow
  tempfile base3
  save `base3'
  restore
  merge m:1 hhid using `base3'
  drop _merge
  ```
]
#strong[`left_join`] is a #strong[`dplyr`] function saying that the first dataframe mentioned (here #strong[`base_created`]) is the "most important" and that we will stick the second one (here #strong[`base3`]) to it. If there are more rows in the first one than in the second one, then there will be some missing values but the number of rows will stay the same. If we knew that #strong[`base3`] had more rows than #strong[`base_created`], we would have used #strong[`right_join`].

We now want to merge #strong[`base_created`] with #strong[`base4`]. The problem is that there are no common columns so we will need to create one in each. Moreover, #strong[`base_created`] contains data for the year 2019 and #strong[`base4`] for the year 2020. We will need to create columns to specify that too:

#block[
```r
# rename the second column of base_created and of base4
colnames(base_created)[2] <- "indid"
colnames(base4)[2] <- "indid"

# create the column "year", that will take the value 2019 
# for base_created and 2020 for base4
base_created$year <- 2019
base4$year <- 2020
```

]
From this point, we can merge these two dataframes:

#block[
```r
base_created2 <- bind_rows(base_created, base4)
base_created2
```

#block[
```
# A tibble: 46 × 8
    hhid indid surname   name     gender  wage location  year
   <dbl> <dbl> <chr>     <chr>     <dbl> <dbl> <chr>    <dbl>
 1     1     1 BROWN     Robert        1  2000 France    2019
 2     1     2 JONES     Michael       1  2100 France    2019
 3     1     3 MILLER    William       1  2300 France    2019
 4     1     4 DAVIS     David         1  1800 France    2019
 5     2     1 RODRIGUEZ Mary          2  3600 England   2019
 6     2     2 MARTINEZ  Patricia      2  3500 England   2019
 7     2     3 WILSON    Linda         2  1900 England   2019
 8     2     4 ANDERSON  Richard       1  1900 England   2019
 9     3     1 THOMAS    Charles       1  1800 Spain     2019
10     3     2 TAYLOR    Barbara       2  1890 Spain     2019
# ℹ 36 more rows
```

]
]
#html.elem("details")[
  #html.elem("summary")[
    Stata
  ]

  ```stata
  rename indidy1 indid
  gen year=2019
  preserve

  * Open base #4 and merge
  clear all
  import delimited Base_Text.txt
  rename indidy2 indid
  gen year=2020
  tempfile base4
  save `base4'
  restore

  merge 1:1 hhid indid year using `base4'
  drop _merge
  ```
]
But we have many missing values for the new rows because #strong[`base4`] only contained three columns. We want to have a data frame arranged by household then by individual and finally by year. Using only #strong[`dplyr`] functions, we can do:

#block[
```r
base_created2 <- base_created2 %>% 
  group_by(hhid, indid) %>% 
  arrange(hhid, indid, year) %>%
  ungroup()
base_created2
```

#block[
```
# A tibble: 46 × 8
    hhid indid surname   name    gender  wage location  year
   <dbl> <dbl> <chr>     <chr>    <dbl> <dbl> <chr>    <dbl>
 1     1     1 BROWN     Robert       1  2000 France    2019
 2     1     1 <NA>      <NA>        NA  2136 <NA>      2020
 3     1     2 JONES     Michael      1  2100 France    2019
 4     1     2 <NA>      <NA>        NA  2362 <NA>      2020
 5     1     3 MILLER    William      1  2300 France    2019
 6     1     3 <NA>      <NA>        NA  2384 <NA>      2020
 7     1     4 DAVIS     David        1  1800 France    2019
 8     1     4 <NA>      <NA>        NA  2090 <NA>      2020
 9     2     1 RODRIGUEZ Mary         2  3600 England   2019
10     2     1 <NA>      <NA>        NA  3784 <NA>      2020
# ℹ 36 more rows
```

]
]
Notice that there are some #strong[`%>%`] between the lines: it is a pipe and its function is to connect lines of code between them so that we don't have to write #strong[`base_created2`] every time. Now that our dataframe is arranged, we need to fill the missing values. Fortunately, these missing values do not change for an individual since they concern the gender, the location, the name and the surname. So basically, we can just take the value of the cell above (corresponding to year 2019) and replicate it in each cell (corresponding to year 2020):

#block[
```r
library(tidyr)
base_created2 <- base_created2 %>%
  fill(select_if(., ~ any(is.na(.))) %>% 
         names(),
       .direction = 'down')
```

]
#html.elem("details")[
  #html.elem("summary")[
    Stata
  ]

  ```stata
  foreach x of varlist surname name gender location {
    bysort hhid indid: replace `x'=`x'[_n-1] if year==2020
  }
  ```
]
Let me explain the code above:

- #strong[`fill`] aims to fill cells
- #strong[`select_if`] selects columns according to the condition defined
- #strong[`any(is.na(.))`] is a logical question asking if there are missing values (NA)
- #strong[`.`] indicates that we want to apply the function to the whole dataframe
- #strong[`names`] tells us what the names of the columns selected are
- #strong[`.direction`] tells the direction in which the filling goes

So #strong[`fill(select_if(., ~ any(is.na(.))) %>% names(), .direction = 'down')`] means that for the dataframe, we select each column which has some NA in it and we obtain their names. In these columns, the empty cells are filled by the value of the cell above (since the direction is "down").

Finally, we want the first three columns to be #strong[`hhid`], #strong[`indid`] and #strong[`year`], and we create a ID column named #strong[`hhind`] which is just the union of #strong[`hhid`] and #strong[`indid`].

#block[
```r
base_created2 <- base_created2 %>%
  select(hhid, indid, year, everything()) %>%
  unite(hhind, c(hhid, indid), sep = "", remove = FALSE) 
base_created2
```

#block[
```
# A tibble: 46 × 9
   hhind  hhid indid  year surname   name    gender  wage location
   <chr> <dbl> <dbl> <dbl> <chr>     <chr>    <dbl> <dbl> <chr>   
 1 11        1     1  2019 BROWN     Robert       1  2000 France  
 2 11        1     1  2020 BROWN     Robert       1  2136 France  
 3 12        1     2  2019 JONES     Michael      1  2100 France  
 4 12        1     2  2020 JONES     Michael      1  2362 France  
 5 13        1     3  2019 MILLER    William      1  2300 France  
 6 13        1     3  2020 MILLER    William      1  2384 France  
 7 14        1     4  2019 DAVIS     David        1  1800 France  
 8 14        1     4  2020 DAVIS     David        1  2090 France  
 9 21        2     1  2019 RODRIGUEZ Mary         2  3600 England 
10 21        2     1  2020 RODRIGUEZ Mary         2  3784 England 
# ℹ 36 more rows
```

]
]
#html.elem("details")[
  #html.elem("summary")[
    Stata
  ]

  ```stata
  egen hhind=group(hhid indid)
  order hhind hhid indid year *
  sort hhid indid year
  ```
]
That's it, we now have the complete dataframe.

== Clean the data
<clean-the-data>
There are still some things to do. First, we remark that there are some errors in the column #strong[`location`] (#strong[`England_error`] and #strong[`Spain_error`]) so we correct it:

#block[
```r
# display the unique values of the column "location"
unique(base_created2$location)
```

#block[
```
[1] "France"        "England"       "Spain"         "Italy"        
[5] "England_error" "Spain_error"  
```

]
```r
# correct the errors
base_created2[base_created2 == "England_error"] <- "England"
base_created2[base_created2 == "Spain_error"] <- "Spain"
unique(base_created2$location)
```

#block[
```
[1] "France"  "England" "Spain"   "Italy"  
```

]
]
#html.elem("details")[
  #html.elem("summary")[
    Stata
  ]

  ```stata
  replace localisation="England" if localisation=="England_error"
  replace localisation="Spain" if localisation=="Spain_error"
  ```
]
Basically, what we've done here is that we have selected every cell in the whole dataframe that had the value #strong[`England_error`] (respectively #strong[`Spain_error`]) and we replaced these cells by #strong[`England`] (#strong[`Spain`]). We also need to recode the column #strong[`gender`] because binary variables have to take values of 0 or 1, not 1 or 2.

#block[
```r
base_created2$gender <- recode(base_created2$gender, `2` = 0)
```

]
#html.elem("details")[
  #html.elem("summary")[
    Stata
  ]

  ```stata
  label define genderlab 1 "M" 2 "F"
  label values gender genderlab
  recode gender (2=0 "Female") (1=1 "Male"), gen(gender2)
  drop gender
  rename gender2 gender
  ```
]
To have more details on the dataframe, we need to create some labels. To do so, we need the #strong[`upData`] function in the #strong[`Hmisc`] package.

#block[
```r
library(Hmisc)
var.labels <- c(hhind = "individual's ID",
                hhid = "household's ID",
                indid = "individual's ID in the household",
                year = "year",
                surname = "surname",
                name = "name",
                gender = "1 if male, 0 if female",
                wage = "wage",
                location = "household's location")
base_created2 <- upData(base_created2, labels = var.labels)
```

]
#html.elem("details")[
  #html.elem("summary")[
    Stata
  ]

  ```stata
  label variable hhind "individual's ID"
  label variable indid "household's ID"
  label variable year "year"
  label variable hhid "individual's ID in the household"
  label variable surname "Surname"
  label variable name "Name"
  label variable gender "1 if male, 0 if female"
  label variable wage "wage"
  label variable location "household's location"
  ```
]
We can see the result with:

#block[
```r
contents(base_created2)
```

#block[
```

Data frame:base_created2    46 observations and 9 variables    Maximum # NAs:0

                                   Labels     Class   Storage
hhind                     individual's ID character character
hhid                       household's ID   integer   integer
indid    individual's ID in the household   integer   integer
year                                 year   integer   integer
surname                           surname character character
name                                 name character character
gender             1 if male, 0 if female   integer   integer
wage                                 wage   integer   integer
location             household's location character character
```

]
]
Now that our dataframe is clean and detailed, we can compute some descriptive statistics. But before doing it, we might want to save it:

#block[
```r
write.xlsx(base_created2, file = here("Bases_Created/modified_base.xlsx")
```

]
#html.elem("details")[
  #html.elem("summary")[
    Stata
  ]

  ```stata
  cd ..\Bases_Created
  export excel using "modified_base.xls", replace
  ```
]
== Descriptive Statistics
<descriptive-statistics>
First of all, if we want to check the number of people per location or gender and per year, we use the #strong[`table`] function:

#block[
```r
table(base_created2$gender, base_created2$year)
```

#block[
```
   
    2019 2020
  0    9    9
  1   14   14
```

]
```r
table(base_created2$location, base_created2$year)
```

#block[
```
         
          2019 2020
  England    6    6
  France    12   12
  Italy      1    1
  Spain      4    4
```

]
]
#html.elem("details")[
  #html.elem("summary")[
    Stata
  ]

  ```stata
  tab gender if year==2019
  tab location if year==2019
  ```
]
To have more detailed statistics, you can use many functions. Here, we use the function #strong[`describe`] from the #strong[`Hmisc`] package

#block[
```r
describe(base_created2)
```

#block[
```
base_created2 

 9  Variables      46  Observations
--------------------------------------------------------------------------------
hhind : individual's ID 
       n  missing distinct 
      46        0       23 

lowest : 11 12 13 14 21, highest: 71 72 81 82 83
--------------------------------------------------------------------------------
hhid : household's ID 
       n  missing distinct     Info     Mean  pMedian      Gmd 
      46        0        8    0.975    4.217        4    2.783 
                                                          
Value          1     2     3     4     5     6     7     8
Frequency      8     8     4     2    10     4     4     6
Proportion 0.174 0.174 0.087 0.043 0.217 0.087 0.087 0.130
--------------------------------------------------------------------------------
indid : individual's ID in the household 
       n  missing distinct     Info     Mean  pMedian      Gmd 
      46        0        5    0.923    2.217        2    1.306 
                                        
Value          1     2     3     4     5
Frequency     16    14     8     6     2
Proportion 0.348 0.304 0.174 0.130 0.043
--------------------------------------------------------------------------------
year 
       n  missing distinct     Info     Mean 
      46        0        2     0.75     2020 
                    
Value      2019 2020
Frequency    23   23
Proportion  0.5  0.5
--------------------------------------------------------------------------------
surname 
       n  missing distinct 
      46        0       23 

lowest : ANDERSON BROWN    DAVIS    DOE      JACKSON 
highest: THOMAS   THOMPSON WHITE    WILLIAMS WILSON  
--------------------------------------------------------------------------------
name 
       n  missing distinct 
      46        0       23 

lowest : Barbara Charles Daniel  David   Donald 
highest: Richard Robert  Susan   Thomas  William
--------------------------------------------------------------------------------
gender : 1 if male, 0 if female 
       n  missing distinct     Info      Sum     Mean 
      46        0        2    0.715       28   0.6087 

--------------------------------------------------------------------------------
wage 
       n  missing distinct     Info     Mean  pMedian      Gmd      .05 
      46        0       37    0.998     2059     1934    477.4     1627 
     .10      .25      .50      .75      .90      .95 
    1692     1800     1901     2098     2373     3575 

lowest : 1397 1600 1608 1683 1690, highest: 2384 3500 3600 3782 3784
--------------------------------------------------------------------------------
location : household's location 
       n  missing distinct 
      46        0        4 
                                          
Value      England  France   Italy   Spain
Frequency       12      24       2       8
Proportion   0.261   0.522   0.043   0.174
--------------------------------------------------------------------------------
```

]
]
#html.elem("details")[
  #html.elem("summary")[
    Stata
  ]

  ```stata
  sum *, detail
  ```
]
but you can also try the function #strong[`summary`] (automatically available in base R), #strong[`stat.desc`] in #strong[`pastecs`], #strong[`skim`] in #strong[`skimr`] or even #strong[`makeDataReport`] in #strong[`dataMaid`] to have a complete PDF report summarizing your data. To summarize data under certain conditions (e.g.~to have the average wage for each location), you can use #strong[`dplyr`]:

#block[
```r
# you can change the argument in group_by() by gender for example
base_created2 %>%
  group_by(location) %>%
  summarize_at(.vars = "wage", .funs = "mean")
```

#block[
```
# A tibble: 4 × 2
  location    wage
  <labelled> <dbl>
1 England    2452.
2 France     1935.
3 Italy      1801 
4 Spain      1905.
```

]
]
#html.elem("details")[
  #html.elem("summary")[
    Stata
  ]

  ```stata
  tabstat wage if year==2019, stats(N mean sd min max p25 p50 p75) by(location)
  tabstat wage if year==2020, stats(N mean sd min max p25 p50 p75) by(location)
  ```
]
== Plots
<plots>
Finally, we want to plot some data to include in our report or article (or anything else). #strong[`ggplot2`] is THE reference to make plots with R. The #strong[`ggplot`] function does not create a graph but tells what is the data you are going to use and the aesthetics (#strong[`aes`]). Here, we want to display the wages in a histogram and to distinguish them per year. Therefore, we want to fill the bars according to the year. To precise the type of graph we want, we add #strong[`+ geom_histogram()`] after #strong[`ggplot`]. You may change the number of #strong[`bins`] to have a more precise histogram.

```r
library(ggplot2)
hist1 <- ggplot(data = base_created2, 
                mapping = aes(wage, fill = factor(year))) +
  geom_histogram(bins = 10)
hist1
```

#box(image("index_files/figure-typst/unnamed-chunk-20-1.svg"))

#html.elem("details")[
  #html.elem("summary")[
    Stata
  ]

  ```stata
  histogram wage if year==2019, saving(Hist1, replace) bin(10) freq title("Year 2019") ytitle("Frequency")
  histogram wage if year==2020, saving(Hist2, replace) bin(10) freq title("Year 2020") ytitle("Frequency")
  ```
]
If you prefer one histogram per year, you can use the #strong[`facet_wrap()`] argument, as below.

```r
hist2 <- ggplot(data = base_created2, 
                mapping = aes(wage, fill = factor(year))) +
  geom_histogram(bins = 10) +
  facet_wrap(vars(year))
hist2
```

#box(image("index_files/figure-typst/unnamed-chunk-21-1.svg"))

#html.elem("details")[
  #html.elem("summary")[
    Stata
  ]

  ```stata
  graph combine Hist1.gph Hist2.gph, col(2) xsize(10) ysize(5) iscale(1.5) title("{bf:Wage distribution per year}")
  ```
]
Finally, you may want to export these graphs. To do so, we use #strong[`ggsave`] (you can replace .pdf by .eps or .png if you want):

#block[
```r
ggsave(here("Figures/plot1.pdf"), plot = hist1)
```

]
#html.elem("details")[
  #html.elem("summary")[
    Stata
  ]

  ```stata
  graph export Histogram1.pdf,  replace
  ```
]
That's it! In this first post, you have seen how to import, clean and tidy datasets, and how to make some descriptive statistics and some plots. I hope this was helpful to you!

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
   package      * version    date (UTC) lib source
   backports      1.5.0      2024-05-23 [1] RSPM
   base64enc      0.1-6      2026-02-02 [1] RSPM
   cellranger     1.1.0      2016-07-27 [1] RSPM
   checkmate      2.3.4      2026-02-03 [1] RSPM
   cli            3.6.5      2025-04-23 [1] RSPM (R 4.5.0)
   cluster        2.1.8.1    2025-03-12 [2] CRAN (R 4.5.0)
   colorspace     2.1-2      2025-09-22 [1] RSPM (R 4.5.0)
   data.table     1.18.2.1   2026-01-27 [1] RSPM
   digest         0.6.39     2025-11-19 [1] RSPM (R 4.5.0)
   dplyr        * 1.2.0.9000 2026-03-01 [1] Github (tidyverse/dplyr@8730221)
   evaluate       1.0.5      2025-08-27 [1] RSPM (R 4.5.0)
   farver         2.1.2      2024-05-13 [1] RSPM
   fastmap        1.2.0      2024-05-15 [1] RSPM
   foreign        0.8-90     2025-03-31 [2] CRAN (R 4.5.0)
   Formula        1.2-5      2023-02-24 [1] RSPM
   generics       0.1.4      2025-05-09 [1] RSPM (R 4.5.0)
   ggplot2      * 4.0.2      2026-02-03 [1] RSPM
   glue           1.8.0      2024-09-30 [1] RSPM
   gridExtra      2.3        2017-09-09 [1] RSPM
   gtable         0.3.6      2024-10-25 [1] RSPM
   here         * 1.0.2      2025-09-15 [1] RSPM (R 4.5.0)
   Hmisc        * 5.2-5      2026-01-09 [1] RSPM (R 4.5.0)
   htmlTable      2.4.3      2024-07-21 [1] RSPM
   htmltools      0.5.9      2025-12-04 [1] RSPM
   htmlwidgets    1.6.4      2023-12-06 [1] RSPM
   jsonlite       2.0.0      2025-03-27 [1] RSPM (R 4.5.0)
   knitr          1.51       2025-12-20 [1] RSPM
   labeling       0.4.3      2023-08-29 [1] RSPM
   lifecycle      1.0.5      2026-01-08 [1] RSPM (R 4.5.0)
   magrittr       2.0.4      2025-09-12 [1] RSPM (R 4.5.0)
   nnet           7.3-20     2025-01-01 [2] CRAN (R 4.5.0)
   otel           0.2.0      2025-08-29 [1] RSPM (R 4.5.0)
   pillar         1.11.1     2025-09-17 [1] RSPM (R 4.5.0)
   pkgconfig      2.0.3      2019-09-22 [1] RSPM
   purrr          1.2.1      2026-01-09 [1] RSPM (R 4.5.0)
   R6             2.6.1      2025-02-15 [1] RSPM
   RColorBrewer   1.1-3      2022-04-03 [1] RSPM
   readxl       * 1.4.5      2025-03-07 [1] RSPM (R 4.5.0)
   rlang          1.1.7.9000 2026-03-01 [1] Github (r-lib/rlang@74733f3)
   rmarkdown      2.30       2025-09-28 [1] RSPM
   rpart          4.1.24     2025-01-07 [2] CRAN (R 4.5.0)
   rprojroot      2.1.1      2025-08-26 [1] RSPM (R 4.5.0)
   rstudioapi     0.18.0     2026-01-16 [1] RSPM (R 4.5.0)
   S7             0.2.1      2025-11-14 [1] RSPM
   scales         1.4.0      2025-04-24 [1] RSPM
   sessioninfo    1.2.3      2025-02-05 [1] RSPM
   stringi        1.8.7      2025-03-27 [1] RSPM
   stringr        1.6.0      2025-11-04 [1] RSPM (R 4.5.0)
   tibble         3.3.1      2026-01-11 [1] RSPM (R 4.5.0)
   tidyr        * 1.3.2      2025-12-19 [1] CRAN (R 4.5.0)
   tidyselect     1.2.1      2024-03-11 [1] RSPM
   utf8           1.2.6      2025-06-08 [1] RSPM (R 4.5.0)
   vctrs          0.7.1      2026-01-23 [1] RSPM
   withr          3.0.2      2024-10-28 [1] RSPM
   xfun           0.56       2026-01-18 [1] RSPM
   yaml           2.3.12     2025-12-10 [1] RSPM
  
   [1] /home/etienne/R/x86_64-pc-linux-gnu-library/4.5
   [2] /opt/R/4.5.0/lib/R/library
   * ── Packages attached to the search path.
  
  ──────────────────────────────────────────────────────────────────────────────
  ```
  
  
  :::
  :::

]



