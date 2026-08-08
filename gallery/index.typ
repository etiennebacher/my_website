#set document(title: [Gallery])
#metadata((title: "Gallery", summary: "Data visualization gallery", toc: (enabled: false))) <website-metadata>

#title()

A selection of the plots I made for \#TidyTuesday. Find the whole list
#link("https://github.com/etiennebacher/tidytuesday")[here].

#let images = (
  "2021-12-steam-games.png",
  "2021-13-un-votes.png",
  "2021-15-deforestation.png",
  "2021-16-us-post-offices.png",
  "2021-17-netflix-titles.png",
  "2021-23-survivor-tv.png",
  "2021-27-animal-rescue.png",
  "2021-40-nber-papers.png",
  "2022-09-alternative-fuel-stations.png",
  "2022-28-european-flights.png",
  "2022-47-uk-museums.png",
  "2022-51-temperature-predictions.png",
)

// The grid shows the thumbnails; the lightbox (theme/js/gallery.js) opens the
// full-size image from each link's href.
#html.div(
  class: "gallery-grid",
  for img in images {
    html.a(
      href: img,
      html.elem("img", "", attrs: (
        src: "thumb-" + img,
        alt: img.slice(0, -4),
        loading: "lazy",
        decoding: "async",
      )),
    )
  },
)
