document.addEventListener("DOMContentLoaded", function () {
  var grid = document.querySelector(".gallery-grid");
  if (!grid) return;

  var links = Array.from(grid.querySelectorAll("a"));
  var currentIndex = 0;

  var overlay = document.createElement("div");
  overlay.className = "gallery-lightbox";

  var prev = document.createElement("button");
  prev.className = "gallery-lightbox-arrow gallery-lightbox-prev";
  prev.textContent = "\u2039";

  var next = document.createElement("button");
  next.className = "gallery-lightbox-arrow gallery-lightbox-next";
  next.textContent = "\u203A";

  var img = document.createElement("img");
  overlay.appendChild(prev);
  overlay.appendChild(img);
  overlay.appendChild(next);
  document.body.appendChild(overlay);

  function show(index) {
    currentIndex = (index + links.length) % links.length;
    img.src = links[currentIndex].href;
    overlay.classList.add("active");
  }

  function close() {
    overlay.classList.remove("active");
  }

  grid.addEventListener("click", function (e) {
    var link = e.target.closest("a");
    if (!link) return;
    e.preventDefault();
    show(links.indexOf(link));
  });

  prev.addEventListener("click", function (e) {
    e.stopPropagation();
    show(currentIndex - 1);
  });

  next.addEventListener("click", function (e) {
    e.stopPropagation();
    show(currentIndex + 1);
  });

  overlay.addEventListener("click", function (e) {
    if (e.target === overlay) close();
  });

  document.addEventListener("keydown", function (e) {
    if (!overlay.classList.contains("active")) return;
    if (e.key === "Escape") close();
    if (e.key === "ArrowLeft") show(currentIndex - 1);
    if (e.key === "ArrowRight") show(currentIndex + 1);
  });
});
