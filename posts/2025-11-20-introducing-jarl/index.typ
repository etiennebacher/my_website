#import "/.calepin/calepin.typ" as calepin

#set document(title: [Jarl: just another R linter])
#metadata((
  title: "Jarl: just another R linter",
  kind: "post",
  date: "2025-11-20",
  summary: "Remove bad patterns in your R code in the blink of an eye.",
)) <website-metadata>

// Code blocks in these posts are already-rendered output from the original
// Quarto build, not live chunks. Keep Calepin from executing them.
#calepin.setup(eval: false, fenced-chunks: false)

#title()

I'm very excited to introduce #link("https://jarl.etiennebacher.com/")[Jarl]#calepin.elements.sidenote[Jarl stands for "Just Another R Linter".], a new R linter. A linter is a tool that statically parses code (meaning that it doesn't run the code in question) and searches for patterns that are inefficient, hard to read, or likely bugs.

Jarl can parse dozens of files and thousands of lines of code in milliseconds. Here is an example of Jarl running on #link("https://github.com/wch/r-source/")[r-source] (approximately 1000 files and 200k lines of R code) in about 700 milliseconds:

#html.elem("video", attrs: (width: "60%", height: "60%", alt: "Running `jarl check . --with-timing` on the 'r-source' repository. This runs in about 700ms and returns hundreds of rule violations detailing the diagnostic and how to fix it.", controls: ""))[
  #html.elem("source", attrs: (src: "demos/lint-r-source.webm", type: "video/mp4"))
]

On top of that, Jarl can apply automatic fixes#calepin.elements.sidenote[This is not always possible, it depends on the rule.]. Suppose that we have the following file `foo.R`:

```r
x <- any(is.na(mtcars))

f <- function(x) {
  apply(x, 1, mean)
}
```

There are two rule violations in this file:

+ `any(is.na(mtcars))` should be replaced by `anyNA(mtcars)`#calepin.elements.sidenote[`anyNA(x)` is more efficient than `any(is.na(x))`.]\;
+ `apply(x, 1, mean)` should be replaced by `rowMeans(x)`#calepin.elements.sidenote[`rowMeans(x)` is more efficient than `apply(x, 1, mean)`.].

Instead of fixing those cases by hand, we can run the following command in the terminal (not in the R console):

```sh
jarl check foo.R --fix
```

After running this, `foo.R` now contains the following code:

```r
x <- anyNA(mtcars)

f <- function(x) {
  rowMeans(x)
}
```

\(Note that `f` is now useless since it is equivalent to `rowMeans()`.)

Jarl stands on the shoulders of giants, in particular:

- #link("https://lintr.r-lib.org/")[lintr]: this R package provides dozens of rules from various sources to lint R code, and Jarl wouldn't exist without this package. Jarl currently supports 25 `lintr` rules.
- #link("https://posit-dev.github.io/air/")[Air]: this is a fast R formatter written in Rust, developed by Lionel Henry and Davis Vaughan, and released earlier this year. It is also a command-line tool that runs in the terminal. It is the technical foundation on which Jarl is built since Air provides the infrastructure to parse and manipulate R code.

Jarl is a single binary, meaning that it doesn't need an R installation to work. This makes it a very attractive option for continuous integration for instance, since it takes less than 10 seconds to download the binary and run it on the repository.

== Using Jarl
<using-jarl>
There are two ways to use Jarl:

+ via the terminal, using `jarl check [OPTIONS]`\;
+ using the integration in your coding editor (at the time of writing, a Jarl extension is available in VS Code, Positron, and Zed).

The Jarl extension enables code highlighting and quick fixes. The former means that code that violates any of the rules in your setup (more on this below) will be underlined and will show the exact violation when hovered.

#html.elem("video", attrs: (width: "60%", height: "60%", alt: "This shows the same file 'foo.R', but this time the two pieces of code that violate the rules are underlined in yellow. Hovering these two pieces of code show a popup detailing the diagnostic.", controls: ""))[
  #html.elem("source", attrs: (src: "demos/hover.webm", type: "video/mp4"))
]

The latter adds a lightbulb button next to rule violations, allowing you to selectively apply fixes or ignore violations.

#html.elem("video", attrs: (width: "60%", height: "60%", alt: "This shows the same file 'foo.R'. This time, clicking on the code that violate the rules displays a small lightbulb icon that applies the automatic fix when clicked.", controls: ""))[
  #html.elem("source", attrs: (src: "demos/quick-fixes.webm", type: "video/mp4"))
]

In the future, those extensions could have a "Fix on save" feature similar to the "Format on save" functionality provided by Air.

== Configuring Jarl
<configuring-jarl>
By default, Jarl will report violations for almost of its rules. It is possible to configure its behavior using a configuration file named `jarl.toml`. In particular, in this file, you can specify:

- the rules you want to apply,
- the files to include or exclude,
- the rules for which you want to apply automatic fixes,

and more.

== Conclusion
<conclusion>
Jarl is in its early days, there are more rules and options to add. Still, it can already be used in interactive use or in continuous integration (check out the #link("https://github.com/etiennebacher/setup-jarl")[`setup-jarl` workflow]!). Eventually, many `lintr` rules should be supported in Jarl, but the end goal is not to have perfect compatibility. `lintr` provides many rules related to code formatting (e.g.~#link("https://lintr.r-lib.org/dev/reference/spaces_inside_linter.html")[spaces\_inside\_linter]). Those will not be integrated in Jarl since they are already covered by Air. Additionally (for now), Jarl cannot perform semantic analysis#calepin.elements.sidenote[Semantic analysis refers to using the context surrounding an expression to explore rule violations.], meaning that some `lintr` rules are out of scope (e.g.~#link("https://lintr.r-lib.org/dev/reference/unreachable_code_linter.html")[unreachable\_code\_linter]).

This was a very light introduction, go to the #link("https://jarl.etiennebacher.com/")[Jarl website] for more information.

If you want to help developing Jarl, check out the #link("https://jarl.etiennebacher.com/contributing")["Contributing" page]. Jarl is written in Rust, which may be a barrier to contributing but is also a very powerful language which is a real pleasure to use. I will add a more detailed tutorial soon so that this can also be a nice introduction to this language. You can also contribute to the documentation!

= Acknowledgements
<acknowledgements>
As I said above, Jarl depends enormously on the work of #link("https://lintr.r-lib.org/authors.html")[`lintr`] and Air developers, so thank you!

Jarl is also very inspired by similar tools in other languages, in particular #link("https://docs.astral.sh/ruff/")[Ruff] in Python and #link("https://github.com/rust-lang/rust-clippy")[Cargo clippy] in Rust.

Finally, thanks to the #link("https://r-consortium.org/")[R Consortium] for funding part of the development of Jarl via the ISC Grant Program.

And thank you, Maëlle, for improving the draft!
