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
  title: "Making POST requests with R",
  description: "An alternative to RSelenium to get data from dynamic webpages.",
  date: datetime(year: 2023, month: 05, day: 09),
  lang: "en",
)

= Making POST requests with R
<making-post-requests-with-r>
Preview picture from Kristina Tripkovic on Unsplash

A few months ago, I gave a training on `RSelenium`, a package that allows us to reproduce all the actions we do in a browser (open a website, scroll, click on a button, etc.) with some R code. This is very useful to perform some webscraping on pages that are #emph[dynamically updated], meaning that we can't simply use the URL to get the HTML we want. I won't explain the basics of webscraping here, there are plenty of articles on this already and the #link("https://rvest.tidyverse.org/articles/rvest.html")[vignettes on the `rvest` website] are very good.

Something I mentioned very briefly in my #link("https://www.rselenium-teaching.etiennebacher.com")[RSelenium slides] is that, in some cases, it is possible to avoid using RSelenium at all by performing the POST requests ourselves#footnote[In fact, I completely buried this in the Appendix because RSelenium was already plenty to teach and I didn't want to add another layer of complexity with POST requests.]. However, a few days ago, another case of dynamic webscraping came to me and I thought that maybe that was a good opportunity to try doing this first. But before diving into this example, let's explain a bit more POST (and GET) requests and why using them directly could save a lot of time.

= POST and GET requests: what?
<post-and-get-requests-what>
There are already a lot of resources on POST and GET requests, like #link("https://www.w3schools.com/tags/ref_httpmethods.asp")[this W3schools page], so here I will only do a brief summary.

== Requests and responses
<requests-and-responses>
What happens when we click on a button, open a new link, or other actions? The website sends a #emph[request] to the server, the server sends a #emph[response] back to us, and the website is updated using this new data that the server provided. There are several types of requests, the two most common being GET and POST requests.

Both GET and POST are used to request data but they have key differences.

== GET requests
<get-requests>
One important thing to note in GET requests is that the query parameters (which describe what data we want to obtain) are displayed in the URL after a question mark `?`. An example of GET requests is the World Bank API. Using an example on their website, we can start from this query to get the data for a specific indicator and all countries:

```
http://api.worldbank.org/v2/country/all/indicator/SP.POP.TOTL
```

By default, this will show the data in the XML format. If we want to use the JSON format instead, we can add a parameter `format` in the URL:

```
http://api.worldbank.org/v2/country/all/indicator/SP.POP.TOTL?format=json
```

This type of requests changes the URL, so this is not very useful in our case where the URL doesn't change at all.

== POST requests
<post-requests>
In a POST request, the website also sends information to the server and the server also sends data back to us but this time the URL doesn't change, the website is dynamically updated. This is often used when we fill a form online: depending on what the user provided, the data sent back by the server is not the same.

Basically, using RSelenium for dynamic webscraping boils down to go to the right webpage, fill the inputs so that a POST request is performed behind the scenes, and then scrape the data that the server provided.

But what if we could avoid doing all these steps by performing the POST requests directly from R? That would be quicker and we would also avoid all issues related to RSelenium (which can be a pain to properly set up). For this to work, we need to know the detailed request to send to the server.

= Making POST requests from R
<making-post-requests-from-r>
There are two main packages to do this: `httr` and `httr2`. The latter is just a couple of years old and has being developed with a lot of convenient built-in features (retries if a query failed, secure secrets, etc.#footnote[I'm just listing things that are written on the #link("https://httr2.r-lib.org/")[website of `httr2`], more details there.]).

We don't need very advanced features here so let's use `httr`. This package provides a function `POST()` that (surprise!) allows us to make POST requests. Let's explore this with an example.

= Example
<example>
The Spanish Office of Patents and Brands#footnote[Oficina Española de Patentes y Marcas.] has a #link("http://historico.oepm.es/buscador.php")[nice website] where you can get historical data about patents and brands from about mid-19th century to mid-20th century. You can type anything you want in the search bar (e.g a city name), specify the years range, and it provides a list of patents, their title, the exact date at which they were done, and some information on the person or company that made the patent.

#strong[Note:] this website is in HTTP only, not HTTPS. Therefore, if you use Firefox with the mode HTTPS Everywhere enabled, you need to put http:\/\/historico.oepm.es in the list of exceptions (see #link("https://support.mozilla.org/en-US/kb/https-only-prefs")[here]).

In the output table, we can see a "+" button for each row. Clicking on this button displays more detailed information for the patent (e.g the category it belongs to). Ideally, what we would like is to obtain this detailed information for all records. This had less to do with POST requests so I show how to do this in the "Bonus" section at the end.

This website is dynamically updated, meaning that we have to use RSelenium or reproduce POST requests. These are the packages we will use:

#block[
```r
library(httr)       # make POST requests
library(polite)     # be polite when we scrape
library(rvest)      # extract HTML tables
library(data.table) # for some data cleaning
```

]
== Step 1: find the POST request parameters
<step-1-find-the-post-request-parameters>
To see the requests and responses, we can use the tab "Network" in the developer console. Fill the search input (for example type "Madrid"), open the network tab and then click on the magnifying glass icon to run the query. You can see what we send to the server and what the server sends back:

