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
  title: "Using property-based testing in R",
  description: "When you don't want to write dozens of versions of unit tests.",
  date: datetime(year: 2024, month: 10, day: 01),
  lang: "en",
)

= Using property-based testing in R
<using-property-based-testing-in-r>
I had never heard of property-based testing until a few months ago when I started looking at some pull requests in #link("https://github.com/pola-rs/polars/")[polars] (the Python implementation, not the R one) where they use #link("https://hypothesis.readthedocs.io/en/latest/")[hypothesis], for example #link("https://github.com/pola-rs/polars/pull/17992/files#diff-728b25c64b205cf575fb186611d9e63eff7cd1ea2c32cf811a6e68d6e3d0f4bc")[polars\#17992].

I have contributed to a fair amount of R packages but I have never seen this type of tests before: unit tests, plenty; snapshot tests, sometimes; but property-based tests? Never. And at first, I didn't really see the point, but I've had a couple of situations recently where I thought it could help, so the aim of this post is to explain (briefly) what property-based testing is and to provide some examples where it can be useful.

== What is property-based testing?
<what-is-property-based-testing>
Most of the time, unit tests check that the function performs well on a few different inputs: does it give correct results? Nice error messages? What about this corner case?

Property-based testing is a way of testing where we give random inputs to the function we want to test and we want to ensure that no matter the inputs, the output will respect some properties. For example, suppose we made a function to reverse the input, so if I pass `3, 1, 4`, it should return `4, 1, 3`#footnote[Example taken from the Rust crate #link("https://github.com/BurntSushi/quickcheck")[`quickcheck`].]. We can pass several inputs and see if the output is correctly reversed. But a more efficient way would be to check that our function respects a basic property, which is that #emph[reversing the input twice should return the original input]:

#block[
```r
rev(rev(c(3, 1, 4)))
```

#block[
```
[1] 3 1 4
```

]
]
Therefore, property-based testing doesn't use hardcoded values to check the output but ensures that our function respects a list of properties.

== Property-based testing in R
<property-based-testing-in-r>
To the best of my knowledge, there are two R packages to do property-based testing in R: #link("https://cran.r-project.org/web/packages/hedgehog/")[`hedgehog`] and #link("https://cran.r-project.org/web/packages/quickcheck/")[`quickcheck`] (which is based on `hedgehog`). If you already use `testthat` for testing, then integrating them in the test suite is not hard. Using the example above, we could do:

#block[
```r
library(quickcheck)
library(testthat)

test_that("reversing twice returns the original input", {
  for_all(
    a = numeric_(any_na = TRUE),
    property = function(a) {
      expect_equal(rev(rev(a)), a)
    }
  )
})
```

#block[
```
Test passed with 1 success 🎉.
```

]
]
This example generated 100 random inputs and checked that the `expect_equal()` clause was respected for all of them. We can see that by adding a `print()` call (I reduce the number of tests to 5 to avoid too much clutter).

#block[
```r
test_that("reversing twice returns the original input", {
  for_all(
    a = numeric_(any_na = TRUE),
    tests = 5,
    property = function(a) {
      print(a)
      expect_equal(rev(rev(a)), a)
    }
  )
})
```

#block[
```
[1]  180299485         NA  169233443 -556327963  671813836 -172893223  650735145
[8]          0         NA
[1] -7477 -3579    NA
[1] -750718822  762579998  288089702  305956068          0         NA
[1] -153870964 -603204715 -104236120  855887186         NA         NA -156238835
[8]         NA
[1]  -65501381 -577303308         NA          0         NA         NA  243810326
[8]  921447592
Test passed with 1 success 🎉.
```

]
]
As we can see, a lot of different examples were generated: some have single values while other have multiple, some only have negative values while others have a mix, etc.

The example above checked only on numeric inputs, but we could check on any type of vector using `any_atomic()`:

#block[
```r
test_that("reversing twice returns the original input", {
  for_all(
    a = any_atomic(any_na = TRUE),
    tests = 5,
    property = function(a) {
      print(a)
      expect_equal(rev(rev(a)), a)
    }
  )
})
```

