#import "tufted-lib/tufted.typ" as tufted

#let template = tufted.tufted-web.with(
  header-links: (
    "/": "Home",
    "/posts/": "Blog",
    "/research/": "Research",
    "/software/": "Software",
    "/gallery/": "Gallery",
    "/cv.pdf": "CV",
  ),

  website-title: "Etienne Bacher",
  author: "Etienne Bacher",
  website-url: "https://etiennebacher.com",
  lang: "en",
  feed-dir: ("/Blog/",),
  footer-elements: (
    "© 2026 Etienne Bacher",
    [#link("https://github.com/etiennebacher/my_website")[Website source] \u{00B7} Powered by #link("https://github.com/Yousa-Mirage/Tufted-Blog-Template")[Tufted-Blog-Template]],
  ),
)
