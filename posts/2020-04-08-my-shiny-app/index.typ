#import "/.calepin/calepin.typ" as calepin

#set document(title: [My application for the Shiny Contest (2020)])
#metadata((
  title: "My application for the Shiny Contest (2020)",
  kind: "post",
  date: "2020-04-08",
  summary: "A presentation of the application I submitted to the Shiny Contest 2nd edition.",
)) <website-metadata>

// Code blocks in these posts are already-rendered output from the original
// Quarto build, not live chunks. Keep Calepin from executing them.
#calepin.setup(eval: false, fenced-chunks: false)

#title()

One of the greatest things about R is the possibility to build websites quite easily with R Shiny. I started to create apps with Shiny almost immediately after having discovered it. This was in May last year and two months later I thought it would be a great idea to build an app to treat more easily World Bank data. Indeed, in my field, World Development Indicators (WDI) are often used and I thought it would be useful to have a graphical interface where we can import and treat these indicators.

So in July last year I started to work on this. Besides building something useful, I considered this as a good opportunity to practice with R Shiny. I worked on that irregularly during the rest of the year. Sometimes I considerably improved my app in a week and sometimes I spent two months not thinking about it.

In January, I was quite stuck: my app required to generate pieces of UI (User Interface) on the fly and I didn't know how to do that. But when I saw the #link("https://community.rstudio.com/t/shiny-contest-2020-is-here/51002")[announcement] for the second edition of the Shiny Contest, I convinced myself to give it a try and worked a lot on my app, especially since I finally understood how to use #link("https://shiny.rstudio.com/articles/modules.html")[modules]. Therefore, after a few weeks, I could finally deploy my app and participate to the contest. Given the incredible apps of other participants (just look at the "Shiny Contest" tag on #link("https://community.rstudio.com/")[RStudio Community]), I know that there is not a chance that I win something but nonetheless I am very proud of having the possibility to show what I can do.

"That's very good", you may say, "but what does your app do?". Well if you are familiar with the WDIs, you know that each indicator has an ID (like "NV.AGR.TOTL.ZS"). Using this ID in my app, you can import the dataset related, choose the type of data you want (cross-country, time series, panel data), the country/countries and year(s) you want and compute the logarithm, the squared value and the lagged value of the variable. You may also generate a plot that you can download for this dataset. You can import and manipulate as many datasets as you desire and when you are done, you can merge them in a final dataset that is also downloadable. Finally, since reproducibility is a big aspect in science, all the manipulations you did are translated into R code so that you can copy and paste this code in a fresh R session and it will reproduce everything you have done. This was made possible thanks the great (but still experimental) `shinymeta` package#calepin.elements.sidenote[Luckily, I have discovered this package a month before I launched my app, in a rstudio::conf 2020 #link("https://resources.rstudio.com/rstudio-conf-2020/reproducible-shiny-apps-with-shinymeta-dr-carson-sievert")[presentation by Carson Sievert]].

You can try the app #link("https://etiennebacher.shinyapps.io/woRldbank/")[here], but if it has been removed by the time you go checking it, you may find the source code for the whole app #link("https://github.com/etiennebacher/woRldbank")[on GitHub].
