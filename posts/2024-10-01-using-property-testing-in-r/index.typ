#import "/.calepin/calepin.typ" as calepin

#set document(title: [Using property-based testing in R])
#metadata((
  title: "Using property-based testing in R",
  kind: "post",
  date: "2024-10-01",
  summary: "When you don't want to write dozens of versions of unit tests.",
)) <website-metadata>

// Code blocks in these posts are already-rendered output from the original
// Quarto build, not live chunks. Keep Calepin from executing them.
#calepin.setup(eval: false, fenced-chunks: false)

#title()

I had never heard of property-based testing until a few months ago when I started looking at some pull requests in #link("https://github.com/pola-rs/polars/")[polars] (the Python implementation, not the R one) where they use #link("https://hypothesis.readthedocs.io/en/latest/")[hypothesis], for example #link("https://github.com/pola-rs/polars/pull/17992/files#diff-728b25c64b205cf575fb186611d9e63eff7cd1ea2c32cf811a6e68d6e3d0f4bc")[polars\#17992].

I have contributed to a fair amount of R packages but I have never seen this type of tests before: unit tests, plenty; snapshot tests, sometimes; but property-based tests? Never. And at first, I didn't really see the point, but I've had a couple of situations recently where I thought it could help, so the aim of this post is to explain (briefly) what property-based testing is and to provide some examples where it can be useful.

= What is property-based testing?
<what-is-property-based-testing>
Most of the time, unit tests check that the function performs well on a few different inputs: does it give correct results? Nice error messages? What about this corner case?

Property-based testing is a way of testing where we give random inputs to the function we want to test and we want to ensure that no matter the inputs, the output will respect some properties. For example, suppose we made a function to reverse the input, so if I pass `3, 1, 4`, it should return `4, 1, 3`#calepin.elements.sidenote[Example taken from the Rust crate #link("https://github.com/BurntSushi/quickcheck")[`quickcheck`].]. We can pass several inputs and see if the output is correctly reversed. But a more efficient way would be to check that our function respects a basic property, which is that #emph[reversing the input twice should return the original input]:

```r
rev(rev(c(3, 1, 4)))
```

```
[1] 3 1 4
```

Therefore, property-based testing doesn't use hardcoded values to check the output but ensures that our function respects a list of properties.

= Property-based testing in R
<property-based-testing-in-r>
To the best of my knowledge, there are two R packages to do property-based testing in R: #link("https://cran.r-project.org/web/packages/hedgehog/")[`hedgehog`] and #link("https://cran.r-project.org/web/packages/quickcheck/")[`quickcheck`] (which is based on `hedgehog`). If you already use `testthat` for testing, then integrating them in the test suite is not hard. Using the example above, we could do:

```r
library(quickcheck)
library(testthat)

test_that("reversing twice returns the original input", {
  for_all(
    a = numeric_(any_na = TRUE),
    property = function(a) {
      expect_equal(rev(rev(a)), a)
    }
  )
})
```

```
Test passed with 1 success 🎉.
```

This example generated 100 random inputs and checked that the `expect_equal()` clause was respected for all of them. We can see that by adding a `print()` call (I reduce the number of tests to 5 to avoid too much clutter).

```r
test_that("reversing twice returns the original input", {
  for_all(
    a = numeric_(any_na = TRUE),
    tests = 5,
    property = function(a) {
      print(a)
      expect_equal(rev(rev(a)), a)
    }
  )
})
```

```
[1]  180299485         NA  169233443 -556327963  671813836 -172893223  650735145
[8]          0         NA
[1] -7477 -3579    NA
[1] -750718822  762579998  288089702  305956068          0         NA
[1] -153870964 -603204715 -104236120  855887186         NA         NA -156238835
[8]         NA
[1]  -65501381 -577303308         NA          0         NA         NA  243810326
[8]  921447592
Test passed with 1 success 🎉.
```

As we can see, a lot of different examples were generated: some have single values while other have multiple, some only have negative values while others have a mix, etc.

The example above checked only on numeric inputs, but we could check on any type of vector using `any_atomic()`:

```r
test_that("reversing twice returns the original input", {
  for_all(
    a = any_atomic(any_na = TRUE),
    tests = 5,
    property = function(a) {
      print(a)
      expect_equal(rev(rev(a)), a)
    }
  )
})
```

