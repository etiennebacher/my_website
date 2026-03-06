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
  title: "How to create a gallery in Distill",
  description: "Use lightgallery.js to create a gallery for your plots or images.",
  date: datetime(year: 2021, month: 05, day: 20),
  lang: "en",
)

= How to create a gallery in Distill
<how-to-create-a-gallery-in-distill>
This post shows how to create a gallery on a Distill website. Keep in mind that Distill is (purposely) less flexible than other tools, such as `{blogdown}`, so the gallery might look quite different from what you expect.

== Create a gallery with lightgallery.js
<create-a-gallery-with-lightgallery.js>
#link("https://github.com/sachinchoolur/lightgallery")[Lightgallery.js] is a Javascript library that allows you to build a gallery very simply. You will need images in full size and thumbnails, i.e a smaller version of the images (we will see how to automatically make them later in this post).

First of all, let's construct the gallery with HTML, CSS, and Javascript. We will see how to adapt this in R then. We need to load the Javascript and CSS files for lightgallery.js in the head:

```html
<head>

<link type="text/css" rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/lightgallery/1.6.0/css/lightgallery.min.css" />
<script src="https://cdnjs.cloudflare.com/ajax/libs/lightgallery-js/1.4.1-beta.0/js/lightgallery.min.js"></script>

<!-- lightgallery plugins -->
<script src="https://cdnjs.cloudflare.com/ajax/libs/lg-fullscreen/1.2.1/lg-fullscreen.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/lg-thumbnail/1.2.1/lg-thumbnail.min.js"></script>

</head>
```

Then, we construct the layout of the gallery. Here, I make the minimum layout, just to make sure this works:

#block[
```html
<div id="lightgallery">
  <a href="img1.png">
    <img src="thumb-img1.png" />
  </a>
  <a href="img2.png">
    <img src="thumb-img2.png" />
  </a>
</div>
```

]
As you can see, the whole gallery is in a `<div>` element. To add an image to the gallery, we just have to add an `<a>` element as the two already there.

Then, we add the Javascript code to run lightgallery.js:

#block[
```html
<script type="text/javascript">
  lightGallery(document.getElementById('lightgallery'));
</script>
```

]
This should work, but I just add a CSS animation to zoom a bit when hovering a thumbnail:

#block[
```html
<style>
  #lightgallery > a > img:hover {
    transform: scale(1.2, 1.2);
    transition: 0.2s ease-in-out;
    cursor: pointer;
  }
</style>
```

]
That's it for the proof of concept. Now let's adapt it in R.

#html.elem("details")[
  #html.elem("summary")[
    Click to see the full HTML.
  ]

  ```html
  <!doctype html>
  <html>
    <head>
      <link type="text/css" rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/lightgallery-js/1.4.1-beta.0/css/lightgallery.css" />
      <script src="https://cdnjs.cloudflare.com/ajax/libs/lightgallery-js/1.4.1-beta.0/js/lightgallery.min.js"></script>

     <!-- lightgallery plugins -->
     <script src="https://cdnjs.cloudflare.com/ajax/libs/lg-fullscreen/1.2.1/lg-fullscreen.min.js"></script>
     <script src="https://cdnjs.cloudflare.com/ajax/libs/lg-thumbnail/1.2.1/lg-thumbnail.min.js"></script>
    </head>
    <body>
      <div id="lightgallery">
        <a href="img1.png" data-sub-html="<h4>Sunset Serenity</h4><p>A gorgeous Sunset tonight captured at Coniston Water....</p>">
            <img src="thumb-img1.png" />
        </a>
        <a href="img2.png">
            <img src="thumb-img2.png" />
        </a>
      </div>

      <script type="text/javascript">
        lightGallery(document.getElementById('lightgallery'));
      </script>

      <style>
        #lightgallery > a > img:hover {
          transform: scale(1.2, 1.2);
          transition: 0.2s ease-in-out;
          cursor: pointer;
        }
      </style>

    </body>
  </html>
  ```
]
== Make the gallery with R
<make-the-gallery-with-r>
=== Create thumbnails
<create-thumbnails>
First, store your (full-size) images in a folder, let's say `_gallery/img`. As we saw above, `lightgallery.js` also requires thumbnails in addition to full-size images. To automatically create these thumbnails, we can use the function `image_resize()` in the package `magick`. First, I create a function to resize a single image, and I will apply it to all the images I have:

#block[
```r
library(magick)
library(here)

resize_image <- function(image) {

  imFile <- image_read(here::here(paste0("_gallery/img/", image)))
  imFile_resized <- magick::image_resize(imFile, "6%")
  magick::image_write(imFile_resized, here::here(paste0("_gallery/img/thumb-", image)))

}

list_png <- list.files("_gallery/img")
lapply(list_png, resize_image)
```

]
=== Build the HTML structure
<build-the-html-structure>
We can now start building the HTML structure with the package `htmltools`. First, we can see that the HTML code for each image is very similar:

#block[
```html
<a href="img.png">
    <img src="thumb-img.png" />
</a>
```

]
This can be reproduced in R with:

#block[
```r
library(htmltools)

tags$a(
  href = "img.png",
  tags$img(src = "thumb-img.png")
)
```

]
We can now create a function to apply this structure to all the images we have:

#block[
```r
make_gallery_layout <- function() {

  # Get the names of all images
  images <- list.files("_gallery/img")

  # Get the names of all full-size images
  images_full_size <- grep("thumb", images, value = TRUE, invert = TRUE)

  # Get the names of all thumbnails
  images_thumb <- grep("thumb", images, value = TRUE)

  # Create a dataframe where each row is one image (useful for
  # the apply() function)
  images <- data.frame(images_thumb = images_thumb,
                       images_full_size = images_full_size)

  # Create the HTML structure for each image
  tagList(apply(images, 1, function(x) {
      tags$a(
        href = paste0("_gallery/img/", x[["images_full_size"]]),
        tags$img(src = paste0("_gallery/img/", x[["images_thumb"]]))
      )
  }))

}
```

]
Lastly, we need to embed this HTML code in `<div id="lightgallery">`, as shown in the first section. We can do that with the following code:

#block[
```r
withTags(
  div(
    class = "row",
    id = "lightgallery",
    tagList(
      make_gallery_layout()
    )
  )
)
```

]
We now have all the HTML code we need. We now have to add the CSS and the JavaScript code. We can just copy-paste it in an R Markdown file.

#html.elem("details")[
  #html.elem("summary")[
    Click to see the full R Markdown file.
  ]

  ````
  ---
  title: "Gallery"
  output:
    distill::distill_article
  ---


  ::: {.cell}

  :::


  <head>

  <link type="text/css" rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/lightgallery/1.6.0/css/lightgallery.min.css" />
  <script src="https://cdnjs.cloudflare.com/ajax/libs/lightgallery-js/1.4.1-beta.0/js/lightgallery.min.js"></script>

  <!-- lightgallery plugins -->
  <script src="https://cdnjs.cloudflare.com/ajax/libs/lg-fullscreen/1.2.1/lg-fullscreen.min.js"></script>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/lg-thumbnail/1.2.1/lg-thumbnail.min.js"></script>

  </head>


  ::: {.cell}

  ```{.css .cell-code}
  #lightgallery > a > img:hover {
     transform: scale(1.15, 1.15);
     transition: 0.4s ease-in-out;
     cursor: pointer;
  }
  ```
  :::





  ::: {.cell}

  ```{.r .cell-code}
  # Create layout
  withTags(
    div(
      class = "row",
      id = "lightgallery",
      tagList(
        make_gallery_layout()
      )
    )
  )
  ```
  :::


  <script type="text/javascript">
      lightGallery(document.getElementById('lightgallery'));
  </script>
  ````
]
== Update GitHub Actions
<update-github-actions>
We need to add `fs::dir_copy("_gallery/img", "_site/_gallery/img")` in GitHub Actions so that the images are found when the gallery is built. We also have to add `magick` and `httr` in the list of packages to install.

If you haven't set up GitHub Actions yet, you can check #link("https://www.etiennebacher.com/posts/2021-03-19-use-github-actions-with-r-markdown-and-distill/")[my previous post], or check my #link("https://github.com/etiennebacher/my_website/blob/master/.github/workflows/main.yml")[current GitHub Actions] for this site.