#block[
```
[1] "Sz4y$L.V" NA         NA         "-"        "B"       
07:01:15.942289
09:19:36.781132
09:25:10.975813
22:06:55.508066
             NA
             NA
03:28:01.363436
08:08:18.982272
[1] -945034635  561650411  862721611          0
[1] FALSE FALSE FALSE FALSE FALSE FALSE FALSE    NA
[1] -995090807 -500356911          0 -703492650 -551443511          0         NA
Test passed with 1 success 🥇.
```

]
]
Finally, if a particular input fails, `quickcheck` will first try to reduce the size of this input as much as possible (a process called "shrinking"). To illustrate that, let's say we make a function to normalize a numeric vector to a \[0, 1\] interval:

#block[
```r
normalize <- function(x) {
  (x - min(x)) / (max(x) - min(x))
}

normalize(c(-1, 2, 0, -4))
```

#block[
```
[1] 0.5000000 1.0000000 0.6666667 0.0000000
```

]
]
One property of this function is that all output values should be in the interval \[0, 1\]. Does this function pass property-based tests?

#block[
```r
test_that("output is in interval [0, 1]", {
  for_all(
    a = numeric_(any_na = TRUE),
    tests = 5,
    property = function(a) {
      res <- normalize(a)
      expect_true(all(res >= 0 & res <= 1))
    }
  )
})

── Failure: output is in interval [0, 1] ───────────────────────────────────────
Falsifiable after 1 tests, and 3 shrinks
<expectation_failure/expectation/error/condition>
all(res >= 0 & res <= 1) is not TRUE

`actual`:   <NA>
`expected`: TRUE
Backtrace:
     ▆
  1. └─quickcheck::for_all(...)
      [TRUNCATED...]
Counterexample:
$a
[1] -4037

Backtrace:
    ▆
 1. └─quickcheck::for_all(...)
 2.   └─hedgehog::forall(...)
```

]
Hah-ah! Problem: what happens if the input is a single value? Then `max(x) - min(x)` is 0, so the division gives `NaN`. In the error message, we can see:

#quote(block: true)[
Falsifiable after 1 tests, #strong[and 3 shrinks]
]

Shrinking is the action of reducing as much as possible the size of the input that makes the function fail. Having the smallest example possible is extremely useful when debugging.

Let's fix the function and try again:

#block[
```r
normalize <- function(x) {
  if (length(x) == 1) {
    return(0.5) # WARNING: this is for the sake of example, I don't 
                # guarantee this is the correct behavior
  }
  (x - min(x)) / (max(x) - min(x))
}

test_that("output is in interval [0, 1]", {
  for_all(
    a = numeric_(any_na = TRUE),
    tests = 5,
    property = function(a) {
      res <- normalize(a)
      expect_true(all(res >= 0 & res <= 1))
    }
  )
})

── Failure: output is in interval [0, 1] ───────────────────────────────────────
Falsifiable after 1 tests, and 8 shrinks
<expectation_failure/expectation/error/condition>
all(res >= 0 & res <= 1) is not TRUE

`actual`:   <NA>
`expected`: TRUE
Backtrace:
     ▆
  1. └─quickcheck::for_all(...)
     [TRUNCATED...]
Counterexample:
$a
[1] -2413 -2413

Backtrace:
    ▆
 1. └─quickcheck::for_all(...)
 2.   └─hedgehog::forall(...)
```

]
Dang it, now it fails when I pass a two identical values! This is for the same reason as above, `max(x) - min(x)` will return 0, but I won't spend more time on this example, you get the idea.

Besides this basic example, where could this be useful?

== Ensuring that a package doesn't crash R
<ensuring-that-a-package-doesnt-crash-r>
When working with compiled code (C++, Rust, etc.), it can happen that a bug makes the R session crash (== segfault == "bomb icon" in RStudio). This can be extremely annoying as we lose all data and computations that were stored in memory. When we work with compiled code, there's one property that our code should follow:

#quote(block: true)[
Calling a function should never lead to a segfault.
]

