/*
 * Utterances comment threads. Paired with theme/css/80_utterances.css.
 *
 * The theme bundles every js/ file into every page, so this bails out on
 * anything that is not a single post.
 */
document.addEventListener("DOMContentLoaded", function () {
  // Posts live at /posts/<slug>/; /posts/ itself is the blog listing, which
  // should not get a comment box. Strip the file name so the check works both
  // on the deployed site and under `calepin serve`.
  var path = location.pathname.replace(/index\.html$/, "");
  if (!/^\/posts\/[^/]+\/$/.test(path)) {
    return;
  }

  // The previous site appended to <article>; this theme wraps the post body in
  // <main class="calepin-content"> instead.
  var container = document.querySelector("main.calepin-content");
  if (!container) {
    return;
  }

  function currentTheme() {
    return document.documentElement.dataset.theme === "dark"
      ? "github-dark"
      : "github-light";
  }

  var script = document.createElement("script");
  script.src = "https://utteranc.es/client.js";
  script.setAttribute("repo", "etiennebacher/my_website");
  // The previous site used `og:title`, which was the bare post title there.
  // Calepin appends " | Etienne Bacher" to og:title, so use `title`
  // (document.title), which still holds the bare post title and therefore maps
  // to the same issue titles as before.
  script.setAttribute("issue-term", "title");
  script.setAttribute("crossorigin", "anonymous");
  script.setAttribute("label", "comment_thread");
  script.setAttribute("theme", currentTheme());
  container.appendChild(script);

  // Follow the site's light/dark toggle, which rewrites data-theme on <html>.
  new MutationObserver(function () {
    var frame = document.querySelector(".utterances-frame");
    if (!frame || !frame.contentWindow) {
      return;
    }
    frame.contentWindow.postMessage(
      { type: "set-theme", theme: currentTheme() },
      "https://utteranc.es"
    );
  }).observe(document.documentElement, { attributeFilter: ["data-theme"] });
});
