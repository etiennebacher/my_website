#import "/.calepin/calepin.typ" as calepin

#set document(title: [My favorite shortcuts in RStudio])
#metadata((
  title: "My favorite shortcuts in RStudio",
  kind: "post",
  date: "2020-04-06",
  summary: "Did you know that RStudio contains a lot of shortcuts to write code faster? Here are my favorites.",
)) <website-metadata>

// Code blocks in these posts are already-rendered output from the original
// Quarto build, not live chunks. Keep Calepin from executing them.
#calepin.setup(eval: false, fenced-chunks: false)

#title()

Currently working on my master's thesis, I spend almost half on my day on R (the other half being spent reading articles). I have learnt a few very useful shortcuts by reading blog posts or free R books here and there and I have decided to make a small list of those I use most.

= "Ctrl+Shift+Enter": run the whole script
<ctrlshiftenter-run-the-whole-script>
This combination will run all of your script, wherever the mouse is in the script. This considerably saves some time and is much more convenient than having to drag the mouse up to the "Run" button.

= "Ctrl+Shift+F10": restart R session
<ctrlshiftf10-restart-r-session>
Almost all your work will have to be done again one day, either by you or by somebody else. That day, you will regret not having saved all the packages you needed in your R script. How is that possible? Well, it comes from the fact that I (and presumably other people too) load some packages #emph[and their dependencies] in the same session because we test some packages, or because we are trying to solve a StackOverflow problem during a break, etc. Therefore, when you were writing it, some of your code was running only thanks to some packages you didn't keep in your script.

To prevent this to happen again, you can run "Ctrl+Shift+F10" sometimes: it restarts the R session (but does not close RStudio) and allows to see quickly if your code can run all by itself. When I have finished writing a chunk of code, I always do "Ctrl+Shift+F10" and "Ctrl+Shift+Enter" to make sure that my code can run again in three months or more.

= "Ctrl+Shift+K": knit Markdown documents
<ctrlshiftk-knit-markdown-documents>
I do not use this everywhere but only in Markdown documents: it knits the document. As "Ctrl+Shift+Enter" replaces the "Run" button, "Ctrl+Shift+K" replaces the "Knit" button.

= "Ctrl+Alt+B": run the script from the beginning to where I am
<ctrlaltb-run-the-script-from-the-beginning-to-where-i-am>
This is similar to "Ctrl+Shift+Enter" but it runs the script only until your mouse.

= "Ctrl+Shift+A": good alignment
<ctrlshifta-good-alignment>
Indentation is quite important to have a code that is readable, especially when you begin to write more than 10 lines of code. Select your code (or just a piece of it) and do this combination to apply indentation rules automatically.

= "Ctrl+Shift+R": new section label
<ctrlshiftr-new-section-label>
This creates a new section in your code, with the title you choose. Quite convenient to keep a readable code.

= "Ctrl+Shift+N": new file
<ctrlshiftn-new-file>
If you want to try a chunk of code quickly, you can run this combination to open a new file in RStudio.

= "Ctrl+Shift+C": comment and un-comment lines of code
<ctrlshiftc-comment-and-un-comment-lines-of-code>
To me, this is one of the most convenient shortcut. It simply allows to comment (and un-comment) at once all the lines selected.

The complete list of shortcuts is available in "Tools -\> Keyboard Shortcuts Help" in RStudio. Other useful tools:

- #link("https://rstudio.github.io/rstudio-extensions/rstudio_snippets.html")[snippets]
- #link("https://rstudio.github.io/rstudioaddins/")[addins]
- #link("https://twitter.com/rstudiotips")[RStudio tips] (on Twitter)
