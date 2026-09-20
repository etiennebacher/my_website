#import "/.calepin/calepin.typ" as calepin

#set document(title: [Snapshotting error messages])
#metadata((
  title: "Snapshotting error messages",
  kind: "post",
  date: "2026-09-21",
)) <website-metadata>

#calepin.setup(eval: true)

#title()

*Note:* this blog post focuses on test suites that use `testthat`, so it assumes some familiarity with writing `testthat` expectations, but the code itself is less important than the message I try to convey. If you use `tinytest`, you might be able to get equivalent results with #link("https://cran.r-project.org/web/packages/tinysnapshot/")[`tinysnapshot`] but I haven't tried it personally.

= What's a snapshot?

A snapshot is a file that contains the output of a function as it would appear to the user.
For instance, you could save snapshots to capture the output of `plot()` so that you can check that it looks correct, and so that you know if this output changes even by just a few pixels in the future.

If you have a custom `print()` or `format()` method for your function, you can also use snapshots to check that the output of these functions looks like what you would expect.

= Why should I care about my error messages?

In this post, I don't want to talk about plots or custom print methods, but rather I want to focus on error messages. Why? Because this is the first thing that users will see when something goes wrong and because it can be *particularly frustrating* when the error doesn't give you details about the what, where, and why of the error.

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

Throughout this post, we will use a custom function that fails in some cases to explore how to test our error messages.
Let's make a function that does some computation #calepin.elements.sidenote[I know this function doesn't make sense, this is for illustration only.]:

```r
f <- function(column) {
  internal_computation(iris[, column])
}

internal_computation <- function(x) {
  x * log(x) / exp(x)
}

head(f("Sepal.Length"), 1)
```

= Testing error messages with `expect_error()`

`testthat` provides a function called `expect_error()` that you can use, well, when you expect a piece of code to produce an error.

In our dummy function above, we know that the column must be numeric so that `log()` and `exp()` work. We could check that this properly errors if we pass a column name that is not numeric:

```r
testthat::expect_error(f("Species"))
```

Yay, that passed! Let's go home.

Nope, the developer is happy because the test passes. And the user? Well that's a different experience:

```r
#| error: true
f("Species")
```

Ah... well that could use some improvements. This tells me that `log()` isn't meaningful for factors. Alright, but I didn't call `log()`, I called `f()`. And although sometimes I know how a function is supposed to work, I'm not supposed to know everything about the internals of `f()`. And what is this `Math.factor()` that created this error?

As we can see, the developer view and the user view conflict here: the developer is happy because  code coverage is 100%, but users has a terrible experience when they do something _slightly_ wrong with the function. They don't know what they did wrong and they have no idea how to fix it.

Let's stay on the developer point of view here. How can we ensure our error check leads to better code? One way would be to be stricter in `expect_error()`. We can provide a regex that the message should match, so at least we know that the error should contain some key message:

```r
#| error: true
testthat::expect_error(
  f("Species"),
  regex = "cannot pass a column of type 'factor'"
)
```

This doesn't pass with the current implementation of `f()`, meaning that I would now need to refactor `f()` for this to pass.

This forces us to think more about the error message, so it is an improvement.
Still, the core of the message might be present but the surrounding information, such as the origin of the error (in the example above, that would be `Math.factor()`), is not captured.
This means that even if the entire error message is of good quality today, we won't know if those unchecked parts of the message degrade in the future.


= Why would you snapshot an error message?

Instead of checking some parts of the error message, we can use snapshot tests to capture the entire output that is displayed in the console. This corresponds exactly to what the user will see.


```r
#| eval: false
testthat::local_edition(3)
testthat::expect_snapshot(
  f("Species"),
  error = TRUE
)
```
```
── Snapshot ──────────────────────────────────────────────────────────────────────
ℹ Can't save or compare to reference when testing interactively.
Code
  f("Species")
Condition
  Error in `Math.factor()`:
  ! ‘log’ not meaningful for factors
──────────────────────────────────────────────────────────────────────────────────
```

Note that snapshots cannot be saved by running the code directly in the console. They are saved and checked in non-interactive settings, e.g. when running `devtools::test()` or `testthat::test_file()`.

Now, we see exactly what the user would see. Maybe you're fine with the current error message, but if you're not then this is the best way to clearly see changes in the message as you refactor the function.

= What about performance?

If you have very large test suites where you check many error messages, you might be worried about the performance implications. After all, `expect_error()` just checks the presence of an error and potentially that a regex is matched, while `expect_snapshot()` needs to save the output and compare it to the content of a file.

`expect_snapshot(error = TRUE)` does take a bit more time than `expect_error()`. In the example below, checking 500 snapshots takes 7 seconds and checking 500 `expect_error()` takes about 3 seconds on my machine.

#html.elem("details")[
  #html.elem("summary")[
    _Click to see a self-contained example to run_
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

Nevertheless, I think the gain in confidence about the user experience is worth this little performance loss in the test suite.


= How to transition to snapshots

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

Note that `flir` is not a formatter, so you will either need to check that the replaced code is properly formatted, or run a code formatter such as #link("https://posit-dev.github.io/air/")[Air].

As an illustration of this workflow, here's a PR in a real package where I made this transition to snapshots: https://github.com/palaeoverse/palaeoverse/pull/173.

= What's next?

This post was purely about improving the checking infrastructure of error messages, but now the hard part is actually fixing or improving error messages displayed in the snapshots! Parts of this could be made easier, e.g. by using one of the many packages for input checking (#link("https://rlang.r-lib.org/index.html")[`rlang`], #link("https://mllg.github.io/checkmate/")[`checkmate`], #link("https://lrberge.github.io/dreamerr/")[`dreamerr`], #link("https://ngreifer.github.io/arg/")[`arg`], etc.), but some parts are very package-specific and require you to explore them.