```
[1] "Sz4y$L.V" NA         NA         "-"        "B"       
07:01:15.942289
09:19:36.781132
09:25:10.975813
22:06:55.508066
             NA
             NA
03:28:01.363436
08:08:18.982272
[1] -945034635  561650411  862721611          0
[1] FALSE FALSE FALSE FALSE FALSE FALSE FALSE    NA
[1] -995090807 -500356911          0 -703492650 -551443511          0         NA
Test passed with 1 success 🥇.
```

Finally, if a particular input fails, `quickcheck` will first try to reduce the size of this input as much as possible (a process called "shrinking"). To illustrate that, let's say we make a function to normalize a numeric vector to a \[0, 1\] interval:

```r
normalize <- function(x) {
  (x - min(x)) / (max(x) - min(x))
}

normalize(c(-1, 2, 0, -4))
```

```
[1] 0.5000000 1.0000000 0.6666667 0.0000000
```

One property of this function is that all output values should be in the interval \[0, 1\]. Does this function pass property-based tests?

```r
test_that("output is in interval [0, 1]", {
  for_all(
    a = numeric_(any_na = TRUE),
    tests = 5,
    property = function(a) {
      res <- normalize(a)
      expect_true(all(res >= 0 & res <= 1))
    }
  )
})

── Failure: output is in interval [0, 1] ───────────────────────────────────────
Falsifiable after 1 tests, and 3 shrinks
<expectation_failure/expectation/error/condition>
all(res >= 0 & res <= 1) is not TRUE

`actual`:   <NA>
`expected`: TRUE
Backtrace:
     ▆
  1. └─quickcheck::for_all(...)
      [TRUNCATED...]
Counterexample:
$a
[1] -4037

Backtrace:
    ▆
 1. └─quickcheck::for_all(...)
 2.   └─hedgehog::forall(...)
```

Hah-ah! Problem: what happens if the input is a single value? Then `max(x) - min(x)` is 0, so the division gives `NaN`. In the error message, we can see:

#quote(block: true)[
Falsifiable after 1 tests, #strong[and 3 shrinks]
]

Shrinking is the action of reducing as much as possible the size of the input that makes the function fail. Having the smallest example possible is extremely useful when debugging.

Let's fix the function and try again:

```r
normalize <- function(x) {
  if (length(x) == 1) {
    return(0.5) # WARNING: this is for the sake of example, I don't 
                # guarantee this is the correct behavior
  }
  (x - min(x)) / (max(x) - min(x))
}

test_that("output is in interval [0, 1]", {
  for_all(
    a = numeric_(any_na = TRUE),
    tests = 5,
    property = function(a) {
      res <- normalize(a)
      expect_true(all(res >= 0 & res <= 1))
    }
  )
})

── Failure: output is in interval [0, 1] ───────────────────────────────────────
Falsifiable after 1 tests, and 8 shrinks
<expectation_failure/expectation/error/condition>
all(res >= 0 & res <= 1) is not TRUE

`actual`:   <NA>
`expected`: TRUE
Backtrace:
     ▆
  1. └─quickcheck::for_all(...)
     [TRUNCATED...]
Counterexample:
$a
[1] -2413 -2413

Backtrace:
    ▆
 1. └─quickcheck::for_all(...)
 2.   └─hedgehog::forall(...)
```

Dang it, now it fails when I pass a two identical values! This is for the same reason as above, `max(x) - min(x)` will return 0, but I won't spend more time on this example, you get the idea.

Besides this basic example, where could this be useful?

= Ensuring that a package doesn't crash R
<ensuring-that-a-package-doesnt-crash-r>
When working with compiled code (C++, Rust, etc.), it can happen that a bug makes the R session crash (== segfault == "bomb icon" in RStudio). This can be extremely annoying as we lose all data and computations that were stored in memory. When we work with compiled code, there's one property that our code should follow:

#quote(block: true)[
Calling a function should never lead to a segfault.
]

