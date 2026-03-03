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
  title: "Where should my family meet?",
  description: "Or a mathematical way to evade the debate on the location of the next holidays.",
  date: datetime(year: 2023, month: 01, day: 14),
  lang: "en",
)

= Where should my family meet?
<where-should-my-family-meet>
Like many others, my family is quite split geographically: some are in Europe but in different countries, and some are in other continents. Given this distance between us, we don't gather in a single place that often.

This got me thinking: in which place should we meet if we wanted to minimize the total distance, i.e the sum of the distances made by each one? I'm just thinking in terms of distance as the crow flies, because of course the distance also depends on where we must go to take the plane, on the potential flight connections we have to make, etc.

This question is frequent in a lot of optimal location problems. For example, where should a factory be built so that it minimizes the sum of distances to a list of warehouses? However, I didn't know about it before thinking about my original question, and it's not as simple as it looked like to me. I thought a bit more about that, searched online, asked to other members of my family more comfortable with maths, and this blog post summarizes what I learnt from that.

As every other post on this blog, it will include some R code, but that will come later.

= The problem on a 2D plan
<the-problem-on-a-2d-plan>
The question I want to answer is: where should my family meet in order to minimize the total distance? Something that is not clearly mentioned here is that I want to minimize the total distance #strong[on a sphere] (because, surprise, the Earth is close to a sphere). This adds a layer of complexity, so let's start with a 2D analysis.

Suppose I have 5 points placed on a grid like below:

#box(image("index_files/figure-typst/unnamed-chunk-1-1.png"))

I want to find the point $\( X \, Y \)$ that minimizes the sum of distances from each point to $\( X \, Y \)$. Here, I use the #link("https://en.wikipedia.org/wiki/Euclidean_distance")[Euclidean distance], but other measures are possible (such as the #link("https://en.wikipedia.org/wiki/Taxicab_geometry")[Manhattan distance]). The formula for the Euclidean distance between two points $\( x_1 \, y_1 \)$ and $\( x_2 \, y_2 \)$ is:

$ d i s t = sqrt(\( x_1 - x_2 \)^2 + \( y_1 - y_2 \)^2) $

For example, the distance between the points $\( 1 \, 0 \)$ and $\( 2 \, 1 \)$ is#footnote[To be sure, we know that the distance between those two points is the diagonal of a square with sides of length 1, and that the length of the diagonal of a square with sides of length $a$ is $a sqrt(2)$.]:

Here, I want to find the point $\( X \, Y \)$ that minimizes:

$ T o t a l med d i s t a n c e = D = sum_(i = 1)^5 sqrt(\( x_i - X \)^2 + \( y_i - Y \)^2) $

The point $\( X \, Y \)$ that solves this is called the #link("https://en.wikipedia.org/wiki/Geometric_median")[geometric median], or $L_1$-median. If we only had two points, then any point on the segment between those two points would be a solution#footnote[For example, if the two points are separated by 1000 km, then putting the meeting point at 200 km from one and 800 km from the other would give the same total distance as putting the meeting point at 500 km far from each point.], but here, we have five points.

However, according to Wikipedia,

#quote(block: true)[
Despite the geometric median's being an easy-to-understand concept, computing it poses a challenge. \[…\] Therefore, only numerical or symbolic approximations to the solution of this problem are possible under this model of computation.
]

In other words, while it is theoretically possible to compute the exact solution to this problem, it is impossible to do so in reasonable time in practice when the number of points is very large (note that there are some special cases, such as $n = 3$ or $n = 4$). This is why we need to use an approximation algorithm.

We can use the Nelder-Mead method, which is a common method for function minimization. We first take a starting point, say $\( 0 \, 0 \)$. Two other points will be taken randomly. Then, the algorithm computes the function we want to minimize (here, the total distance) for each of the three random points. The two lowest points are kept, and the algorithm replaces the third one by its symmetric point relative to the line between the two lowest points. But an animation is worth a thousand words:

#box(image("Nelder-Mead_Rosenbrock.gif", width: 75.0%))

