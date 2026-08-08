# etiennebacher.com

Personal website, built with [Calepin](https://vincentarelbundock.github.io/calepin).

Ported from the previous Quarto + [Tufted-Blog-Template](https://github.com/Yousa-Mirage/Tufted-Blog-Template)
site, which is kept alongside in `my_website/` for reference (excluded from the
build; see `[pages] exclude` in `calepin.toml`). It can be deleted once you are
happy with the port.

## Build

```sh
calepin compile .
calepin serve . --open
```

## Layout

```
index.typ            /                     home
posts/index.typ      /posts/               blog listing (generated from page metadata)
posts/<slug>/        /posts/<slug>/        one directory per post, assets alongside
research/index.typ   /research/
software/index.typ   /software/
gallery/index.typ    /gallery/             TidyTuesday plots
404.typ              /404.html
cv.pdf               /cv.pdf
_redirects           old blogdown and distill paths
```

Routes match the previous site exactly, so `_redirects` and any external links
keep working.

## Theme

The site uses a local Tufte theme in `theme/`, selected with `theme = "./theme"`
in `calepin.toml`. It is a thin overlay on Calepin's built-in `academic` theme,
adapted from the [Tufte case
study](https://github.com/vincentarelbundock/calepin/tree/main/docs/themes/examples/tufte)
(originally a single document) to a multi-page website:

- `theme/theme.toml` — `extends = "academic"`, so all layout, navigation,
  sidenote, and dark-mode behavior is inherited.
- `theme/css/60_tufte.css` — overrides the public `--calepin-*` tokens for the
  case study's warm paper and brick accents (light and dark), Palatino-ish
  serif type with a small-caps title and italic headings, and the site-level
  rules that give every page (not just standalone notebooks) a margin column
  for sidenotes and margin figures.
- `theme/css/70_gallery.css` + `theme/js/gallery.js` — the gallery grid and
  lightbox, carried over from the old site's `assets/`.
- `theme/layouts/pdf.typ` — the built-in `academic` PDF layout with Tufte page
  geometry (`marginalia`) and typography added. Currently unused (`pdf = false`).
- `theme/partials/site-nav-prev-next.html` — emptied on purpose; the old site
  had no prev/next pager.

Write margin material with `calepin.elements.sidenote` and
`calepin.elements.sidefigure`; both render in the margin and collapse inline on
narrow screens. The old site's `#footnote[...]` calls became sidenotes, which is
what the old theme rendered them as anyway.

### Table of contents

`[toc]` in `calepin.toml` turns on Calepin's floating TOC site-wide; the
standalone pages switch it off with `toc: (enabled: false)` in their
`<website-metadata>`, so only posts get one — as on the old site. Posts with no
headings (there are three) simply render without it.

The inherited `academic` theme floats the TOC into the *right* margin, which is
where sidenotes and margin figures already live, so the theme CSS repositions
it as a fixed column on the left. It appears only above 84rem of viewport
width, where there is room for the reading column, the right-hand margin, and
the TOC at once.

To compare against the bundled themes without editing `calepin.toml`:

```sh
calepin compile . --set theme=academic
calepin compile . --set theme=calepin
```

## How the posts were ported

`tools/port_posts.py` converted the 20 posts. The old `.typ` files were Pandoc
output: ~376 lines of Quarto boilerplate, then the Tufted template call, then
clean Typst with the R output already baked in. The script keeps that body —
re-running the R would need every package and data file the posts have used
since 2019 — and replaces the template call with Calepin metadata, `#title()`,
and `#calepin.setup(eval: false, fenced-chunks: false)` so Calepin does not try
to execute the ` ```r ` blocks.

The script reads from `my_website/`, so it only works until that directory is
deleted. It is kept for auditing the conversion, not as part of the build.

To write a new post, skip all of that and write Calepin Typst directly in
`posts/<date>-<slug>/index.typ` with `kind: "post"` and a `date` in its
`<website-metadata>`; the blog listing and the feeds pick it up automatically.

## Credits

- `imgs/etienne.jpg`: portrait photograph.
