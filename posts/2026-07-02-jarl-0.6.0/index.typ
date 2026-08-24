#import "/.calepin/calepin.typ" as calepin

#set document(title: [Jarl 0.6.0])
#metadata((
  title: "Jarl 0.6.0",
  kind: "post",
  date: "2026-07-02",
)) <website-metadata>

#calepin.setup(eval: false, fenced-chunks: false)

#title()

I'm glad to announce the release of #link("https://jarl.etiennebacher.com/")[Jarl] 0.6.0. Jarl is a very fast R linter, written in Rust. It finds inefficient, hard-to-read, and suspicious patterns of R code across dozens of files and thousands of lines of code in milliseconds. Install or update Jarl #link("https://jarl.etiennebacher.com/#installation")[via the command line] or install the #link("https://jarl.etiennebacher.com/howto/editors")[Jarl extension] in Positron, VS Code, Zed, and more.

A quick summary before diving into the details:

- Jarl has a new experimental rule (`unused_object`) to detect objects that are defined but never used. This is disabled by default because there may be false positives. However, we released it both because it can already be very useful and because it can be improved thanks to your bug reports!
- 16 new rules (in addition to `unused_object`)
- better experience with the command-line interface (CLI)
- Jarl can be installed via `uv`, `pixi`, `mise`, and more!

As usual, this release also comes with other small features and a whole lot of bug fixes. You can find the full list of changes in the #link("https://jarl.etiennebacher.com/changelog")[changelog].

= Find unused objects
<find-unused-objects>
Jarl 0.6.0 brings many new rules but `unused_object` probably is the most significant, and definitely was the most complicated to implement. `unused_object` is a rule that finds objects that are defined but never used, meaning that these definitions can be removed without affecting the rest of the code. Unused objects are usually pieces of code that were forgotten while refactoring some code, but they can also signal a bug somewhere if we expected this object to be used.

This rule is hard to implement for two reasons.

== Semantic analysis
<semantic-analysis>
The first one is shared across all languages: we need to have a good representation of the meaning of the code.

So far, most rules rely on #emph[patterns]. For example, if we find a piece of code that follows the pattern `any(is.na(<other code>))`, then we can report a violation of the `any_is_na` rule. This is relatively easy to implement because this is a small pattern that follows a logical construct: if we find a call to `any()` containing a call to `is.na()`, we report it.

In the case of `unused_object`, we need to find whether an object that was just defined is used anywhere in the subsequent code, whether it is called in a different file, whether it is overwritten before actually being used, etc.

We need to be able to analyze the relationship of all R objects in our code. In other words, we need to do some semantic analysis.

This is a big challenge that I haven't tackled myself. Instead, I relied upon the work of Lionel Henry and Davis Vaughan in #link("https://github.com/posit-dev/ark")[Ark] (in particular the `Oak` project). Thanks to their work, Jarl can now read the entire semantic structure of R code, which also requires handling the case of multi-file projects that share objects, such as R packages or scripts that call `source()`. Big thanks to both of them for their work!

== Everyone can manipulate R
<everyone-can-manipulate-r>
We have a strong foundation for our semantic analysis, and this already covers a lot of cases in real-world projects. Now comes the second reason why this rule is hard to implement: anyone can manipulate R code, and this leads to cases that slip through the cracks:

- string interpolation:

  #block[
  ```r
  x <- 1
  glue::glue("{x}")
  ```

  #block[
  ```
  1
  ```

  ]
  ]
  Jarl automatically handles string interpolation in the `glue`, `cli`, and `stringr` packages, but anyone could create their own functions to do string interpolation (see for instance #link("https://lrberge.github.io/stringmagic/")[stringmagic]) and Jarl isn't capable of handling them.

- non-standard evaluation (NSE):

  #block[
  ```r
  x <- 1
  q <- quote(x)

  env <- environment()
  eval(q, envir = env)
  #> [1] 1

  env[["x"]] <- 2
  eval(q, envir = env)
  #> [1] 2
  ```
  ]

  Suppose we cannot run any code (as-is the case in a static analysis tool like Jarl), should we consider that our `x <- 1` definition above is used? Hard to say because it entirely depends on `env`, which may have been modified in another place, and we can't explore its contents. Currently, Jarl reports `x` as unused.

  Similarly, in the following code, can we detect that `x` is actually used?

  #block[
  ```r
  my_expr <- quote(x + 1)
  f <- function(expr) {
    x <- 1
    eval(expr)
  }
  f(my_expr)
  ```

  #block[
  ```
  [1] 2
  ```

  ]
  ]
  When we evaluate the code, we can see that it is used, but in static analysis this is much harder to do because once we are in the function body, we would need to guess that `x` #emph[might] be used in `eval()`, walk back to `expr`, leading to `my_expr`, detect that `quote()` is used and that `x` is part of it.

  This might be doable in this simple example, but it is much harder to generalize. Currently, Jarl reports `x` as unused.

Nevertheless, despite these flaws, I believe that `unused_object` will be very useful in many projects.

*Reminder:* for now, you need to explicitly opt-in to use this rule.

= New rules
<new-rules>
16 new rules have been added since 0.5.0 (in addition to `unused_object`), thanks to several contributors. Most of these rules also exist in `lintr`, meaning that Jarl slowly but surely gets closer to feature parity, but a few of them are not found there. In particular, Jarl now reports cases of unused parentheses and empty R files.

