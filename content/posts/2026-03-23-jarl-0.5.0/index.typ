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
  title: "Jarl 0.5.0",
  date: datetime(year: 2026, month: 03, day: 20),
  lang: "en",
)

= Jarl 0.5.0
<jarl-0.5.0>
I'm glad to announce the release of #link("https://jarl.etiennebacher.com/")[Jarl] 0.5.0. Jarl is a very fast R linter, written in Rust. It finds inefficient, hard-to-read, and suspicious patterns of R code across dozens of files and thousands of lines of code in milliseconds. Jarl is available as a command-line tool and as an extension for Positron, VS Code, Zed, and more.

This release comes with many new features and some bug fixes and deprecations.

== Check R Markdown and Quarto documents
<check-r-markdown-and-quarto-documents>
Jarl now checks the content of R code chunks in R Markdown and Quarto documents by default:

````r
---
title: "hello"
---

```{r}
x <- 1
any(is.na(x))
```
````

```
$ jarl check test.Rmd
warning: any_is_na
 --> test.Rmd:7:1
  |
7 | any(is.na(x))
  | ------------- `any(is.na(...))` is inefficient.
  |
  = help: Use `anyNA(...)` instead.
```

This new functionality also comes with a new suppression comment: `jarl-ignore-chunk`. Other suppression comments still work, but `jarl-ignore-chunk` will be parsed as a chunk option and therefore will not appear in the rendered output:

````default
---
title: "hello"
---

```{r}
#| jarl-ignore-chunk:
#|   - any_is_na: this is just a demo
#|   - any_duplicated: another reason to suppress this violation
x <- 1
any(is.na(x))
any(duplicated(x))
```
````

#box(image("rendered_rmd.png", alt: "A screenshot of the HTML output produced by the R Mardown example above. It shows that the two calls to `any()` return `FALSE`, but importantly the `jarl-ignore-chunk` comments do not appear in the output."))

See more information in the #link("https://jarl.etiennebacher.com/howto/suppression-comments#where-should-i-place-suppression-comments")["Suppression comments" docs].

== Rule-specific options in `jarl.toml`
<rule-specific-options-in-jarl.toml>
It is now possible to pass options for specific rules in the config file. This can be useful in two situations:

- respect the user preferences for rules that don't have a clear argument in favor of one side or another (e.g.~`<-` vs `=`, or `"` vs `'`);
- give more information to Jarl, for instance for the `unreachable_code` rule (see example below).

Those rules can be customized with a `[lint.<rule-name>]` section in `jarl.toml`. For example, `unreachable_code` (introduced in the previous version of Jarl) detects code that would never run because it comes after a `stop()` (among other situations). This rule already comes with a bundled list of "stopping functions", such as `rlang::abort()`. However, maybe you have defined your own custom stopping function that Jarl doesn't know, e.g.~`stopf()` in `data.table`:

#block[
```r
data.table:::stopf
```

#block[
```
function (fmt, ..., class = NULL, domain = "R-data.table") 
{
    raise_condition(stop, gettextf(fmt, ..., domain = domain), 
        c(class, "simpleError", "error", "condition"))
}
<bytecode: 0x60fc9289b030>
<environment: namespace:data.table>
```

]
]
As of Jarl 0.5.0, someone working on the `data.table` project could now add the following in `jarl.toml`:

```toml
[lint.unreachable_code]
extend-stopping-functions = ["stopf"]
```

This would add `stopf()` on top of all the other stopping functions. Use `stopping-functions` instead to define the entire list by yourself.

See all rule-specific options in the #link("https://jarl.etiennebacher.com/reference/config-file#rule-specific-arguments")["Configuration file" docs].

== Allow multiple `jarl.toml`
<allow-multiple-jarl.toml>
Until now, Jarl would allow a single `jarl.toml` in the project to check. This means that it would error if you were running Jarl on the folder `my_projects` containing several R packages or other projects, each with their own `jarl.toml`.

Jarl now allows this, meaning that each analyzed file will use the closest `jarl.toml` that exists in the same folder or in a parent folder.

For example, let's say I have the following folders that belong to a more general "projects" folder:

```
projects
  ├── mypkg1
  │   ├── DESCRIPTION
  │   ├── jarl.toml
  │   ├── NAMESPACE
  │   └── R
  │       └── foo1.R
  └── mypkg2
      ├── DESCRIPTION
      ├── jarl.toml
      ├── NAMESPACE
      └── R
          └── foo2.R
```

Both `mypkg1/R/foo1.R` and `mypkg2/R/foo2.R` contain the following code:

```r
any(is.na(x))
any(duplicated(x))
```

`mypkg1/jarl.toml` selects #emph[only] the `any_is_na` rule, and `mypkg2/jarl.toml` selects #emph[only] the `any_duplicated` rule.

This would error#footnote[Even worse than that, it would #emph[panic]! This is what happens in Rust when you don't properly handle errors.] with Jarl 0.4.0:

```
$ jarl check mypkg1 mypkg2

thread 'main' (1044252) panicked at crates/jarl-core/src/config.rs:96:9:
not yet implemented: Don't know how to handle multiple TOML
note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace
```

but it works just fine with Jarl 0.5.0:

```
$ jarl check mypkg1 mypkg2

warning: any_is_na
 --> mypkg1/R/foo1.R:1:1
  |
1 | any(is.na(x))
  | ^^^^^^^^^^^^^ `any(is.na(...))` is inefficient.
  |
help: Use `anyNA(...)` instead.

warning: any_duplicated
 --> mypkg2/R/foo2.R:2:1
  |
