document.addEventListener("DOMContentLoaded", function () {
  if (!/\/posts\/.+/.test(location.pathname)) {
    return;
  }

  var script = document.createElement("script");
  script.src = "https://utteranc.es/client.js";
  script.setAttribute("repo", "etiennebacher/my_website");
  script.setAttribute("issue-term", "og:title");
  script.setAttribute("crossorigin", "anonymous");
  script.setAttribute("label", "comment_thread");

  var article = document.querySelector("article");
  if (article) {
    article.appendChild(script);
  }
});