= Better CLI experience
<better-cli-experience>
The CLI received some small but useful improvements.

== Autocomplete suggestions

It is now possible to press `<TAB>` to have suggestions of commands or rule names accepted by Jarl. For instance, `jarl check . --select any<TAB>` would suggest either `any_is_na` or `any_duplicated`.

This is supported in several shells, such as `fish`, `zsh`, and `bash`. See the #link("https://jarl.etiennebacher.com/dev/howto/shell-completions")[documentation] to know how to set this up with your shell.

== `jarl rule`

Jarl now has a new command `jarl rule <rulename>` to print the documentation of a specific rule directly in the terminal, hence avoiding an extra trip to the website.

```sh
> jarl rule any_is_na
any_is_na
Categories: PERF
Enabled by default: yes
Fix: safe

Added in 0.0.8

## What it does

Checks for usage of `any(is.na(...))`, `NA %in% x`, and `NA %notin% x`.

[...]
```

== Rule name suggestions

Jarl now suggests similar rule names when there is a typo in one of the names:

```sh
> jarl check . --select duplicated_argument,any_i_na

jarl failed
  Cause: Unknown rules in `--select`: duplicated_argument, any_i_na
  Help: Did you mean "duplicated_arguments"?
  Help: Did you mean "any_is_na"?
```

== Exclude folders

Jarl can exclude folders with the `--exclude` argument, similar to the `exclude` argument in `jarl.toml`. Note that this argument must take a `=`:

```sh
> jarl check . --exclude=inst,tests
```

== Better help docs organization

The help page is now clearly split into various sections:

```sh
Check a set of files or directories

Usage: jarl check [OPTIONS] <FILES>...

Arguments:
  <FILES>...
          List of files or directories to check or fix lints, for example `jarl check .`.

File selection:
      --exclude <FILES>
          List of file patterns to exclude from linting, separated by a comma (no spaces).

      [TRUNCATED FOR CONCISENESS]


Rule selection:
  -s, --select <RULES>
          Names of rules to include, separated by a comma (no spaces). This also accepts names of groups of rules, such as "PERF".

          [default: ""]

      [TRUNCATED FOR CONCISENESS]

Fix options:
  -f, --fix
          Automatically fix issues detected by the linter.

      [TRUNCATED FOR CONCISENESS]

Other options:
  -w, --with-timing
          Show the time taken by the function.

      [TRUNCATED FOR CONCISENESS]

Global options:
      --log-level <LOG_LEVEL>
          The log level. One of: `error`, `warn`, `info`, `debug`, or `trace`. Defaults to `warn`
```

= New ways to install Jarl
<new-ways-to-install-jarl>
Jarl is now available on #link("https://pypi.org/project/jarl-linter/")[PyPI] and #link("https://anaconda.org/channels/conda-forge/packages/jarl/overview")[conda-forge], meaning that it can be installed by `uv`, `mise`, `pixi`, and potentially more tools.

See the #link("https://jarl.etiennebacher.com/dev/#other")[installation instructions] for more info.

= Conclusion
<conclusion>
Jarl 0.6.0 brings many exciting features, try them out! If you find any issue, have feature ideas, or want to contribute, head to the #link("https://github.com/etiennebacher/jarl")[Github repository].

I'm glad that this release got code contributions from six people (in addition to myself), and I want to thank them and everyone else who contributed one way or another: #link("https://github.com/atsyplenkov")[\@atsyplenkov], #link("https://github.com/Bisaloo")[\@Bisaloo], #link("https://github.com/christopherkenny")[\@christopherkenny], #link("https://github.com/dieghernan")[\@dieghernan], #link("https://github.com/fh-mthomson")[\@fh-mthomson], #link("https://github.com/gisler")[\@gisler], #link("https://github.com/Goldziher")[\@Goldziher], #link("https://github.com/hfrick")[\@hfrick], #link("https://github.com/ilyaZar")[\@ilyaZar], #link("https://github.com/JosephBARBIERDARNAL")[\@JosephBARBIERDARNAL], #link("https://github.com/JosiahParry")[\@JosiahParry], #link("https://github.com/lwjohnst86")[\@lwjohnst86], #link("https://github.com/maelle")[\@maelle], #link("https://github.com/njtierney")[\@njtierney], #link("https://github.com/novica")[\@novica], #link("https://github.com/randy3k")[\@randy3k], #link("https://github.com/sebffischer")[\@sebffischer], #link("https://github.com/snystrom")[\@snystrom], and #link("https://github.com/Yousa-Mirage")[\@Yousa-Mirage].

// since <- "2026-03-24"
//
// x <- gh::gh(
//   "/repos/:owner/:repo/issues",
//   owner = "etiennebacher",
//   repo = "jarl",
//   since = since,
//   state = "all",
//   .limit = Inf
// )

// # closed items, plus those opened after the cutoff and still open
// x <- purrr::keep(x, \(i) {
//   i$state == "closed" || substr(i$created_at, 1, 10) >= since
// })

// users <- sort(unique(purrr::map_chr(x, c("user", "login"))))
// users <- grep("dependabot|etiennebacher", users, invert = TRUE, value = TRUE)

// clipr::write_clip(glue::glue_collapse(
//   glue::glue('#link("https://github.com/{users}")[\\@{users}]'),
//   ", ",
//   last = ", and "
// ))
