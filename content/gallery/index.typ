#import "../index.typ": template, tufted
#show: template.with(
  title: "Gallery",
  description: "Data visualization gallery",
)

A selection of the plots I made for \#TidyTuesday. Find the whole list #link("https://github.com/etiennebacher/tidytuesday")[here].

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

#html.div(class: "gallery-grid",
  for img in images {
    html.a(href: img,
      html.img(src: img, alt: img.slice(0, -4))
    )
  }
)
