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
  title: "Some notes about improving base R code",
  description: "A small collection of tips to make base R code faster.",
  date: datetime(year: 2022, month: 11, day: 28),
  lang: "en",
)

= Some notes about improving base R code
<some-notes-about-improving-base-r-code>
Preview image coming from: https:\/\/trainingindustry.com/magazine/nov-dec-2018/life-in-the-fast-lane-accelerated-continuous-development-for-fast-paced-organizations/

Lately I've spent quite some time on packages that require (almost) only base R:

- `datawizard`, a package belonging to the `easystats` ecosystem, whose goal is to provide tools for data wrangling and statistical transformations;
- `poorman`, whose goal is to reproduce `tidyverse` functions (with a strong focus on `dplyr`) using base R only.

I've used `bench::mark()` and `profvis::profvis()` a lot to improve code performance and here are a few things I learnt. By default, `bench::mark()` checks that all expressions return the same output, so we can be confident that the alternatives I show in this post are truly equivalent.

Before we start, I want to precise a few things.

First, these performance improvements are targeted to package developers. A random user shouldn't really care if a function takes 200 milliseconds less to run. However, I think a package developer might find these tips interesting.

Second, if you find some ways to speed up my alternatives, feel free to comment. I know that there are a bunch of packages whose reputation is built on being very fast (for example `data.table` and `collapse`). I'm only showing some base R code alternatives here.

Finally, here's a small function that I use to make a classic dataset (like `iris` or `mtcars`) much bigger.

#block[
```r
make_big <- function(data, nrep = 500000) {
  tmp <- vector("list", length = nrep)
  for (i in 1:nrep) {
    tmp[[i]] <- data
  }
  
  data.table::rbindlist(tmp) |> 
    as.data.frame()
}
```

]
== Check if a vector has a single value
<check-if-a-vector-has-a-single-value>
One easy way to do this is to run `length(unique(x)) == 1`, which basically means that first we have to collect all unique values and then count them. This can be quite inefficient: it would be enough to stop as soon as we find two different values.

What we can do is to compare all values to the first value of the vector. Below is an example with a vector containing 10 million values. In the first case, it only contains `1`, and in the second case it contains `1` and `2`.

#block[
```r
# Should be TRUE
test <- rep(1, 1e7)

bench::mark(
  length(unique(test)) == 1,
  all(test == test[1]),
  iterations = 10
)
```

#block[
```
Warning: Some expressions had a GC in every iteration; so filtering is
disabled.
```

]
#block[
```
# A tibble: 2 × 6
  expression                     min   median `itr/sec` mem_alloc `gc/sec`
  <bch:expr>                <bch:tm> <bch:tm>     <dbl> <bch:byt>    <dbl>
1 length(unique(test)) == 1  132.8ms  136.5ms      7.21   166.1MB     7.21
2 all(test == test[1])        30.2ms   30.6ms     30.5     38.1MB     9.16
```

]
```r
# Should be FALSE
test2 <- rep(c(1, 2), 1e7)

bench::mark(
  length(unique(test2)) == 1,
  all(test2 == test2[1]),
  iterations = 10
)
```

#block[
```
Warning: Some expressions had a GC in every iteration; so filtering is
disabled.
```

]
#block[
```
# A tibble: 2 × 6
  expression                      min   median `itr/sec` mem_alloc `gc/sec`
  <bch:expr>                 <bch:tm> <bch:tm>     <dbl> <bch:byt>    <dbl>
1 length(unique(test2)) == 1  256.8ms  265.6ms      3.72   332.3MB     3.72
2 all(test2 == test2[1])       44.7ms   46.1ms     19.6     76.3MB     3.91
```

]
]
This is also faster for character vectors:

#block[
```r
# Should be FALSE
test3 <- rep(c("a", "b"), 1e7)

bench::mark(
  length(unique(test3)) == 1,
  all(test3 == test3[1]),
  iterations = 10
)
```

#block[
```
Warning: Some expressions had a GC in every iteration; so filtering is
disabled.
```

]
#block[
```
# A tibble: 2 × 6
  expression                      min   median `itr/sec` mem_alloc `gc/sec`
  <bch:expr>                 <bch:tm> <bch:tm>     <dbl> <bch:byt>    <dbl>
1 length(unique(test3)) == 1  247.4ms  256.3ms      3.71   332.3MB     3.71
2 all(test3 == test3[1])       56.8ms   58.8ms     15.6     76.3MB     3.13
```

]
]
== Concatenate columns
<concatenate-columns>
Sometimes we need to concatenate columns, for example if we want to create a unique id from several grouping columns.