Animation by Nicoguaro - Own work, CC BY 4.0, https:\/\/commons.wikimedia.org/w/index.php?curid=51597575

In the animation above, the triangle moves and shrinks until it reaches the minimum. There are more available options than just reflecting the highest point. I found these two blog posts very helpful to understand how the Nelder-Mead method works:

- by #link("https://brandewinder.com/2022/03/31/breaking-down-Nelder-Mead/")[Mathias Brandewinder]
- by #link("https://alexdowad.github.io/visualizing-nelder-mead/")[Alex Dowad]

Another algorithm that is commonly used for that is the Weiszfeld algorithm. The idea is to start from a point $\( X_0 \, Y_0 \)$, update it using its derivatives to get $\( X_1 \, Y_1 \)$, and continue this process until the distance between two updates is under a certain threshold. I won't use this method here, so click on the arrow below if you want more details.

Click here to have more details about Weiszfeld algorithm and its R implementation.

List of steps in Weiszfeld algorithm:

- pick a random point $P_0 = \( X_0 \, Y_0 \)$
- compute $X_1 = frac(sum_(i = 1)^5 x_i / sqrt(\( x_i - X_0 \)^2 + \( y_i - Y_0 \)^2), sum_(i = 1)^5 1 / sqrt(\( x_i - X_0 \)^2 + \( y_i - Y_0 \)^2))$ and $Y_1 = frac(sum_(i = 1)^5 x_i / sqrt(\( x_i - X_0 \)^2 + \( y_i - Y_0 \)^2), sum_(i = 1)^5 1 / sqrt(\( x_i - X_0 \)^2 + \( y_i - Y_0 \)^2))$
- compute the distance $epsilon$ between $\( X_0 \, Y_0 \)$ and $\( X_1 \, Y_1 \)$
- repeat steps 2 and 3 until $epsilon$ is lower than an arbitrary threshold. This will give an approximate solution $\( X \, Y \)$.

To get the expressions above, we differentiate with respect to $X$:

Similarly,

Now, we can make a loop like the following:

- start with $X = X_0$ and $Y = Y_0$, and compute $X_1 = T \( X_0 \)$ and $Y_1 = T \( Y_0 \)$
- compute $X_2 = T \( X_1 \)$ and $Y_2 = T \( Y_1 \)$
- continue until the distance between $\( X_n \, X_(n + 1) \)$ and $\( Y_n \, Y_(n + 1) \)$ is smaller than an arbitrary $epsilon$.

Once again, I'm not mathematician, so this may seem not rigorous at all for someone with more experience. If you're interested in a rigorous explanation of Weiszfeld's algorithm, check out #link("https://ssabach.net.technion.ac.il/files/2015/12/BS2015.pdf")[this paper] (but there are many others online).

As usual with R, when you think of a widely used algorithm or feature, there's necessarily an R package for that. Here, I will use the package `Gmedian` and the function `Weiszfeld()`:

#block[
```r
library(Gmedian)
```

]
This function has 4 arguments:

- `X` is a matrix of points, where each row is an observation;
- `weights` is useful if we want to give more importance to some points. Here, we assume that all 4 points are equally important, so we set it to `NULL` (the default);
- `epsilon` is the threshold below which the algorithm will stop;
- `nitermax` is the maximum number of iterations that will be run. This is complementary to `epsilon`: the algorithm stops as soon as the difference between two $\( X \, Y \)$ is lower than `epsilon` or as the algorithm hits the maximum number of iterations.

We can keep the defaults for `epsilon` and `nitermax`, so we just need to create a matrix containing our four points, and run this in `Weiszfeld()`:

#block[
```r
# Create matrix
my_points <- rbind(c(1, 0), c(2, 1), c(-3, 0), c(0, 3), c(-2,2))
my_points
```

#block[
```
     [,1] [,2]
[1,]    1    0
[2,]    2    1
[3,]   -3    0
[4,]    0    3
[5,]   -2    2
```

]
```r
median_point <- Weiszfeld(my_points)
median_point
```

