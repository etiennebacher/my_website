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
  title: "Jarl 0.4.0",
  description: "Find unreachable code, ignore diagnostics, show summary statistics of diagnostics, and more.",
  date: datetime(year: 2026, month: 02, day: 03),
  lang: "en",
)

= Jarl 0.4.0
<jarl-0.4.0>
I'm very happy to announce the release of #link("https://jarl.etiennebacher.com/")[Jarl] 0.4.0. Jarl is a very fast R linter, written in Rust. It finds inefficient, hard-to-read, and suspicious patterns of R code across dozens of files and thousands of lines of code in milliseconds. Jarl is available as a command-line tool and as an extension for Positron, VS Code, Zed, and more.

After a few rapid iterations following the #link("https://www.etiennebacher.com/posts/2025-11-20-introducing-jarl/")[initial 0.1.0 announcement], I took a bit more time to add more features and fix more bugs.

== Unreachable code
<unreachable-code>
Jarl is now able to find unreachable code in R files. Code might not be reachable for a few reasons:

- it comes after a function that stops the execution (`stop()`, `rlang::abort()`, etc.);
- it comes after a keyword that breaks a loop (`break`) or goes to the next iteration (`next`);
- it comes after a `return()` statement in a function;
- it is part of a branch that can never be executed (for instance after `if (FALSE)`).

Usually, unreachable code means that there is a logic error somewhere before, or that the code is now useless and should be removed.

For example, take this simple function:

```r
f <- function(x) {
  if (x > 5) {
    return("greater than five")
  } else if (x < 5) {
    return("lower than five")
  } else {
    stop("x must be greater or lower than five")
  }
  print("end of function")
}
```

The `print()` statement will never be executed because all branches of the `if` statement return early or error. And indeed, Jarl indicates:

```
warning: unreachable_code
 --> _posts/2026-02-03-jarl-0.4.0/test.R:9:3
  |
9 |   print("end of function")
  |   ------------------------ This code is unreachable because the preceding if/else
  terminates in all branches.
  |

Found 1 error.
```

Note that if we were to remove the `else` statement:

```r
f <- function(x) {
  if (x > 5) {
    return("greater than five")
  } else if (x < 5) {
    return("lower than five")
  }
  print("end of function")
}
```

then Jarl wouldn't report anything because the `print()` statement would run if `x == 5`.

This unreachable code detection also works outside of functions, which can be helpful for example if you have introduced a `stop()` for debugging somewhere in a script and forgot to remove it when running the entire script again later.

== Suppression comments
<suppression-comments>
Suppression comments are special comments that are used to ignore diagnostics reported by the linter. If you have already used `lintr`, you might be familiar with the `# nolint` comments. In the first iterations of Jarl, these `# nolint` comments were partially supported. However, the way they were implemented in Jarl was brittle and prone to errors, especially when automatically inserting them.

As of Jarl 0.4.0, suppression comments have been entirely rewritten and now follow a different syntax. This also allows you to safely use Jarl and `lintr` in the same project, knowing that there won't be conflicts between their comments. The new suppression comments are extensively covered in the section #link("https://jarl.etiennebacher.com/using-jarl#ignoring-diagnostics")["Ignoring diagnostics"] on the documentation website, but I present a summary below.

There are three types of suppression comments:

- #strong[standard comments] apply to the next block of code, or #emph[node]. A node correspond to an R expression as well as all expressions that belong to it (aka #emph[children nodes]). Importantly, the detection of which node is affected by a comment doesn't depend on the layout of the code (line breaks, whitespaces, etc.).

  ```r
  # The comment below only applies to `any(is.na(x1))`.
  # jarl-ignore any_is_na: <reason>
  any(is.na(x1))
  any(is.na(x2))

  # The comment below applies to the entire function definition, including the
  # two `any(is.na(...))` calls.
  # jarl-ignore any_is_na: <reason>
  f <- function(x1, x2) {
    any(is.na(x1))
    any(is.na(x2))
  }
  ```

  If you have ever used #link("https://posit-dev.github.io/air/formatter.html#disabling-formatting")[Air's suppression comments], then you should already be familiar about the locations of Jarl's comments since they follow the same rules.

  #html.elem("details")[
    #html.elem("summary")[
      Click to see more details on how node detection works.
    ]

  Jarl is entirely based on parsing the abstract syntax tree (AST) of the code.
  In the example above, the `f <- function...` call is represented as follows:

  ```r
  lobstr::ast(
    f <- function() {
      any(is.na(x1))
      any(is.na(x2))
    }
  )
  #> █─`<-`
  #> ├─f
  #> └─█─`function`
  #>   ├─NULL
  #>   ├─█─`{`
  #>   │ ├─█─any
  #>   │ │ └─█─is.na
  #>   │ │   └─x1
  #>   │ └─█─any
  #>   │   └─█─is.na
  #>   │     └─x2
  #>   └─NULL
  ```

  The top node is the assignment `<-`. Then come the left-hand side and right-hand side of the assignment. The LHS simply is the identifier `f`, but the RHS has itself multiple children, including the function body (`{`). Finally, inside the function body, we see the two calls to `any(is.na(...))`.

  When we put a comment above `f <- function...`, we attach the node to `<-` #emph[and to all its children], which explains why code inside the function also uses this comment to ignore diagnostics.

  ]