2 | any(duplicated(x))
  | ^^^^^^^^^^^^^^^^^^ `any(duplicated(...))` is inefficient.
  |
help: Use `anyDuplicated(...) > 0` instead.


── Summary ──────────────────────────────────────
Found 2 errors.
2 fixable with the `--fix` option.
```

== Package-specific rules
<package-specific-rules>
So far, Jarl's rules were mostly copied from #link("https://lintr.r-lib.org/dev/reference/index.html")[`lintr`'s list]. Most of those rules focus on base R or other concerns (e.g.~which assignment operator to prefer in the project).

As of 0.5.0, Jarl opens the door to package-specific rules. Those rules are written for particular packages and come with a performance tradeoff. The problem here comes from two components:

+ a given function, say `filter()`, can be exported by several packages:

  ```r
  pkgcheck::fn_names_on_cran("filter")
  #>          package version fn_name
  #> 1         crunch  1.31.1  filter
  #> 2        gsignal   0.3-7  filter
  #> 3         narray   0.5.2  filter
  #> 4  pandocfilters   0.1-6  filter
  #> 5        poorman   0.2.7  filter
  #> 6           rTLS 0.2.6.1  filter
  #> 7         signal   1.8-1  filter
  #> 8         tidyft  0.9.20  filter
  #> 9        tidylog   1.1.0  filter
  #> 10     tidytable  0.11.2  filter
  #> 11         dplyr   1.2.0  filter
  #> 12           rbi   1.0.1  filter
  #> 13     pammtools   0.7.4  filter
  #> 14 cohortBuilder   0.4.0  filter
  #> 15         stats   4.5.2  filter
  ```

+ Jarl does static analysis, meaning that it doesn't run R code.

To enable package-specific rules, the latter has to be slightly relaxed. Jarl will run R to get the version and list of exports of all packages used in the session, and this introduces a slight slowdown when any of those package-specific rules are enabled. However, Jarl should still run in less than 1 second on your entire project. Note that if you enable these rules and use Jarl in CI, you will need to adapt your workflow to install R and the dependencies of your project as well.

So far, Jarl provides only two package-specific rules, both for `dplyr`:

- `dplyr_group_by_ungroup` looks for chains of pipes that could be replaced by the argument `.by` or `by`, e.g.:

  ```r
  library(dplyr)
  mtcars |> 
    group_by(am, cyl) |> 
    summarize(mean_mpg = mean(mpg)) |> 
    ungroup()
  ```

  ```
  warning: dplyr_group_by_ungroup
  --> test.R:4:3
    |
  4 | /   group_by(am, cyl) |> 
  5 | |   summarize(mean_mpg = mean(mpg)) |> 
  6 | |   ungroup()
    | |___________- `group_by()` followed by `summarize()` and `ungroup()` can be simplified.
    |
    = help: Use `summarize(..., .by = c(am, cyl))` instead.

  ── Summary ──────────────────────────────────────
  Found 1 error.
  1 fixable with the `--fix` option.
  ```

  Note that this would only be reported if your `dplyr` version is `>= 1.1.0`.

- `dplyr_filter_out` looks for `x |> filter(...)` with conditions such as `my_condition(var) | is.na(var)`. As of `dplyr` 1.2.0, these `filter()` calls can be replaced with easier-to-read `filter_out()` calls:

  ```r
  library(dplyr)
  mtcars |> 
    group_by(am, cyl) |> 
    summarize(mean_mpg = mean(mpg)) |> 
    ungroup()
  ```

  ```
  warning: dplyr_filter_out
  --> test.R:3:3
    |
  3 |   filter(hair_color != "blond" | is.na(hair_color))
    |   ------------------------------------------------- This `filter()` contains complex condition(s).
    |
    = help: It can be simplified by using `filter_out()`, which keeps `NA` rows.


  ── Summary ──────────────────────────────────────
  Found 1 error.
  1 fixable with the `--fix` option.
  ```

See the #link("https://jarl.etiennebacher.com/howto/package-specific")[package-specific rules] section in the docs for more details.

== Stuff for package developers
<stuff-for-package-developers>
This release brings a couple of enhancements for R package developers.

First, Jarl comes with two new rules that run in R packages only: `unused_function` and `duplicated_function_definition`. The former finds functions that are not used anywhere (in other functions or in tests) and are not exported by the package, meaning that they should either be fixed or removed. The latter finds functions that are defined several times in the package, leading to one definition being used and the other(s) being ignored by mistake.

Second, Jarl now checks `roxygen2` comments by default and reports violations in `@examples` and `@examplesIf`. Diagnostics reported in those comments can be ignored with standard suppression comments:

```r
#' @examples
# jarl-ignore any_is_na: <reason>
#' any(is.na(x))
```

Note that `jarl-ignore` starts with `#` and not `#'`.

This feature can be controlled with two new arguments in `jarl.toml`: `check-roxygen` (true by default) and `fix-roxygen` (false by default because not all formatters can format roxygen comments yet).

== Conclusion
<conclusion>
Jarl 0.5.0 brings a lot of new stuff! If you find any issue, have feature ideas, or want to contribute, head to the #link("https://github.com/etiennebacher/jarl")[Github repository].

Thanks to everyone who contributed one way or another to this release: #link("https://github.com/bjyberg")[\@bjyberg], #link("https://github.com/larry77")[\@larry77], #link("https://github.com/maelle")[\@maelle], #link("https://github.com/novica")[\@novica], and #link("https://github.com/vincentarelbundock")[\@vincentarelbundock]
