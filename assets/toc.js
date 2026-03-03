document.addEventListener('DOMContentLoaded', function () {
    // Only show TOC on blog posts (and not on the "Blog" page)
    if (!window.location.pathname.startsWith('/posts/') || window.location.pathname.endsWith('/posts/')) return;

    const headings = document.querySelectorAll('article > section h2, article > section h3');

    if (headings.length < 2) return;

    // Ensure every heading has an id
    headings.forEach(function (h) {
        if (!h.id) {
            h.id = h.textContent.trim()
                .toLowerCase()
                .replace(/[^a-z0-9]+/g, '-')
                .replace(/^-|-$/g, '');
        }
    });

    // Build nav
    const nav = document.createElement('nav');
    nav.className = 'toc-sidebar';
    const ul = document.createElement('ul');

    headings.forEach(function (h) {
        const li = document.createElement('li');
        if (h.tagName === 'H3') {
            li.classList.add('toc-h3');
        }
        const a = document.createElement('a');
        a.href = '#' + h.id;
        a.textContent = h.textContent;
        li.appendChild(a);
        ul.appendChild(li);
    });

    nav.appendChild(ul);

    const article = document.querySelector('article');
    if (article) {
        article.parentNode.insertBefore(nav, article);
    } else {
        document.body.prepend(nav);
    }

    // Align TOC top with the blog post title (first h2 in article)
    const title = document.querySelector('article > section > h2');
    if (title) {
        var titleTop = title.getBoundingClientRect().top;
        nav.style.top = titleTop + 'px';
        nav.style.maxHeight = 'calc(100vh - ' + titleTop + 'px - 1rem)';
    }

    // Smooth scroll on click
    nav.addEventListener('click', function (e) {
        if (e.target.tagName === 'A') {
            e.preventDefault();
            const target = document.querySelector(e.target.getAttribute('href'));
            if (target) {
                target.scrollIntoView({ behavior: 'smooth' });
                history.replaceState(null, '', e.target.getAttribute('href'));
            }
        }
    });

    // Scroll spy with IntersectionObserver
    const links = nav.querySelectorAll('a');
    const headingMap = new Map();
    links.forEach(function (link) {
        headingMap.set(link.getAttribute('href').slice(1), link);
    });

    let currentActive = null;

    const observer = new IntersectionObserver(function (entries) {
        entries.forEach(function (entry) {
            if (entry.isIntersecting) {
                if (currentActive) currentActive.classList.remove('active');
                const link = headingMap.get(entry.target.id);
                if (link) {
                    link.classList.add('active');
                    currentActive = link;
                }
            }
        });
    }, {
        rootMargin: '0px 0px -70% 0px',
        threshold: 0
    });

    headings.forEach(function (h) {
        observer.observe(h);
    });
});