- #strong[range comments] applies to all the code between `start` and `end`:

  ```r
  # The comment below applies until `jarl-ignore-end` is found (and at the
  # same nesting level).
  # jarl-ignore-start any_is_na: <reason>
  any(is.na(x1))
  any(is.na(x2))

  f <- function(x1, x2) {
    any(is.na(x1))
    any(is.na(x2))
  }
  # jarl-ignore-end any_is_na
  ```

- #strong[file comments] applies to all code in the file:

  ```r
  # The comment below applies to the entire file.
  # jarl-ignore-file any_is_na: <reason>
  any(is.na(x1))
  any(is.na(x2))

  f <- function(x1, x2) {
    any(is.na(x1))
    any(is.na(x2))
  }
  ```

There are two important things to notice in the syntax of the suppression comments.

First, #strong[they must state the precise rule to ignore]. This means that if you wish to ignore multiple rules for the same code block, you must have one comment per rule to ignore (the reason for this is the next point). This also means that comments such as `# jarl-ignore` (aka #emph[blanket suppressions]) are ignored and even reported by Jarl.

Second, #strong[they must state a reason why these diagnostics are ignored]. This is the `<reason>` placeholder in the examples above, and it can be any text after the colon.

If you are used to `lintr`'s suppression comment system, this may feel quite constraining but there is a good justification for having these two rules. You may have a valid reason to ignore a diagnostic, for instance because Jarl returns a false positive. If this is the case, it is important that only the rule that gives the false positive is ignored and not rules that have nothing to do with the false positive. This is why you have to specify the rule name in the comment. It is also important that you explain why this case must be ignored, so that future people who work on the code (and maybe future you) are aware of that.

Note that if you don't want any diagnostics of a specific rule, you can always ignore the rule in `jarl.toml` or with command-line arguments.

To help you write valid suppression comments, Jarl will report comments that are invalid for any reason (misplaced comment, misnamed rule, unused comment, etc.).

== Other goodies
<other-goodies>
This release brings more features!

#strong[A new command-line argument `--statistics`] to show a count of diagnostics instead of being flooded in details in the console:

```
> jarl check . --statistics

   88 [*] numeric_leading_zero
    3 [*] redundant_equals
    1 [ ] vector_logic
    1 [*] string_boundary

Rules with `[*]` have an automatic fix.
```

#link("https://jarl.etiennebacher.com/config#config-file-detection")[#strong[A hierarchical search for `jarl.toml`]] to look for configuration files in parent folders if the working directory doesn't have one.

This is particularly useful to store a default `jarl.toml` in a config folder so that any projects that doesn't have its own `jarl.toml` will fallback to this one. The location of this config folder varies by OS:

- on Linux/macOS, you can store the default config at `~/.config/jarl/jarl.toml`\;
- on Windows, you can store the default config at `~/AppData/Roaming/jarl/jarl.toml`.

For instance, suppose I have `test.R` in my working directory, and this working directory doesn't have a `jarl.toml`. Before 0.4.0, Jarl wouldn't look for other configuration files. As of 0.4.0, Jarl looks in parent folders and in the config folder as a fallback.

```
/home/etienne
    |
    ├── Desktop
    |     ├── test    # ---> this is my working directory
    |     |   ├── data
    |     |   ├── scripts
    |     |   ├── ...
    |     |   └── test.R
    |     |
    |     └── jarl.toml    # ---> config file belongs to "Desktop" (parent
    |                      #      directory of my working directory) so it
    |                      #      will be used first
    |
    └── .config
        └── jarl
            └── jarl.toml  # ---> this is the fallback config file that would
                           #      be used if there weren't any jarl.toml found
                           #      in parent directories of my working
                           #      directory.
```

#strong[Less rules activated by default] as some were considered too noisy relative to their benefit (such as `assignment` and `fixed_regex`). Those rules still exist but need to be selected in `jarl.toml` or with command line arguments.

And a few bug fixes, because what would programming be without bugs.

I hope you enjoy this release! If you find any issues or want to contribute, please check out the #link("https://github.com/etiennebacher/jarl")[Github repository]. And thanks Maëlle for the suggestions!
