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
  title: "Use GitHub actions with R Markdown and Distill",
  description: "How can you automatically render README, Distill website...",
  date: datetime(year: 2021, month: 03, day: 19),
  lang: "en",
)

= Use GitHub actions with R Markdown and Distill
<use-github-actions-with-r-markdown-and-distill>
#emph[ The preview image comes from: https:\/\/github.com/marketplace/actions/cancel-workflow-action ]

Sometimes, it is useful to automatically render an R Markdown document or a website, made with #link("https://rstudio.github.io/distill/")[`distill`] for example. In this post, I will present you two cases in which I use GitHub Actions to automatically do that.

= Render a README
<render-a-readme>
One of my GitHub repos is a list of JavaScript libraries that have been adapted in R. You can find the repo #link("https://github.com/etiennebacher/r-js-adaptation")[here]. I wanted this list to be easy to update, so that it can be done on GitHub directly. The idea is that when I (or someone else) find a JavaScript library that has been adapted into an R package, I add it to a CSV file on GitHub. The problem is that this CSV file is then used into an R Markdown file, that creates a clean README with all the information.

Without GitHub Actions, in addition to modify the CSV file, I would have to clone the repo, open it in RStudio, render the README, and push it back on GitHub.

But this task is repetitive: apart from the details I add to the CSV file, it can be automated. This is where GitHub Actions comes into play. The idea is that you create a `.yml` file that contains the R code you want to run to render the README. This is what mine looks like:

```{yaml}
on:
  push:
    branches: master

name: Render README

jobs:
  render:
    name: Render README
    runs-on: macOS-latest
    steps:
      - uses: actions/checkout@v2
      - uses: r-lib/actions/setup-r@v1
      - uses: r-lib/actions/setup-pandoc@v1
      - name: Install rmarkdown
        run: Rscript -e 'install.packages("rmarkdown")'
      - name: Render README
        run: Rscript -e 'rmarkdown::render("README.Rmd", output_format = "md_document")'
      - name: Commit results
        run: |
          git commit README.md -m 'Re-build README.Rmd' || echo "No changes to commit"
          git push origin || echo "No changes to commit"
```

The first two parts are quite self-explanatory:

- the jobs run every time there's a push on the master branch;

- the name of this process is "Render README".

The third part needs a bit more details. There are some parts that I just copied and pasted from the #link("https://github.com/r-lib/actions")[R actions repository], but basically you can see that first it initiates R and pandoc (`setup-r@v1`, `setup-pandoc@v1`). Then, I run an R script to install the `rmarkdown` package and I use it to render the Rmd file to create `README.md`.

Last but not least, GitHub Actions rendered the README, but the changes are not on the repo yet. Hence, the last step is to commit the changes with a message and to push them on the master branch. Now, every time I change the CSV file on the master branch, the README will be automatically rendered (after a few minutes, since all the actions have to run first).

I said this was the `.yaml` file I use on my repo, but I lied a bit. Actually, for my list of JavaScript libraries to be up-to-date, I also need to scrape the #link("https://gallery.htmlwidgets.org/")[htmlwidgets gallery] once in a while. Hence, I use `cron` to run GitHub Actions every Monday at 00:00. See #link("https://docs.github.com/en/actions/reference/events-that-trigger-workflows#schedule")[the documentation] to know how to format your schedule. Finally, here's the `.yaml` file I use:

```{yaml}
on:
  push:
    branches: master
  schedule:
    - cron: '0 0 * * MON'

name: Render README

jobs:
  render:
    name: Render README
    runs-on: macOS-latest
    steps:
      - uses: actions/checkout@v2
      - uses: r-lib/actions/setup-r@v1
      - uses: r-lib/actions/setup-pandoc@v1
      - name: Install rmarkdown
        run: Rscript -e 'install.packages("rmarkdown")'
      - name: Render README
        run: Rscript -e 'rmarkdown::render("README.Rmd", output_format = "md_document")'
      - name: Commit results
        run: |
          git commit README.md -m 'Re-build README.Rmd' || echo "No changes to commit"
          git push origin || echo "No changes to commit"
```

= Render a Distill website
<render-a-distill-website>
To automatically render your `distill` website on every push on master branch, the logic is very similar. In my `.yml` file, there are two main differences.

The first one is that I need to install more packages to render my `distill` website. Some will be essential for everyone (e.g `distill`) but other packages won't be (e.g `postcards`).

The second one is more tricky, but could be useful for several people. Before using `distill`, I used `blogdown`. For some reasons (and mostly because `distill` is much easier in my opinion), I switched to `distill`. However, this switch changed a few URLs addresses, for my posts for instance. Therefore, I needed a #link("https://yihui.org/en/2017/11/301-redirect/")[`_redirects`] file to, well, redirect the old URLs to the new ones and prevent 404 errors. The `_redirects` file needs to be in the `_site` folder, because it is the folder that is used by Netlify to build the site. The problem here is that this folder is deleted and re-generated every time `rmarkdown::render_site()` is called, i.e every time the website is locally built. Therefore, the `_redirects` file couldn't just stay there. I had to add it manually after every build.

The solution to that is to automate this in GitHub Actions. After having rendered the website, I just copy `_redirects` from its location on the repo to the `_site` folder. Now, every time I change something on the master branch, the `distill` website is rebuilt, and then the `_redirects` file is added.

One drawback though: since these files are changed on GitHub only, the first thing you have to do when opening your site project in RStudio is to pull the changes (or, like me, you will struggle with merge conflicts).

To finish this post, here's the `.yml` file for my `distill` website:

```{yaml}
on:
  push:
    branches: master

name: Render & Deploy Site

jobs:
  build:
    runs-on: macOS-latest
    steps:
      - uses: actions/checkout@v2

      - uses: r-lib/actions/setup-r@master

      - uses: r-lib/actions/setup-pandoc@master

      - name: Install dependencies
        run: |
          install.packages("rmarkdown")
          install.packages("distill")
          install.packages("postcards")
          install.packages("devtools")
          install.packages("fs")
          devtools::install_github("etiennebacher/ebmisc")
        shell: Rscript {0}

      - name: Render Site
        run: Rscript -e 'rmarkdown::render_site(encoding = "UTF-8")'
      - name: Copy redirects
        run: Rscript -e 'fs::file_copy("_redirects", "_site/_redirects")'
      - name: Commit results
        run: |
          git add -A
          git commit -m 'Rebuild site' || echo "No changes to commit"
          git push origin || echo "No changes to commit"
```