== Bonus: make a gallery for \#tidytuesday
<bonus-make-a-gallery-for-tidytuesday>
I have started participating to #link("https://github.com/rfordatascience/tidytuesday")[\#tidytuesday] this year, and the main reason I wanted to create a gallery was to display my favorite plots. Therefore, I created a function to make it as easy as possible for me to update the plots I want to display in the gallery.

The purpose of the function below is to download a plot for a specific week in a specific year in the #link("https://github.com/etiennebacher/tidytuesday")[repo containing my plots].

#block[
```r
library(httr)

get_tt_image <- function(year, week) {

  if (is.numeric(year)) year <- as.character(year)
  if (is.numeric(week)) week <- as.character(week)
  if (nchar(week) == 1) week <- paste0("0", week)

  ### Get the link to download the image I want
  req <- GET("https://api.github.com/repos/etiennebacher/tidytuesday/git/trees/master?recursive=1")
  stop_for_status(req)
  file_list <- unlist(lapply(content(req)$tree, "[", "path"), use.names = F)
  png_list <- grep(".png", file_list, value = TRUE, fixed = TRUE)
  png_wanted <- grep(year, png_list, value = TRUE)
  png_wanted <- grep(paste0("W", week), png_wanted, value = TRUE)
  # If a png file is called accidental_art, don't take it
  if (any(grepl("accidental_art", png_wanted))) {
    png_wanted <- png_wanted[-which(grepl("accidental_art", png_wanted))]
  }

  ### Link of the image I want to download
  origin <- paste0(
    "https://raw.githubusercontent.com/etiennebacher/tidytuesday/master/",
    png_wanted
  )

  ### Destination of this image
  destination <- paste0("_gallery/img/", year, "-", week, "-", trimws(basename(origin)))

  ### Download only if not already there
  if (!file.exists(destination)) {
    if (!file.exists("_gallery/img")) {
      dir.create("_gallery/img")
    }
    download.file(origin, destination)
  }

  ### Create the thumbnail if not already there
  thumb_destination <- paste0("_gallery/img/thumb-", year, "-", week, "-",
                        trimws(basename(origin)))
  if (!file.exists(thumb_destination)) {
    resize_image(paste0(year, "-", week, "-", trimws(basename(origin))))
  }

}
```

]
As you can see, this function downloads the plot I want, puts it in `_gallery/img` and creates the thumbnail. All I have to do now is to choose the plots I want to display and to apply the function to these year-week pairs in the R Markdown file.

Note that for some reason, this function sometimes fails on GitHub Actions because of HTTP error 403. I think this is related to the number of requests to GitHub API but what is strange is that this function isn't supposed to make a lot of requests, so it is still a mystery.

#html.elem("details")[
  #html.elem("summary")[
    Click to see the full R Markdown file.
  ]

  ````
  ---
  title: "Gallery"
  output:
    distill::distill_article
  ---


  ::: {.cell}

  :::


  <head>

  <link type="text/css" rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/lightgallery/1.6.0/css/lightgallery.min.css" />
  <script src="https://cdnjs.cloudflare.com/ajax/libs/lightgallery-js/1.4.1-beta.0/js/lightgallery.min.js"></script>

  <!-- lightgallery plugins -->
  <script src="https://cdnjs.cloudflare.com/ajax/libs/lg-fullscreen/1.2.1/lg-fullscreen.min.js"></script>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/lg-thumbnail/1.2.1/lg-thumbnail.min.js"></script>

  </head>


  ::: {.cell}

  ```{.css .cell-code}
  #lightgallery > a > img:hover {
     transform: scale(1.15, 1.15);
     transition: 0.4s ease-in-out;
     cursor: pointer;
  }
  ```
  :::





  ::: {.cell}

  ```{.r .cell-code}
  # Create layout
  withTags(
    div(
      class = "row",
      id = "lightgallery",
      tagList(
        make_gallery_layout()
      )
    )
  )
  ```
  :::


  <script type="text/javascript">
      lightGallery(document.getElementById('lightgallery'));
  </script>
  ````
]
== Conclusion
<conclusion>
In this post, I tried to explain how to build a gallery with a simple example. However, you can also check the #link("https://github.com/etiennebacher/my_website")[repo of my website] to have a clearer view of how to do so. I also added some CSS styling that is not described here, to limit the code to what is really necessary.

Check the #link("https://www.etiennebacher.com/gallery.html")[gallery] to see the result.