#block[
```
$median
           [,1]    [,2]
[1,] -0.2704185 1.36027

$iter
[1] 33
```

]
]
We can now compute the sum of distances between each original point and the geometric median:

#block[
```r
list_dist <- c()
for (i in 1:nrow(my_points)) {
  foo <- my_points[i, ]
  list_dist[i] <- dist(rbind(foo, median_point$median))
}
sum(list_dist)
```

#block[
```
[1] 10.71581
```

]
]
We can use the Nelder-Mead algorithm in R with the function `optim()` in the `stats` package (included in base R). First, we write the objective function and feed `optim()` with it, along with the parameters (our list of points and a point from which to start).

#block[
```r
# Inputs:
# - starting_p: a vector (x, y) indicating from which point to start
# - my_p: a matrix where each row is a point in our list
criterion_2D <- function(starting_p, my_p) {
  # Formula for the sum of Euclidean distances
  f <- sum(sqrt((starting_p[1] - my_p[, 1])^2 + (starting_p[2] - my_p[, 2])^2))
}

output <- optim(par = c(0, 0), criterion_2D, my_p = my_points)

# Location of the optimal point
output$par
```

#block[
```
[1] -0.2701872  1.3599835
```

]
```r
# Total distance
output$value
```

#block[
```
[1] 10.71581
```

]
]
As we can see, this solution automatically gives us the optimal location and the total distance. It also doesn't require an external package, which is interesting if you want to reduce the dependencies you use. In the example above, the optimal point is therefore at (-0.27, 1.36), and the total distance is 10.72:

#box(image("index_files/figure-typst/unnamed-chunk-6-1.png"))

Now that we know how to solve the problem in 2D, let's move to 3D with a sphere, where it is slightly more complicated.

= The problem with a sphere
<the-problem-with-a-sphere>
== Finding points on a sphere
<finding-points-on-a-sphere>
Points on a sphere are often referred to by their latitude and longitude. However, if we want to compute the distance between points on a sphere, we need to get 3 coordinates $\( x \, y \, z \)$. How do we do that?

First, we have to change the unit of the points to use radians instead of degrees. This is done by multiplying the values in degrees by pi and dividing them by 180.

Then, we need to compute the 3 coordinates $x$, $y$, and $z$ as follows:

$x = c o s \( l a t i t u d e \) times c o s \( l o n g i t u d e \) times R$

$y = c o s \( l a t i t u d e \) times s i n \( l o n g i t u d e \) times R$

$z = s i n \( l a t i t u d e \) times R$

where $R$ is the radius of the sphere.

Let's make an example. We define some random points on a sphere with their latitude and longitude in degrees:

#block[
```r
# R = earth radius (km) 
R <- 6200

# Latitude, longitude for a few locations in degrees
latitude <- c(45, -40, 30, -30)
longitude <- c(-10, 10, 50, 50)

# Convert to radians
latitude_r <- latitude * pi / 180
longitude_r <- longitude * pi / 180

# x,y,z coordinates for the locations
x <- cos(latitude_r) * cos(longitude_r) * R
y <- cos(latitude_r) * sin(longitude_r) * R
z <- sin(latitude_r) * R

my_points <- cbind(x,y,z)
my_points
```

#block[
```
            x         y         z
[1,] 4317.458 -761.2844  4384.062
[2,] 4677.320  824.7378 -3985.283
[3,] 3451.356 4113.1665  3100.000
[4,] 3451.356 4113.1665 -3100.000
```

]
]
== Computing the distance
<computing-the-distance>
We know how to express the location of points using three coordinates. We can now think about how we will measure the distance between these points.

Suppose we have two points, $P_1$ and $P_2$, and we want to measure the distance $l$. If we were in an Euclidean space, we would compute the distance $d$ between the two points, which is equal to $sqrt(\( x_1 - x_2 \)^2 + \( y_1 - y_2 \)^2 + \( z_1 - z_2 \)^2)$, but that's not what we're looking for because it doesn't take into account the curvature of the sphere.

