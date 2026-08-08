#import "/.calepin/calepin.typ" as calepin

#set document(title: [Blog])
#metadata((title: "Blog", toc: (enabled: false))) <website-metadata>

#title()

// Built from page metadata rather than a hand-maintained list: every file in
// `posts/*/index.typ` that declares `kind: "post"` shows up here automatically.
#context {
  let posts = calepin
    .pages()
    .filter(p => p.meta.at("kind", default: "") == "post")
    .sorted(key: p => p.meta.at("date", default: ""))
    .rev()

  table(
    columns: (auto, 1fr),
    align: (left + top, left + top),
    ..posts
      .map(p => (
        text(fill: luma(40%))[#p.meta.at("date", default: "")],
        link(p.href)[#p.title],
      ))
      .flatten(),
  )
}
