#import "../index.typ": template, tufted

#show: template.with(
  title: "Blog",
  description: "",
)

// Blog entry helper: shows a card with optional preview image
#let blog-entry(date, path, title, preview: false) = {
  let href = path + "/"
  html.div(
    class: "blog-entry",
    {
      html.div(
        class: "blog-entry-date",
        date,
      )
      html.div(
        class: "blog-entry-content",
        html.a(href: href, title),
      )
      // if preview {
      //   html.div(
      //     class: "blog-entry-preview",
      //     html.elem("img", attrs: (
      //       src: href + "preview.png",
      //       alt: title,
      //       loading: "lazy",
      //     ), ""),
      //   )
      // }
    },
  )
}

= Blog

#blog-entry("2026-03-23", "2026-03-23-jarl-0.5.0", "Jarl 0.5.0")
#blog-entry("2026-02-03", "2026-02-03-jarl-0.4.0", "Jarl 0.4.0")
#blog-entry("2025-11-20", "2025-11-20-introducing-jarl", "Jarl: just another R linter")
#blog-entry("2025-05-23", "2025-05-23-refactoring-code-with-flir", "Refactoring code with flir")
#blog-entry("2024-10-01", "2024-10-01-using-property-testing-in-r", "Using property-based testing in R")
#blog-entry("2023-05-09", "2023-05-09-making-post-requests-with-r", "Making POST requests with R")
#blog-entry("2023-03-01", "2023-03-01-do-bonus-points-lead-to-more-tries-in-6-nations-matches", "Do bonus points lead to more tries in 6 Nations matches?")
#blog-entry("2023-01-14", "2023-01-14-where-should-my-family-meet", "Where should my family meet?", preview: true)
#blog-entry("2022-11-28", "2022-11-28-some-notes-about-improving-base-r-code", "Some notes about improving base R code")
#blog-entry("2021-12-27", "2021-12-27-mapping-french-rivers-network", "Mapping French rivers network")
#blog-entry("2021-12-23", "2021-12-23-reproduce-some-maps-about-3g-and-4g-access", "Reproduce some maps about 3G and 4G access")
#blog-entry("2021-04-11", "2021-04-11-how-to-create-a-gallery-in-distill", "How to create a gallery in Distill")
#blog-entry("2021-03-19", "2021-03-19-use-github-actions-with-r-markdown-and-distill", "Use GitHub actions with R Markdown and Distill")
#blog-entry("2020-10-18", "2020-10-18-nobel-laureates", "Visualize data on Nobel laureates per country", preview: true)
#blog-entry("2020-05-22", "2020-05-22-code-doesnt-work", "What to do when your code doesn't work?")
#blog-entry("2020-04-08", "2020-04-08-my-shiny-app", "My application for the Shiny Contest (2020)")
#blog-entry("2020-04-06", "2020-04-06-my-favorite-shortcuts", "My favorite shortcuts in RStudio")
#blog-entry("2020-01-22", "2020-01-22-first-contact", "First contact with the data on R", preview: true)
#blog-entry("2019-12-01", "2019-12-01-why-moving", "Why you should move from Stata to R")
