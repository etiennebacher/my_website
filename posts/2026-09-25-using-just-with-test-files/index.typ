#import "/.calepin/calepin.typ" as calepin

#set document(title: [Using Just to run a subset of test files])
#metadata((
  title: "Using Just to run a subset of test files",
  kind: "post",
  date: "2026-09-25",
)) <website-metadata>

#calepin.setup(eval: true)

#title()

I now spend a lot of time in the terminal, whether to run Git, #link("https://posit-dev.github.io/air/")[Air] or #link("https://jarl.etiennebacher.com/")[Jarl].
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

Now, we can simply run `just test foo` to run test files whose name contain "foo", and `just test` to run all tests.
This is super useful if your test suite takes more than a few seconds to run#calepin.elements.sidenote[This works even better if you have autocompletion in your terminal.].

#html.elem("video", attrs: (alt: "This shows the terminal in the `tidypolars` project. Running `just test unnest` only runs two test files whose names contain 'unnest', and it skips dozens of other test files.", controls: ""))[
  #html.elem("source", attrs: (src: "demo_tidypolars.webm", type: "video/mp4"))
]