#align(center)[#box(image("index_files/figure-typst/unnamed-chunk-8-1.png"))]
By definition, $l = R times theta$. We know the radius, so we need to compute $theta$. The triangle is isosceles, so dividing the angle in two equal parts will give us two rectangle triangles where we can compute $theta / 2$. Indeed, $ s i n \( theta / 2 \) = frac(d \/ 2, R) $ $ theta / 2 = a r c s i n \( frac(d \/ 2, R) \) $ $ theta = 2 times a r c s i n \( frac(d \/ 2, R) \) $

#align(center)[#box(image("index_files/figure-typst/unnamed-chunk-9-1.png"))]
Therefore, we have: $ l = 2 R times a r c s i n \( frac(d \/ 2, R) \) $

Now that we have a way to measure the distance between two points based on their 3 coordinates, we can follow the same procedure as in the 2D case: make a function and give it to `optim()`. However, the objective function to minimize is different because we now use the formula above for the distance.

#block[
```r
# Inputs:
# - starting_p: a vector (lat, long, both in degrees) indicating from which point to start
# - my_p: a matrix where each row is a point in our list, and 3 columns (one for
#   each dimension)
criterion_3D <- function(starting_p, my_p) {
  # Convert degrees in radians
  plat <- starting_p[1] * pi / 180
  plon <- starting_p[2] * pi / 180
  # Compute the x, y, z coordinates
  x <- cos(plat) * cos(plon) * R
  y <- cos(plat) * sin(plon) * R
  z <- sin(plat) * R

  # Return the total distance
  sum(
    2*R*asin(
      sqrt(
        (x - my_points[, 1])^2 + (y - my_points[, 2])^2 + (z - my_points[, 3])^2
      )
    / 2 /R)
  )
}
```

]
We can now apply once again the `optim()` function:

#block[
```r
# Initial point (latitude, longitude, in degrees)
y <- optim(c(0,0), criterion_3D, my_p = my_points) 
y$par
```

#block[
```
[1] -4.532362 31.660719
```

]
```r
y$value
```

#block[
```
[1] 18606.59
```

]
]
So in this dummy example, the optimal location is in -4.53° lat., 31.66° long., and the total distance 18606.59 km.

== Making an interactive globe
<making-an-interactive-globe>
Now the most important part: show the solution on a globe! There are several ways to do this. One of them is to use `echarts4r`:

```r
library(echarts4r)
library(echarts4r.assets)
coords <- data.frame(
  lat = latitude,
  long = longitude,
  lat_sol = y$par[1],
  long_sol = y$par[2]
)

coords |> 
  e_charts() |> 
  
  # create the globe
  e_globe(
    base_texture = ea_asset("world"), 
    displacementScale = 0.05,
    shading = "color",
    viewControl = list(autoRotate = FALSE, targetCoord = c(10, 0))
  ) |> 
  
  # add the starting points
  e_scatter_3d(
    long, lat,
    coord_system = "globe",
    symbolSize = 15,
    itemStyle = list(color = "red"),
    emphasis = list(label = list(show = FALSE))
  ) |> 
  
  # add the solution
  e_scatter_3d(
    long_sol, lat_sol,
    coord_system = "globe",
    symbolSize = 15,
    itemStyle = list(color = "yellow")
  ) |> 
  
  # add tooltip with latitude and longitude (only works for
  # starting points)
  e_tooltip(
    trigger = "item",
    formatter = htmlwidgets::JS("
      function(params){
        return('Longitude: ' + params.value[0] + '<br />Latitude: ' + params.value[1])
      }
    ")
  ) |> 
  e_legend(FALSE)
```

#box(image("index_files/figure-typst/unnamed-chunk-12-1.png"))

We now have a solution, but the question is: what if the optimal meeting point is located in the middle of the Pacific Ocean? That wouldn't be the most convenient point for a family meeting (unless you have a yacht).

So far, we didn't care about this. We did some unconstrained optimization. The next step is to add the constraint that the meeting cannot happen at a place covered by oceans. I will try to explore that in a future post, but so far I didn't find many resources on this. If you have some ideas on how to do this or where to start from, feel free to let a comment.

Thanks for having read so far!