#block[
```r
test <- data.frame(
  origin = c("A", "B", "C"),
  destination = c("Z", "Y", "X"),
  value = 1:3
)

test <- make_big(test)
```

]
One option to do this is to combine `paste()` and `apply()` using `MARGIN = 1` to apply `paste()` to each row. However, a faster way to do this is to use `do.call()` instead of `apply()`:

#block[
```r
bench::mark(
  apply = apply(test[, c("origin", "destination")], 1, paste, collapse = "_"),
  do.call = do.call(paste, c(test[, c("origin", "destination")], sep = "_"))
)
```

#block[
```
Warning: Some expressions had a GC in every iteration; so filtering is
disabled.
```

]
#block[
```
# A tibble: 2 × 6
  expression      min   median `itr/sec` mem_alloc `gc/sec`
  <bch:expr> <bch:tm> <bch:tm>     <dbl> <bch:byt>    <dbl>
1 apply         4.04s    4.04s     0.248    80.1MB     9.41
2 do.call    126.96ms 127.58ms     7.83     11.4MB     0   
```

]
]
== Giving attributes to large dataframes
<giving-attributes-to-large-dataframes>
This one comes from these #link("https://stackoverflow.com/questions/74029805/why-does-adding-attributes-to-a-dataframe-take-longer-with-large-dataframes")[StackOverflow question and answer]. Manipulating a dataframe can remove some attributes. For example, if I give an attribute `foo` to a large dataframe:

#block[
```r
orig <- data.frame(x1 = rep(1, 1e7), x2 = rep(2, 1e7))
attr(orig, "foo") <- TRUE
attr(orig, "foo")
```

#block[
```
[1] TRUE
```

]
]
If I reorder the columns, this attribute disappears:

#block[
```r
new <- orig[, c(2, 1)]
attr(new, "foo")
```

#block[
```
NULL
```

]
]
We can put it back with:

#block[
```r
attributes(new) <- utils::modifyList(attributes(orig), attributes(new))
attr(new, "foo")
```

#block[
```
[1] TRUE
```

]
]
But this takes some time because we also copy the 10M row names of the dataset. Therefore, one option is to create a custom function that only copies the attributes that were in `orig` but are not in `new` (in this case, only attribute `foo` is concerned):

#block[
```r
replace_attrs <- function(obj, new_attrs) {
  for(nm in setdiff(names(new_attrs), names(attributes(data.frame())))) {
    attr(obj, which = nm) <- new_attrs[[nm]]
  }
  return(obj)
}

bench::mark(
  old = {
    attributes(new) <- utils::modifyList(attributes(orig), attributes(new))
    head(new)
  },
  new = {
    new <- replace_attrs(new, attributes(orig))
    head(new)
  }
)
```

#block[
```
# A tibble: 2 × 6
  expression      min   median `itr/sec` mem_alloc `gc/sec`
  <bch:expr> <bch:tm> <bch:tm>     <dbl> <bch:byt>    <dbl>
1 old          32.8ms   41.8ms      24.9    38.2MB     3.12
2 new          43.5µs     47µs   19415.     23.5KB    14.7 
```

]
]
== Find empty rows
<find-empty-rows>
It can be useful to remove empty rows, meaning rows containing only `NA` or `""`. We could once again use `apply()` with `MARGIN = 1`, but a faster way is to use `rowSums()`. First, we create a data frame full of `TRUE`/`FALSE` with `is.na(test) | test == ""`, and then we count by row the number of `TRUE`. If this number is equal to the number of columns, then it means that the row only has `NA` or `""`.

#block[
```r
test <- data.frame(
  a = c(1, 2, 3, NA, 5),
  b = c("", NA, "", NA, ""),
  c = c(NA, NA, NA, NA, NA),
  d = c(1, NA, 3, NA, 5),
  e = c("", "", "", "", ""),
  f = factor(c("", "", "", "", "")),
  g = factor(c("", NA, "", NA, "")),
  stringsAsFactors = FALSE
)

test <- make_big(test, 100000)

bench::mark(
  apply = which(apply(test, 1, function(i) all(is.na(i) | i == ""))),
  rowSums = which(rowSums((is.na(test) | test == "")) == ncol(test))
)
```

#block[
```
Warning: Some expressions had a GC in every iteration; so filtering is
disabled.
```

]
#block[
```
# A tibble: 2 × 6
  expression      min   median `itr/sec` mem_alloc `gc/sec`
  <bch:expr> <bch:tm> <bch:tm>     <dbl> <bch:byt>    <dbl>
1 apply         1.27s    1.27s     0.785   112.9MB     6.28
2 rowSums    282.67ms 287.59ms     3.48     99.7MB     0   
```

]
]
== Conclusion
<conclusion>
These were just a few tips I discovered. Maybe there are ways to make them even faster in base R? Or maybe you know some weird/hidden tips? If so, feel free to comment below!
