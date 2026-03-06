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
  title: "Refactoring code with flir",
  description: "How to efficiently rewrite many code patterns.",
  date: datetime(year: 2025, month: 05, day: 23),
  lang: "en",
)

= Refactoring code with flir
<refactoring-code-with-flir>
Slightly less than a year ago, I created #link("https://flir.etiennebacher.com/")[`flir`] (named `flint` at the time). The objective was to have a tool to detect and automatically correct a set of "bad practices" in R code. Those "bad practices" do not necessarily mean the code is wrong, simply that it is possible to improve its readability, robustness, and performance. If you are already familiar with #link("https://lintr.r-lib.org/")[`lintr`], you could think of `flir` as an extension that is faster and applies automatic fixes (at the expense of not covering the entire set of `lintr`'s rules).

== Detecting and fixing bad practices
<detecting-and-fixing-bad-practices>
`flir` provides 3 types of functions: linter functions, fixer functions, and helper functions:

- linter functions give the same capability as `lintr`: they detect bad practices in the code and report them with messages indicating what's wrong.
- fixer functions go one step further and automatically fix those bad practices in code. Note that not all rules can be automatically fixed.
- helper functions make it easier to use `flir` on a regular basis. They can create a dedicated folder where you can specify which rules you want to use and define your own, and they can create a Github Actions workflow to check the existence of bad practices on each commit.

You might be worried about this "automatic fixing" feature. After all, what if the fix is wrong? What if I want to go back to the previous situation? In this case, you should read this #link("https://flir.etiennebacher.com/articles/automatic_fixes")[vignette on the website] that details a couple of actions you can take to be more confident about this.

I won't repeat the package documentation and examples here. Rather, I'd like to explain how `flir` allows one to go further fixing "bad practices" and can be helpful when refactoring projects.

== `flir` can rewrite (almost) anything
<flir-can-rewrite-almost-anything>
Originally, `flir` was created to be an extension of `lintr`, but it can do more than that. `flir` works by detecting specific code patterns and rewriting them using the Rust crate #link("https://ast-grep.github.io/")[`ast-grep`]. This isn't limited to linter rules, it can be applied to any R code.

Let's take an example.

=== Rewriting superseded functions
<rewriting-superseded-functions>
#link("https://dplyr.tidyverse.org/index.html")[`dplyr`] contains several functions marked as "deprecated" or "superseded". Deprecated means that those functions will be removed in a later version of the package because they have some weaknesses that cannot be easily fixed or because there are alternative functions that are always better to use. Those functions are not supported anymore, meaning that bugs won't be fixed, so you should update your code if you use them. Superseded means that the function still works and is still supported in terms of fixing bugs, but there are better alternatives that are more efficient or readable for instance.

Let's say we have several occurrences of #link("https://dplyr.tidyverse.org/reference/sample_n.html")[`dplyr::sample_n()`] in our project. This function is superseded and we should use `slice_sample()` instead. First, after installing `flir`, we can create a `flir` folder with `flir::setup_flir()`. Then we add a new rule with `flir::add_new_rule("superseded-sample-n")`.

This creates the file below (`flir/rules/custom/superseded-sample-n.yml`):

```yaml
id: superseded-sample-n
language: r
severity: warning
rule:
  pattern: ...
fix: ...
message: ...
```

=== Creating the rule
<creating-the-rule>
Now we must define the patterns we want to detect in the code. For now, let's say we want to catch usages of `sample_n(my_data, 10)` and `sample_n(my_data, size = 10)` and replace them with `slice_sample(my_data, n = 10)`#footnote[`my_data` and `10` are just placeholders here, they could be anything.]. We want to detect two patterns and replace them with the same code, so we can use `any` in this situation:

```yaml
id: superseded-sample-n
language: r
severity: warning
rule:
  any:
    - pattern: sample_n($DATA, size = $N)
    - pattern: sample_n($DATA, $N)
fix: ...
message: ...
```

Note that we have used #emph[metavariables] here: `$DATA` and `$N`. Those will capture any code that fits in the `pattern`. We can then reuse those metavariables when we define the `fix` and `message`, but we'll need to use a double tilde instead of `$` to use them:

```yaml
id: superseded-sample-n
language: r
severity: warning
rule:
  any:
    - pattern: sample_n($DATA, size = $N)
    - pattern: sample_n($DATA, $N)
fix: slice_sample(~~DATA~~, n = ~~N~~)
message: Use `slice_sample()` instead of `sample_n()`.
```

We now have our rule. The only thing left to do is to list in the `flir/config.yml` file so that it is taken into account by `flir::lint_*()` and `flir::fix_*()` functions:

```yaml
keep:
  - any_duplicated
  [...]
  - which_grepl
  - superseded-sample-n
```

Alternatively, we can leave it out of the config file and specify it by hand, such as `flir::lint("my_file.R", linters = "superseded-sample-n")`.

=== Applying the rule
<applying-the-rule>
Now the only thing left to do is to run `flir` on the files we want.

For this example, I have created two files in a project:

- `foo1.R`:

#block[
```r
df <- tibble(x = 1:5, w = c(0.1, 0.1, 0.1, 2, 2))

sample_n(df, 3)
sample_n(df, 10, replace = TRUE)
sample_n(df, 3, weight = w)

n_rows <- 3

foo(sample_n(df, n_rows))
```

]
- `script/foo2.R`:

#block[
```r
if (nrow(sample_n(df, size = 3)) > 0) {
  print("hi")
}
```

]
First, let's see how many times we find those patterns in our code. We can run `flir::lint()` and it will open a "Markers" window in RStudio (if you don't use RStudio, it will print the messages in the R console):

#box(image("lints.png", width: 75.0%))

We have three occurrences that can be fixed. I can now run `flir::fix()` (note that I don't use Git for this demo project, so I will have to manually confirm I want to run this).

`foo1.R` now looks like this (I manually added the comments):

#block[
```r
df <- tibble(x = 1:5, w = c(0.1, 0.1, 0.1, 2, 2))

slice_sample(df, n = 3)          # fixed
sample_n(df, 10, replace = TRUE) # not fixed
sample_n(df, 3, weight = w)      # not fixed

n_rows <- 3

foo(slice_sample(df, n = n_rows)) # fixed
```

]
Several occurrences of `sample_n()` weren't modified. This is because they don't match any of the `pattern`s we defined in the rule: they include additional arguments such as `weight` and `replace`. We would need to include those additional patterns in the rule to fix them. Since they would need different replacements to account for the additional arguments, we can create an extra rule in the same file using `---` to separate them (and don't forget to change the `id`!):

```yaml
id: superseded-sample-n
language: r
severity: warning
rule:
  any:
    - pattern: sample_n($DATA, size = $N)
    - pattern: sample_n($DATA, $N)
fix: slice_sample(~~DATA~~, n = ~~N~~)
message: Use `slice_sample()` instead of `sample_n()`.

---

id: superseded-sample-n-2
language: r
severity: warning
rule: ...
fix: ...
message: ...
```

Similarly, `script/foo2.R` is now:

```r
if (nrow(slice_sample(df, n = 3)) > 0) { # fixed
  print("hi")
}
```

=== Going further
<going-further>
In this example, I have shown very simple patterns to detect, but it is possible to use much more advanced rules, using nested patterns and regular expressions for instance.

Take a look at those rules in `flir` to see what it can do: #link("https://github.com/etiennebacher/flir/blob/main/inst/rules/builtin/redundant_ifelse.yml")[`redundant_ifelse`], #link("https://github.com/etiennebacher/flir/blob/main/inst/rules/builtin/stopifnot_all.yml")[`stopifnot_all`], #link("https://github.com/etiennebacher/flir/blob/main/inst/rules/builtin/literal_coercion.yml")[`literal_coercion`].

== Conclusion
<conclusion>
`flir` is useful to detect bad practices in R code, but its usage doesn't stop here. It can be used to rewrite any R code you want using flexible patterns, which can be very valuable in projects involving many R files.

In the future, I would like to add a feature enabling package developers to provide a set of rules, for instance to replace deprecated and superseded functions in their package, that users would be able to use directly.

If you find bugs, would like more features, or simply have further questions, head to the #link("https://github.com/etiennebacher/flir/issues?q=sort%3Aupdated-desc+is%3Aissue+is%3Aopen")[Issues page]!
