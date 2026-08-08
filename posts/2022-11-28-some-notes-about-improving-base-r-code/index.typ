#import "/.calepin/calepin.typ" as calepin

#set document(title: [Some notes about improving base R code])
#metadata((
  title: "Some notes about improving base R code",
  kind: "post",
  date: "2022-11-28",
  summary: "A small collection of tips to make base R code faster.",
)) <website-metadata>

// Code blocks in these posts are already-rendered output from the original
// Quarto build, not live chunks. Keep Calepin from executing them.
#calepin.setup(eval: false, fenced-chunks: false)

#title()

Preview image coming from: https:\/\/trainingindustry.com/magazine/nov-dec-2018/life-in-the-fast-lane-accelerated-continuous-development-for-fast-paced-organizations/

Lately I've spent quite some time on packages that require (almost) only base R:

- `datawizard`, a package belonging to the `easystats` ecosystem, whose goal is to provide tools for data wrangling and statistical transformations;
- `poorman`, whose goal is to reproduce `tidyverse` functions (with a strong focus on `dplyr`) using base R only.

I've used `bench::mark()` and `profvis::profvis()` a lot to improve code performance and here are a few things I learnt. By default, `bench::mark()` checks that all expressions return the same output, so we can be confident that the alternatives I show in this post are truly equivalent.

Before we start, I want to precise a few things.

First, these performance improvements are targeted to package developers. A random user shouldn't really care if a function takes 200 milliseconds less to run. However, I think a package developer might find these tips interesting.

Second, if you find some ways to speed up my alternatives, feel free to comment. I know that there are a bunch of packages whose reputation is built on being very fast (for example `data.table` and `collapse`). I'm only showing some base R code alternatives here.

Finally, here's a small function that I use to make a classic dataset (like `iris` or `mtcars`) much bigger.

```r
make_big <- function(data, nrep = 500000) {
  tmp <- vector("list", length = nrep)
  for (i in 1:nrep) {
    tmp[[i]] <- data
  }
  
  data.table::rbindlist(tmp) |> 
    as.data.frame()
}
```

= Check if a vector has a single value
<check-if-a-vector-has-a-single-value>
One easy way to do this is to run `length(unique(x)) == 1`, which basically means that first we have to collect all unique values and then count them. This can be quite inefficient: it would be enough to stop as soon as we find two different values.

What we can do is to compare all values to the first value of the vector. Below is an example with a vector containing 10 million values. In the first case, it only contains `1`, and in the second case it contains `1` and `2`.

```r
# Should be TRUE
test <- rep(1, 1e7)

bench::mark(
  length(unique(test)) == 1,
  all(test == test[1]),
  iterations = 10
)
```

```
Warning: Some expressions had a GC in every iteration; so filtering is
disabled.
```

```
# A tibble: 2 × 6
  expression                     min   median `itr/sec` mem_alloc `gc/sec`
  <bch:expr>                <bch:tm> <bch:tm>     <dbl> <bch:byt>    <dbl>
1 length(unique(test)) == 1  132.8ms  136.5ms      7.21   166.1MB     7.21
2 all(test == test[1])        30.2ms   30.6ms     30.5     38.1MB     9.16
```

```r
# Should be FALSE
test2 <- rep(c(1, 2), 1e7)

bench::mark(
  length(unique(test2)) == 1,
  all(test2 == test2[1]),
  iterations = 10
)
```

```
Warning: Some expressions had a GC in every iteration; so filtering is
disabled.
```

```
# A tibble: 2 × 6
  expression                      min   median `itr/sec` mem_alloc `gc/sec`
  <bch:expr>                 <bch:tm> <bch:tm>     <dbl> <bch:byt>    <dbl>
1 length(unique(test2)) == 1  256.8ms  265.6ms      3.72   332.3MB     3.72
2 all(test2 == test2[1])       44.7ms   46.1ms     19.6     76.3MB     3.91
```

This is also faster for character vectors:

```r
# Should be FALSE
test3 <- rep(c("a", "b"), 1e7)

bench::mark(
  length(unique(test3)) == 1,
  all(test3 == test3[1]),
  iterations = 10
)
```

```
Warning: Some expressions had a GC in every iteration; so filtering is
disabled.
```

```
# A tibble: 2 × 6
  expression                      min   median `itr/sec` mem_alloc `gc/sec`
  <bch:expr>                 <bch:tm> <bch:tm>     <dbl> <bch:byt>    <dbl>
1 length(unique(test3)) == 1  247.4ms  256.3ms      3.71   332.3MB     3.71
2 all(test3 == test3[1])       56.8ms   58.8ms     15.6     76.3MB     3.13
```

= Concatenate columns
<concatenate-columns>
Sometimes we need to concatenate columns, for example if we want to create a unique id from several grouping columns.