#box(image("network-1.png"))

We see four lines:

- `search_lib.php`
- `Spanish.json`
- two PNG files

We already know that the information we want is not the images so we can discard the last two lines. The `Spanish.json` is intriguing, maybe the data we want is in this JSON? When we click on this request, we see the full URL, but if we open it in another tab, it turns out that this JSON only contains useless information like the loading message.

So there's only `search_lib.php` left, what we're looking for must be in there. We see several things when we click on it. First, we see that it is a POST request but if we open the URL, it says "Invalid arguments". This makes sense, there's nothing unique in this URL, nothing that would allow the server to know the records it should send back.

We can see a "Payload" tab when we click on the request and it seems that this is where our parameters are stored:

#box(image("network-2.png"))

== Step 2: build the query
<step-2-build-the-query>
Great, but how do we know the exact query? Well, the parameters are displayed in a cleaned way, but the button "View source" shows the raw query:

```
cadena=madrid&tb=SPH_MATCH_ALL&rangoa=1826%2C1966&indexes%5B%5D=privilegios&
indexes%5B%5D=patentes&indexes%5B%5D=patentes_upm&indexes%5B%5D=marcas&
timestamp=Mon May 08 2023 15:38:09 GMT+0200 (Central European Summer Time)
```

We can now replace the city, years or patent types in the query (the timestamp is useless so I remove it):

#block[
```r
city <- "madrid"
year1 <- 1850
year2 <- 1870

query <- paste0(
  "cadena=", city, "&tb=SPH_MATCH_ALL&rangoa=", year1, "%2C", year2,
  "&indexes%5B%5D=privilegios&indexes%5B%5D=patentes&indexes%5B%5D",
  "=patentes_upm&indexes%5B%5D=marcas"
)
```

]
== Step 3: perform the query
<step-3-perform-the-query>
We now have:

- the base URL that the website contacts to get the data
- the parameters in raw format

The next step is to actually perform the query:

#block[
```r
# use politely() to tell the website who is performing the requests and to add
# a delay between requests (here we only do one)
polite_POST <- politely(POST, verbose=TRUE) 

POST_response <- polite_POST(
  "http://historico.oepm.es/logica/search_lib.php",
  add_headers(
    "accept" = "*/*",
    "accept-language" = "en-GB,en-US;q=0.9,en;q=0.8",
    "content-type" = "application/x-www-form-urlencoded; charset=UTF-8",
    "x-requested-with" = "XMLHttpRequest"
  ),
  body = query
)
```

#block[
```
Fetching robots.txt
```

]
#block[
```
rt_robotstxt_http_getter: normal http get
```

]
#block[
```
Warning in request_handler_handler(request = request, handler = on_not_found, :
Event: on_not_found
```

]
#block[
```
Warning in request_handler_handler(request = request, handler =
on_file_type_mismatch, : Event: on_file_type_mismatch
```

]
#block[
```
Warning in request_handler_handler(request = request, handler =
on_suspect_content, : Event: on_suspect_content
```

]
#block[
```

New copy robots.txt was fetched from http://historico.oepm.es/robots.txt
```

]
#block[
```
Total of 0 crawl delay rule(s) defined for this host.
```

]
#block[
```
Your rate will be set to 1 request every 5 second(s).
```

]
#block[
```
Pausing... 
```

]
#block[
```
Scraping: http://historico.oepm.es/logica/search_lib.php
```

]
#block[
```
Setting useragent: polite R/4.5.0 (ubuntu-24.04) R (4.5.0 x86_64-pc-linux-gnu x86_64 linux-gnu) bot
```

]
]
You can see additional information in `add_headers()`. This information is available in the "Headers" tab when the click on the request. However, I don't really know why some of these headers are necessary and others are not. Note that you can easily get these headers by doing a right-click on the POST request (on the left of the "Network" tab) \> "Copy value" \> "Copy as fetch" and then pasting it anywhere.

== Step 4: extract the information
<step-4-extract-the-information>
We can extract the HTML from the response with `content()`:

#block[
```r
content(POST_response, "parsed")
```

#block[
```
{html_document}
<html>
[1] <body><div class="rs1 row space-bottom">\n<div class="col-md-10 col-xs-10 ...
```

]
]
This is the HTML code from the "Mostrando xxx de xxx resultados encontrados" to the bottom of the page. We only want the table, so we extract it with `rvest::html_table()`:

#block[
```r
content(POST_response, "parsed") |> 
  html_table()
```

