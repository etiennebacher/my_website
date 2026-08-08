#import "/.calepin/calepin.typ" as calepin

#set document(title: [Mapping French rivers network])
#metadata((
  title: "Mapping French rivers network",
  kind: "post",
  date: "2021-12-27",
)) <website-metadata>

// Code blocks in these posts are already-rendered output from the original
// Quarto build, not live chunks. Keep Calepin from executing them.
#calepin.setup(eval: false, fenced-chunks: false)

#title()

#figure([
#box(image("original_map.png", alt: "Spanish rivers network, by Dominic Royé"))
], caption: figure.caption(
position: bottom, 
[
Spanish rivers network, by Dominic Royé
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)

Once again inspired by #link("https://dominicroye.github.io/en/graphs/geography/")[Dominic Royé]'s maps, I decided to map rivers in France. The dataset I use comes from #link("https://hydrosheds.org/")[HydroSHEDS]. The code below is quite similar to the code in my #link("https://www.etiennebacher.com/posts/2021-12-23-reproduce-some-maps-about-3g-and-4g-access/")[previous post] so I don't spend a lot of time on it.

```r
library(ggplot2)
library(ggtext)
library(sf)
```

```
Linking to GEOS 3.12.1, GDAL 3.8.4, PROJ 9.4.0; sf_use_s2() is TRUE
```

```r
library(rnaturalearth)
```

```r
france <- ne_countries(country = "France", scale = 'medium',
                       type = 'map_units', returnclass = 'sf')

rivers_30sec <- read_sf("eu_riv_30s.shp") |>
  st_intersection(france)
```

```
Warning: attribute variables are assumed to be spatially constant throughout
all geometries
```

```r
x <- ggplot() +
  geom_sf(
    data = rivers_30sec,
    color = "#002266"
  ) +
  labs(
    title = "Rivers network in France",
    subtitle = "This map displays 18,099 rivers. These are<br> measured at a grid resolution of 30 arc-seconds<br> (approx. 1km at the equator).",
    caption = "Made by Etienne Bacher &middot; Data from HydroSHEDS"
  ) +
  theme_void() +
  theme(
    plot.background = element_rect(fill = "white", color = "white"),
    panel.background = element_rect(fill = "white", color = "white"),
    plot.title = element_markdown(
      hjust = 0.5,
      size = 30,
      margin = margin(t = 10, b = -20)
    ),
    plot.subtitle = element_markdown(
      margin = margin(t = 40, b = -60, l = 10),
      size = 12
    ),
    plot.caption = element_markdown(
      hjust = 0.5,
      margin = margin(l = 10, b = 20, t = -30)
    ),
    text = element_text(family = "Roboto Condensed")
  )

ggsave("france_30sec.png", plot = x, width = 8, height = 8)
```

#box(image("france_30sec.png"))

This plot shows the density of rivers in France. Now, if we want to show which rivers are the most important, we can modify the opacity of the lines depending on their flow:

```r
x <- ggplot() +
  geom_sf(
    data = rivers_30sec,
    mapping = aes(alpha = UP_CELLS),
    color = "#002266"
  ) +
  labs(
    title = "Rivers network in France",
    subtitle = "This map displays 18,099 rivers. These are<br> measured at a grid resolution of 30 arc-seconds<br> (approx. 1km at the equator). Line opacity<br> represents the size of the flow.",
    caption = "Made by Etienne Bacher &middot; Data from HydroSHEDS"
  ) +
  theme_void() +
  theme(
    plot.background = element_rect(fill = "white", color = "white"),
    panel.background = element_rect(fill = "white", color = "white"),
    plot.title = element_markdown(
      hjust = 0.5,
      size = 30,
      margin = margin(t = 10, b = -20)
    ),
    plot.subtitle = element_markdown(
      margin = margin(t = 40, b = -60, l = 10),
      size = 12
    ),
    legend.position = "none",
    plot.caption = element_markdown(
      hjust = 0.5,
      margin = margin(l = 10, b = 20, t = -30)
    ),
    text = element_text(family = "Roboto Condensed")
  )

ggsave("france_30sec_opac.png", plot = x, height = 8, width = 8)
```

#box(image("france_30sec_opac.png"))
