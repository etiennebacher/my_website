#import "/.calepin/calepin.typ" as calepin

#set document(title: [Snapshotting error messages])
#metadata((
  title: "Snapshotting error messages",
  kind: "post",
  date: "2026-09-15",
)) <website-metadata>

#calepin.setup(eval: true)

#title()

*Note:* this blog post focuses on test suites that use `testthat`, so it assumes some familiarity with writing `testthat` expectations. If you use `tinytest`, you might be able to get equivalent results with `tinysnapshot` but I haven't tried it personally.

== What's a snapshot?

A snapshot is a file that contains the output of a function as it would appear to the user.
For instance, you could snapshots to capture the output of `plot()` so that you can check that it looks correct and, most importantly, so that you know if this output changes even by just a few pixels in the future.

If you have a custom `print()` or `format()` method for your function, you can also use snapshots to check that the output of these functions looks like what you would expect.

== Why should I care about my error messages?

In this post, I don't want to talk plots or custom print methods, but rather I want to focus on error messages. Why? Because this is the first thing that users will see when something goes wrong and because it can be *particularly frustrating* when the error doesn't give you details about the what, where, and why of the error.

My view on this also changed when I started using Rust a few years ago. Before, I was more or less thinking "you just have to learn to recognize the error messages over time". After, it just felt so nice to have a language that just helps you work with it. I mean look at what happens if I try to compile this piece of code:

```rust
#| eval: false
fn my_fun() -> Option<i32> {
    true
}
```

```rust
#| eval: false
error[E0308]: mismatched types
  --> foo.rs:2:5
   |
32 | fn my_fun() -> Option<i32> {
   |                ----------- expected `std::option::Option<i32>` because of return type
33 |     true
   |     ^^^^ expected `Option<i32>`, found `bool`
   |
   = note: expected enum `std::option::Option<i32>`
              found type `bool`
```

Sure, you still need to know a bit about the language for this to make sense, but with these few lines, you know:

- the type of error (`mismatched types`)
- where it happened (`foo.rs:2:5`)
- why there is a mismatch between what the function is supposed to return (`Option<i32>`) and what it actually returns (`bool`)

And on top of that, in many cases (but not here), it will give you an actual code suggestion to fix the error.

So, bottom line: *error messages are important*.

Throughout this post, we will use a custom function that fails to explore how to test our error messages.
Let's make a function that does some computation^[I know this function doesn't make sense, this is for illustration only.]:

```r
# f <- function(column, multiplier) {
#   internal_computation(mtcars[, column], mean)
# }

# internal_computation <- function(x, y) {
#   x * log(x) / exp(y[1])
# }

# head(f("drat", 5), 1)
f <- function(dat, multiplier) {
  for (i in 1:ncol(dat)) {
    dat[[i]] <- dat[[i]] * internal_computation(multiplier)
  }
  dat
}

internal_computation <- function(x) {
  x * log(x) / exp(x)
}

head(f(mtcars, 5), 1)
```

== Testing error messages with `expect_error()`

`testthat` provides a function called `expect_error()` that you can use, well, when you expect a piece of code to produce an error.

In our dummy function above, we know that the multiplier must be a numeric value, and preferably one greater than 0 to avoid producing `NaN`s due to the `log()` operation.

We could check that this properly errors if we pass something cannot be coerced to a numeric value:

```r
testthat::expect_error(f(mtcars, "a"))
```

Yay, that passed! Let's go home.

Nope, the developer is happy because the test passes. And the user? Well that's a different experience:

```r
#| error: true
f(mtcars, "a")
```

Ah... well that could use some improvements.

[...]


`expect_error()` allows us to provide a regex that the message should match, so it is a bit better:

```r
testthat::expect_error(
  f(mtcars, "a"),
  regex = "non-numeric argument"
)
```

Still, the core of the message might be present but the surrounding information, such as the origin of the error, is not captured.
This means that even if the entire error message is of good quality today, we won't know if those unchecked parts of the message change in the future.


== Why would you snapshot an error message?

Instead of checking some parts of the error message, we can use snapshot tests to capture the entire output that is displayed in the console. This corresponds exactly to what the user will see.


```r
#| eval: false
testthat::local_edition(3)
testthat::expect_snapshot(
  f(mtcars, "a"),
  error = TRUE
)
```
```
── Snapshot ──────────────────────────────────────────────────────────────────────
ℹ Can't save or compare to reference when testing interactively.
Code
  f(mtcars, "a")
Condition
  Error in `log()`:
  ! non-numeric argument to mathematical function
──────────────────────────────────────────────────────────────────────────────────
```