This happened to me a few months ago. I investigated some code that used `igraph::cluster_fast_greedy()`. I know almost nothing about `igraph`, I was just playing around with arguments, and suddenly… crash. I reported this situation (#link("https://github.com/igraph/igraph/issues/2459")[igraph\#2459]), which was promptly fixed (thank you `igraph` devs!), but one sentence in the explanation caught my eye: "it is a rare use case to only want modularity but not membership, and avoiding membership calculation doesn't have any advantages."

I have no particular problem with this sentence or the rationale behind, it makes sense to prioritize fixes that affect a larger audience. But it got me thinking: could we try all combinations of inputs to see if it makes the session crash? We could use #link("https://cran.r-project.org/web/packages/patrick/")[parametric testing] for this, but then again we need to hardcode at least some possible values for parameters. We could say that we start by testing only `TRUE`/`FALSE` values for all combinations of params, but what if the user passes a string?

I think this is a situation where property-based testing would be helpful: we know that no matter the input type, its length, and the value of other inputs, #emph[the session shouldn't crash]. Implementing it with `quickcheck` looks fairly simple:

#block[
```r
library(igraph, warn.conflicts = FALSE)

test_that("cluster_fast_greedy doesn't crash", {
  # setup a graph, from the examples of ?cluster_fast_greedy
  g <- make_full_graph(5) %du% make_full_graph(5) %du% make_full_graph(5)
  g <- add_edges(g, c(1, 6, 1, 11, 6, 11))

  for_all(
    merges = any_atomic(any_na = TRUE), 
    modularity = any_atomic(any_na = TRUE), 
    membership = any_atomic(any_na = TRUE), 
    weights = any_atomic(any_na = TRUE),
    property = function(merges, modularity, membership, weights) {
      suppressWarnings(
        try(
          cluster_fast_greedy(g, merges = merges, modularity = modularity, membership = membership, weights = weights),
          silent = TRUE
        )
      )
      expect_true(TRUE)
    }
  )
})
```

#block[
```
Test passed with 1 success 😀.
```

]
]
I didn't really know what expectation to put, I don't care if the function errors or not, I just want it not to segfault. So I put `try(silent = TRUE)` and added a fake expectation.

== Ensuring that a package and its variants give the same results
<ensuring-that-a-package-and-its-variants-give-the-same-results>
I have spent some time working on #link("https://www.tidypolars.etiennebacher.com/")[`tidypolars`], a package that provides the same interface as the `tidyverse` but uses `polars` under the hood. This means that there should be the lowest amount of "surprises" for the user: the behavior of functions that are available in `tidypolars` should match the behavior of those in `tidyverse`. Once again this can be tedious to check. One example is the function `stringr::str_sub()`. For instance, we can start with basic examples, such as:

#block[
```r
stringr::str_sub(string = "foo", start = 1, end = 2)
```

#block[
```
[1] "fo"
```

]
]
Easy enough to test. But what happens if `string` is missing? Or if `start > end`? Or if `end` is negative? Or if `start` is negative #emph[and] `end` is `NULL` #emph[and] the length of `start` is greater than the length of `string`? Manually adding tests for all of those is painful and increases the risk of forgetting a corner case.

It is better here to use property-based testing: we don't need to check the value of the output of functions implemented in `tidypolars`, #emph[we only need to check that they match the output of functions in `tidyverse`].

Here, one additional difficulty is that sometimes throwing an error is the correct behavior. Therefore, we need to create a custom expectation that checks that the output of `tidypolars` and `tidyverse` is identical, #emph[or] that both functions error (see the `testthat` vignette on #link("https://testthat.r-lib.org/articles/custom-expectation.html")[creating custom expectations]):

#block[
```r
expect_equal_or_both_error <- function(object, other) {
  polars_error <- FALSE
  polars_res <- tryCatch(
    object,
    error = function(e) polars_error <<- TRUE
  )

  other_error <- FALSE
  other_res <- suppressWarnings(
    tryCatch(
      other,
      error = function(e) other_error <<- TRUE
    )
  )

  if (isTRUE(polars_error)) {
    testthat::expect(isTRUE(other_error), "tidypolars errored but tidyverse didn't.")
  } else {
    testthat::expect_equal(polars_res, other_res)
  }

  invisible(NULL)
}
```

]
== Conclusion
<conclusion>
Property-based testing will not replace all kinds of tests, and is not necessarily appropriate in all contexts. Still, it can help uncover bugs, segfaults, and it adds more confidence in our code by randomly checking that it works even with implausible inputs.
