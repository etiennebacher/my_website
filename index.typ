#import "/.calepin/calepin.typ" as calepin

#set document(title: [Etienne Bacher])
#metadata((title: "Etienne Bacher", toc: (enabled: false))) <website-metadata>

#title()

#calepin.elements.sidefigure[
  #image("imgs/etienne.jpg", alt: "Portrait of Etienne Bacher", width: 300pt)
]

Hi there! I'm Etienne Bacher.

I am a Research Software Engineer working at University College London for
#link("https://palaeoverse.org/")[Palaeoverse].

Before that, I completed a PhD in Economics as part of the
#link("https://sites.google.com/view/fredericdocquier/xingb-blog/across")[Doctoral Team Unit ACROSS]
at the Luxembourg Institute for Socio-Economic Research (LISER). I focused on
the relationship between cross-border mobility, attitudes and political
preferences using both contemporaneous and historical data.

I then worked as a Research Associate at LISER, helping on the INSKILL project
to study the effect of Artificial Intelligence on the labour market in Western
Europe.

In parallel, I develop or contribute to many R packages, all of which you can
find on #link("https://github.com/etiennebacher/")[my GitHub profile]. I also
write occasional blog articles about R and I have given some training on
several topics, available in the "Software" tab above.

If you want to contact me, the best way to do so is by email.

#let icon(name) = box(
  image("icons/" + name + ".svg", height: 12pt, fit: "contain"),
  baseline: 2pt,
)

#icon("github") #link("https://github.com/etiennebacher/")[etiennebacher]

#icon("mastodon") #link("https://mastodon.social/@etiennebacher")[\[at\]etiennebacher]

#icon("bluesky") #link("https://bsky.app/profile/etiennebacher.bsky.social")[etiennebacher.bsky.social]

#icon("envelope") #link("mailto:etienne.bacher@protonmail.com")[etienne.bacher\[at\]protonmail.com]