```r
test <- data.frame(
  origin = c("A", "B", "C"),
  destination = c("Z", "Y", "X"),
  value = 1:3
)

test <- make_big(test)
```

One option to do this is to combine `paste()` and `apply()` using `MARGIN = 1` to apply `paste()` to each row. However, a faster way to do this is to use `do.call()` instead of `apply()`:

```r
bench::mark(
  apply = apply(test[, c("origin", "destination")], 1, paste, collapse = "_"),
  do.call = do.call(paste, c(test[, c("origin", "destination")], sep = "_"))
)
```

```
Warning: Some expressions had a GC in every iteration; so filtering is
disabled.
```

```
# A tibble: 2 × 6
  expression      min   median `itr/sec` mem_alloc `gc/sec`
  <bch:expr> <bch:tm> <bch:tm>     <dbl> <bch:byt>    <dbl>
1 apply         4.04s    4.04s     0.248    80.1MB     9.41
2 do.call    126.96ms 127.58ms     7.83     11.4MB     0   
```

= Giving attributes to large dataframes
<giving-attributes-to-large-dataframes>
This one comes from these #link("https://stackoverflow.com/questions/74029805/why-does-adding-attributes-to-a-dataframe-take-longer-with-large-dataframes")[StackOverflow question and answer]. Manipulating a dataframe can remove some attributes. For example, if I give an attribute `foo` to a large dataframe:

```r
orig <- data.frame(x1 = rep(1, 1e7), x2 = rep(2, 1e7))
attr(orig, "foo") <- TRUE
attr(orig, "foo")
```

```
[1] TRUE
```

If I reorder the columns, this attribute disappears:

```r
new <- orig[, c(2, 1)]
attr(new, "foo")
```

```
NULL
```

We can put it back with:

```r
attributes(new) <- utils::modifyList(attributes(orig), attributes(new))
attr(new, "foo")
```

```
[1] TRUE
```

But this takes some time because we also copy the 10M row names of the dataset. Therefore, one option is to create a custom function that only copies the attributes that were in `orig` but are not in `new` (in this case, only attribute `foo` is concerned):

```r
replace_attrs <- function(obj, new_attrs) {
  for(nm in setdiff(names(new_attrs), names(attributes(data.frame())))) {
    attr(obj, which = nm) <- new_attrs[[nm]]
  }
  return(obj)
}

bench::mark(
  old = {
    attributes(new) <- utils::modifyList(attributes(orig), attributes(new))
    head(new)
  },
  new = {
    new <- replace_attrs(new, attributes(orig))
    head(new)
  }
)
```

```
# A tibble: 2 × 6
  expression      min   median `itr/sec` mem_alloc `gc/sec`
  <bch:expr> <bch:tm> <bch:tm>     <dbl> <bch:byt>    <dbl>
1 old          32.8ms   41.8ms      24.9    38.2MB     3.12
2 new          43.5µs     47µs   19415.     23.5KB    14.7 
```

= Find empty rows
<find-empty-rows>
It can be useful to remove empty rows, meaning rows containing only `NA` or `""`. We could once again use `apply()` with `MARGIN = 1`, but a faster way is to use `rowSums()`. First, we create a data frame full of `TRUE`/`FALSE` with `is.na(test) | test == ""`, and then we count by row the number of `TRUE`. If this number is equal to the number of columns, then it means that the row only has `NA` or `""`.

```r
test <- data.frame(
  a = c(1, 2, 3, NA, 5),
  b = c("", NA, "", NA, ""),
  c = c(NA, NA, NA, NA, NA),
  d = c(1, NA, 3, NA, 5),
  e = c("", "", "", "", ""),
  f = factor(c("", "", "", "", "")),
  g = factor(c("", NA, "", NA, "")),
  stringsAsFactors = FALSE
)

test <- make_big(test, 100000)

bench::mark(
  apply = which(apply(test, 1, function(i) all(is.na(i) | i == ""))),
  rowSums = which(rowSums((is.na(test) | test == "")) == ncol(test))
)
```

```
Warning: Some expressions had a GC in every iteration; so filtering is
disabled.
```

```
# A tibble: 2 × 6
  expression      min   median `itr/sec` mem_alloc `gc/sec`
  <bch:expr> <bch:tm> <bch:tm>     <dbl> <bch:byt>    <dbl>
1 apply         1.27s    1.27s     0.785   112.9MB     6.28
2 rowSums    282.67ms 287.59ms     3.48     99.7MB     0   
```

= Conclusion
<conclusion>
These were just a few tips I discovered. Maybe there are ways to make them even faster in base R? Or maybe you know some weird/hidden tips? If so, feel free to comment below!