Note that snapshots cannot be saved by running the code directly in the console. They are saved and checked in non-interactive settings, e.g. when running `devtools::test()` or `testthat::test_file()`.

== What about performance?

If you have very large test suites where you check many error messages, you might be worried about the performance implications.

`expect_snapshot(error = TRUE)` does take a bit more time than `expect_error()`. In the example file, checking 500 snapshots takes 7 seconds and checking 500 `expect_error()` takes about 3 seconds on my machine.

#html.elem("details")[
  #html.elem("summary")[
    Click to see a self-contained example to run
  ]

  ```r
  #| eval: false

  withr::with_tempdir({
    usethis::create_package("foo", open = FALSE)
    setwd("foo")
    usethis::use_test("snap", open = FALSE)

    writeLines(
      glue::glue(
        "test_that('foo-<i>', {
    expect_snapshot(log('a'), error = TRUE)
  })\n
  ",
        i = 1:500,
        .open = "<", .close = ">"
      ),
      "tests/testthat/test-snap.R"
    )

    writeLines(
      glue::glue(
        "test_that('foo-<i>', {
    expect_error(log('a'), regex = 'non-numeric argument')
  })\n
  ",
        i = 1:500,
        .open = "<", .close = ">"
      ),
      "tests/testthat/test-regex.R"
    )

    # Save the snapshots
    testthat::test_file(
      "tests/testthat/test-snap.R",
      reporter = testthat::SilentReporter
    )

    print(system.time({
      testthat::test_file("tests/testthat/test-snap.R")
    }))
    print(system.time({
      testthat::test_file("tests/testthat/test-regex.R")
    }))
  })
  ```
  ```
  ══ Testing test-snap.R ═══════════════════════════════════════════════════════════
  [ FAIL 0 | WARN 0 | SKIP 0 | PASS 500 ] Done!
    user  system elapsed
    6.918   0.213   7.096

  ══ Testing test-regex.R ══════════════════════════════════════════════════════════
  [ FAIL 0 | WARN 0 | SKIP 0 | PASS 500 ] Done!
    user  system elapsed
    2.882   0.136   2.997
  ```
]

Nevertheless, the overall impact on the test suite should be negligible, and this was a test case with many snapshots of error messages, which isn't common in R packages.


== How to transition to snapshots

If you've reached this section, then maybe I have convinced you to use snapshots to test error messages. However, this can be a very tedious process if you have many error expectations so you may wonder if there's an easy way to make this transition.

Lucky for you, there's a package for that \u{2122}.

#link("https://flir.etiennebacher.com/")[`flir`] is a package I created a few years ago that uses the Rust crate #link("https://ast-grep.github.io/")[`ast-grep`] to perform search and replace of any pattern of R code #calepin.elements.sidenote[This package was originally created to be an R linter and an alternative to `lintr`. However, its purpose evolved and it is now better to view it as a tool to refactor any type of code by detecting and rewriting custom patterns.]. It is perfectly suitable for the task we want to perform now, namely find an existing code pattern (`expect_error()`) and replace it with another one (`expect_snapshot(error = TRUE)`) without doing any other manual tweaks.

Here are the steps to follow once you have installed `flir`:

- in the folder containing your package, run `flir::setup_flir(".")`
- run `flir::add_new_rule("expect_snapshot_error", ".")`
- set up the rule:
  ```
  id: expect_snapshot_error
  language: r
  severity: warning
  rule:
    pattern: expect_error($A)
  # This could also be `expect_snapshot(error = TRUE, ~~A~~)` to clarify that
  # this code should error.
  fix: expect_snapshot(~~A~~, error = TRUE)
  message: foo
  ```
- `flir::fix_dir("tests", linters = "expect_snapshot_error")`
- remove the `flir` folder

Note that `flir` is not a formatter, so you will either need to check that the replaced code is properly formatted, or run a code formatter such as Air.

As an illustration of this workflow, here's a PR in a real package where I made this transition to snapshots: https://github.com/palaeoverse/palaeoverse/pull/173.

== What's next?

This post was purely about improving the checking infrastructure of error messages, but now the hard part is actually fixing or improving error messages displayed in the snapshots! Parts of this could be made easier, e.g. by using one of the many packages for input checking (#link("https://rlang.r-lib.org/index.html")[`rlang`], #link("https://mllg.github.io/checkmate/")[`checkmate`], #link("https://lrberge.github.io/dreamerr/")[`dreamerr`], #link("https://ngreifer.github.io/arg/")[`arg`], etc.), but some parts are very package-specific and require you to explore them.
