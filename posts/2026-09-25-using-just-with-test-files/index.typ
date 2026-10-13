#import "/.calepin/calepin.typ" as calepin

#set document(title: [Using Just to run a subset of test files])
#metadata((
  title: "Using Just to run a subset of test files",
  kind: "post",
  date: "2026-09-25",
)) <website-metadata>

#calepin.setup(eval: true)

#title()

I now spend a lot of time in the terminal, whether to run Git, #link("https://posit-dev.github.io/air/")[Air], or #link("https://jarl.etiennebacher.com/")[Jarl].
Lately I've been using #link("https://github.com/casey/just")[`Just`] to run custom commands to lint, format, and test code.

`Just` is an #link("https://github.com/casey/just#pre-built-binaries")[easy-to-install] command runner.
It allows one to define commands in a `justfile` and run them with `just <command name>`.
For instance, our `justfile` could define a `lint` command that would run a custom Jarl command:

```
lint:
  jarl check . --output-format concise
```

and then we could call `just lint` in the terminal.

I was already using Just in #link("https://tidypolars.etiennebacher.com/")[`tidypolars`], a project whose test suite has thousands of tests that usually take about two to three minutes to run, but #link("https://github.com/Yousa-Mirage")[\@Yousa-Mirage] gave the nice suggestion to add the following rule in `justfile`:

```
test filter="":
    Rscript -e 'devtools::test(filter = commandArgs(TRUE)[[1]])' {{ quote(filter) }}
```

This uses the `filter` argument in `devtools::test()` to only run test files whose name contain the value of `filter`. However, running this in the R console is a bit annoying as I either need to write it in full, or to navigate the console history and modify the value of `filter`.

Now, I can go to the terminal and run `just test foo`, `just test bar`, etc.
This is very useful if your test suite takes more than a few seconds to run#calepin.elements.sidenote[This works even better if you have autocompletion in your terminal.].

#html.elem("video", attrs: (alt: "This shows the terminal in the `tidypolars` project. Running `just test unnest` only runs two test files whose names contain 'unnest', and it skips dozens of other test files.", controls: ""))[
  #html.elem("source", attrs: (src: "demo_tidypolars.webm", type: "video/mp4"))
]

_Couldn't you simply use Make instead of Just?_

Probably. I just never had to write Makefiles and discovered Just via a co-developer.

I'm pretty sure Make would also work fine for this simple example, but the #link("https://github.com/casey/just#just")[Just docs] list many differences and improvements over Make. The goal of this post was just to showcase a small quality-of-life improvement in my workflow.