#block[
```
[[1]]
# A tibble: 12 × 7
   ``    TIPO       SUBTIPO     EXPEDIENTE FECHA DENOMINACION_TITULO SOLICITANTE
   <lgl> <chr>      <chr>            <int> <chr> <chr>               <chr>      
 1 NA    Marca      ""                 103 1870… La Deliciosa        "Castellá,…
 2 NA    Marca      "Marca de …         54 1867… Fuente de los Cana… "Pérez, Te…
 3 NA    Marca      "Marca de …         50 1868… Campanadas para in… "Algar, Fé…
 4 NA    Marca      "Marca de …         66 1868… Compañía Española   "Cunill y …
 5 NA    Marca      "Marca de …         76 1869… Tinta Universal     "Hernando,…
 6 NA    Marca      "Marca de …         80 1869… La Cruz de Puerta … "Sánchez F…
 7 NA    Marca      "Marca de …         82 1869… Chocolate de la Co… "Méric Her…
 8 NA    Marca      "Marca de …          6 1866… La Corza            "Buj, Igna…
 9 NA    Privilegio "Privilegi…       1261 1855… MODO DE FABRICAR U… "COUAILHAC…
10 NA    Privilegio "Privilegi…       2015 1860… PROCEDIMIENTO PARA… "\"SOCIEDA…
11 NA    Privilegio "Privilegi…       2368 1861… PROCEDIMIENTO PARA… "ENRIQUEZ,…
12 NA    Privilegio "Privilegi…       2631 1863… PROCEDIMIENTO QUIM… "MADRID LE…
```

]
]
And voilà! You can now customize the query to loop through cities, years, etc. Note that by default, the number of records returned is limited to 250, and we can't bypass this.

#strong[Remember: use the package #link("https://dmi3kno.github.io/polite/")[`polite`] to avoid flooding the server with requests]. As they say on `polite`'s website, the four pillars of polite session are

#quote(block: true)[
Introduce Yourself, Seek Permission, Take Slowly and Never Ask Twice.
]

= Bonus
<bonus>
You know how to make POST requests, but at the beginning of the "Example" section, I said that I wanted the detailed information that is only displayed when we click on a "+" button in the table.

Using the same method as before, we see that clicking on one of these buttons triggers a GET request of the form `ficha.php?id=<ID>&db=<DB>`. Problem: these `<ID>` and `<DB>` change for each record and their value cannot be easily guessed. However, if we look at the HTML of these buttons, we can see that `<ID>` and `<DB>` are stored as attributes of the `<a>` tag:

#box(image("html-tag.png"))

Since the have the HTML of the full table (thanks to the POST request), we can extract these attributes with `html_nodes()`:

#block[
```r
# get all the attributes for all "+" buttons
list_attrs <- content(POST_response, "parsed") |> 
  html_nodes("td > a") |> 
  html_attrs()

# for each "+" button, extract only the id and db attributes
info <- lapply(list_attrs, function(x) {
  out <- x[names(x) %in% c("data-id", "data-db")]
  if (length(out) == 0) return(NULL)
  data.frame(id = out[1], db = out[2])
})

# remove cases where there are no attributes
info <- Filter(Negate(is.null), info)

# transform the list into a clean dataframe
out <- rbindlist(info)
head(out)
```

#block[
```
       id     db
   <char> <char>
1:      6 maruam
2:    130 maruam
3:    461 maruam
4:    523 maruam
5:    560 maruam
6:    581 maruam
```

]
]
We now have a very clean table with the `id` and `db` values for each row of the HTML table. We can now make a loop through all of these to create the URL and read it with `rvest` (I only do it once here to avoid making useless requests):

#block[
```r
read_html(
  paste0("http://historico.oepm.es/logica/ficha.php?id=", 
         6, "&db=", "maruam")
) |> 
  html_table()
```

#block[
```
[[1]]
# A tibble: 14 × 2
   X1                             X2                                      
   <chr>                          <chr>                                   
 1 Número de Marca                "103"                                   
 2 Denominación Breve             "La Deliciosa"                          
 3 Fecha Solicitud                "27-10-1870"                            
 4 Fecha Concesión                "24-03-1871"                            
 5 Fecha de publicación Concesión ""                                      
 6 Clasificación NIZA             "CLASE31"                               
 7 Caducidad                      "Caducada"                              
 8 Fecha Caducidad                "24-03-1891"                            
 9 Cesiones                       "Sí"                                    
10 Propietario                    "Castellá, Joaquín"                     
11 Lugar de residencia            "Madrid"                                
12 Provincia de residencia        "Madrid"                                
13 País de residencia             "ESPAÑA"                                
14 Profesión                      "Fabricante, industriales y empresarios"
```

]
]
There's still some cleaning to do but this post is quite dense so I'll stop here. The full code (POST + GET + cleaning) can be found on this repo, in the file "demo.R": #link("https://github.com/etiennebacher/webscraping-patents-spain")[webscraping-patents-spain]. Thanks for having read so far!