This happened to me a few months ago. I investigated some code that used `igraph::cluster_fast_greedy()`. I know almost nothing about `igraph`, I was just playing around with arguments, and suddenly… crash. I reported this situation (#link("https://github.com/igraph/igraph/issues/2459")[igraph\#2459]), which was promptly fixed (thank you `igraph` devs!), but one sentence in the explanation caught my eye: "it is a rare use case to only want modularity but not membership, and avoiding membership calculation doesn't have any advantages."

I have no particular problem with this sentence or the rationale behind, it makes sense to prioritize fixes that affect a larger audience. But it got me thinking: could we try all combinations of inputs to see if it makes the session crash? We could use #link("https://cran.r-project.org/web/packages/patrick/")[parametric testing] for this, but then again we need to hardcode at least some possible values for parameters. We could say that we start by testing only `TRUE`/`FALSE` values for all combinations of params, but what if the user passes a string?

I think this is a situation where property-based testing would be helpful: we know that no matter the input type, its length, and the value of other inputs, #emph[the session shouldn't crash]. Implementing it with `quickcheck` looks fairly simple:

```r
library(igraph, warn.conflicts = FALSE)

test_that("cluster_fast_greedy doesn't crash", {
  # setup a graph, from the examples of ?cluster_fast_greedy
  g <- make_full_graph(5) %du% make_full_graph(5) %du% make_full_graph(5)
  g <- add_edges(g, c(1, 6, 1, 11, 6, 11))

  for_all(
    merges = any_atomic(any_na = TRUE), 
    modularity = any_atomic(any_na = TRUE), 
    membership = any_atomic(any_na = TRUE), 
    weights = any_atomic(any_na = TRUE),
    property = function(merges, modularity, membership, weights) {
      suppressWarnings(
        try(
          cluster_fast_greedy(g, merges = merges, modularity = modularity, membership = membership, weights = weights),
          silent = TRUE
        )
      )
      expect_true(TRUE)
    }
  )
})
```

```
Test passed with 1 success 😀.
```

I didn't really know what expectation to put, I don't care if the function errors or not, I just want it not to segfault. So I put `try(silent = TRUE)` and added a fake expectation.

= Ensuring that a package and its variants give the same results
<ensuring-that-a-package-and-its-variants-give-the-same-results>
I have spent some time working on #link("https://www.tidypolars.etiennebacher.com/")[`tidypolars`], a package that provides the same interface as the `tidyverse` but uses `polars` under the hood. This means that there should be the lowest amount of "surprises" for the user: the behavior of functions that are available in `tidypolars` should match the behavior of those in `tidyverse`. Once again this can be tedious to check. One example is the function `stringr::str_sub()`. For instance, we can start with basic examples, such as:

```r
stringr::str_sub(string = "foo", start = 1, end = 2)
```

```
[1] "fo"
```

Easy enough to test. But what happens if `string` is missing? Or if `start > end`? Or if `end` is negative? Or if `start` is negative #emph[and] `end` is `NULL` #emph[and] the length of `start` is greater than the length of `string`? Manually adding tests for all of those is painful and increases the risk of forgetting a corner case.

It is better here to use property-based testing: we don't need to check the value of the output of functions implemented in `tidypolars`, #emph[we only need to check that they match the output of functions in `tidyverse`].

Here, one additional difficulty is that sometimes throwing an error is the correct behavior. Therefore, we need to create a custom expectation that checks that the output of `tidypolars` and `tidyverse` is identical, #emph[or] that both functions error (see the `testthat` vignette on #link("https://testthat.r-lib.org/articles/custom-expectation.html")[creating custom expectations]):

```r
expect_equal_or_both_error <- function(object, other) {
  polars_error <- FALSE
  polars_res <- tryCatch(
    object,
    error = function(e) polars_error <<- TRUE
  )

  other_error <- FALSE
  other_res <- suppressWarnings(
    tryCatch(
      other,
      error = function(e) other_error <<- TRUE
    )
  )

  if (isTRUE(polars_error)) {
    testthat::expect(isTRUE(other_error), "tidypolars errored but tidyverse didn't.")
  } else {
    testthat::expect_equal(polars_res, other_res)
  }

  invisible(NULL)
}
```

= Conclusion
<conclusion>
Property-based testing will not replace all kinds of tests, and is not necessarily appropriate in all contexts. Still, it can help uncover bugs, segfaults, and it adds more confidence in our code by randomly checking that it works even with implausible inputs.
