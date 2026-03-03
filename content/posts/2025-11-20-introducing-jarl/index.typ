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
  title: "Jarl: just another R linter",
  description: "Remove bad patterns in your R code in the blink of an eye.",
  date: datetime(year: 2025, month: 11, day: 20),
  lang: "en",
)

= Jarl: just another R linter
<jarl-just-another-r-linter>
I'm very excited to introduce #link("https://jarl.etiennebacher.com/")[Jarl]#footnote[Jarl stands for "Just Another R Linter".], a new R linter. A linter is a tool that statically parses code (meaning that it doesn't run the code in question) and searches for patterns that are inefficient, hard to read, or likely bugs.

Jarl can parse dozens of files and thousands of lines of code in milliseconds. Here is an example of Jarl running on #link("https://github.com/wch/r-source/")[r-source] (approximately 1000 files and 200k lines of R code) in about 700 milliseconds:

On top of that, Jarl can apply automatic fixes#footnote[This is not always possible, it depends on the rule.]. Suppose that we have the following file `foo.R`:

```r
x <- any(is.na(mtcars))

f <- function(x) {
  apply(x, 1, mean)
}
```

There are two rule violations in this file:

+ `any(is.na(mtcars))` should be replaced by `anyNA(mtcars)`#footnote[`anyNA(x)` is more efficient than `any(is.na(x))`.]\;
+ `apply(x, 1, mean)` should be replaced by `rowMeans(x)`#footnote[`rowMeans(x)` is more efficient than `apply(x, 1, mean)`.].

Instead of fixing those cases by hand, we can run the following command in the terminal (not in the R console):

```sh
jarl check foo.R --fix
```

After running this, `foo.R` now contains the following code:

```r
x <- anyNA(mtcars)

f <- function(x) {
  rowMeans(x)
}
```

\(Note that `f` is now useless since it is equivalent to `rowMeans()`.)

Jarl stands on the shoulders of giants, in particular:

- #link("https://lintr.r-lib.org/")[lintr]: this R package provides dozens of rules from various sources to lint R code, and Jarl wouldn't exist without this package. Jarl currently supports 25 `lintr` rules.
- #link("https://posit-dev.github.io/air/")[Air]: this is a fast R formatter written in Rust, developed by Lionel Henry and Davis Vaughan, and released earlier this year. It is also a command-line tool that runs in the terminal. It is the technical foundation on which Jarl is built since Air provides the infrastructure to parse and manipulate R code.

Jarl is a single binary, meaning that it doesn't need an R installation to work. This makes it a very attractive option for continuous integration for instance, since it takes less than 10 seconds to download the binary and run it on the repository.

== Using Jarl
<using-jarl>
There are two ways to use Jarl:

+ via the terminal, using `jarl check [OPTIONS]`\;
+ using the integration in your coding editor (at the time of writing, a Jarl extension is available in VS Code, Positron, and Zed).

The Jarl extension enables code highlighting and quick fixes. The former means that code that violates any of the rules in your setup (more on this below) will be underlined and will show the exact violation when hovered.

The latter adds a lightbulb button next to rule violations, allowing you to selectively apply fixes or ignore violations.

In the future, those extensions could have a "Fix on save" feature similar to the "Format on save" functionality provided by Air.

== Configuring Jarl
<configuring-jarl>
By default, Jarl will report violations for almost of its rules. It is possible to configure its behavior using a configuration file named `jarl.toml`. In particular, in this file, you can specify:

- the rules you want to apply,
- the files to include or exclude,
- the rules for which you want to apply automatic fixes,

and more.

== Conclusion
<conclusion>
Jarl is in its early days, there are more rules and options to add. Still, it can already be used in interactive use or in continuous integration (check out the #link("https://github.com/etiennebacher/setup-jarl")[`setup-jarl` workflow]!). Eventually, many `lintr` rules should be supported in Jarl, but the end goal is not to have perfect compatibility. `lintr` provides many rules related to code formatting (e.g.~#link("https://lintr.r-lib.org/dev/reference/spaces_inside_linter.html")[spaces\_inside\_linter]). Those will not be integrated in Jarl since they are already covered by Air. Additionally (for now), Jarl cannot perform semantic analysis#footnote[Semantic analysis refers to using the context surrounding an expression to explore rule violations.], meaning that some `lintr` rules are out of scope (e.g.~#link("https://lintr.r-lib.org/dev/reference/unreachable_code_linter.html")[unreachable\_code\_linter]).

This was a very light introduction, go to the #link("https://jarl.etiennebacher.com/")[Jarl website] for more information.

If you want to help developing Jarl, check out the #link("https://jarl.etiennebacher.com/contributing")["Contributing" page]. Jarl is written in Rust, which may be a barrier to contributing but is also a very powerful language which is a real pleasure to use. I will add a more detailed tutorial soon so that this can also be a nice introduction to this language. You can also contribute to the documentation!

= Acknowledgements
<acknowledgements>
As I said above, Jarl depends enormously on the work of #link("https://lintr.r-lib.org/authors.html")[`lintr`] and Air developers, so thank you!

Jarl is also very inspired by similar tools in other languages, in particular #link("https://docs.astral.sh/ruff/")[Ruff] in Python and #link("https://github.com/rust-lang/rust-clippy")[Cargo clippy] in Rust.

Finally, thanks to the #link("https://r-consortium.org/")[R Consortium] for funding part of the development of Jarl via the ISC Grant Program.

And thank you, Maëlle, for improving the draft!
