"""Port Quarto-rendered posts from the old site to Calepin pages.

The old site's `.typ` files are Pandoc output: ~376 lines of Quarto boilerplate,
then the Tufted template call, then clean Typst body with R output already
baked in. We keep the body (re-running the R would need every package and data
file the posts ever used) and swap the template call for Calepin metadata.
"""

import re
import shutil
from pathlib import Path

SRC = Path("my_website/content/posts")
DST = Path("posts")

BODY_START = 377  # 1-indexed line where `#import "../index.typ"` begins

# Files that are Quarto/knitr build artifacts rather than post assets.
SKIP_DIRS = {".quarto", "__pycache__"}
SKIP_SUFFIXES = (".qmd", ".Rmd", ".rdb", ".rdx", ".RData")


def _fence_scan(lines):
    """Yield (index, line, inside_fence) for each line.

    Fences are tracked by backtick count, not toggled blindly: two posts show
    Rmd/Quarto source inside ````-fences whose bodies contain ``` lines.
    """
    opener = None
    for i, line in enumerate(lines):
        stripped = line.strip()
        if opener is None:
            m = re.match(r"^(`{3,})(\S*)\s*$", stripped)
            if m:
                opener = len(m.group(1))
                yield i, line, True
                continue
            yield i, line, False
        else:
            m = re.match(r"^(`{3,})\s*$", stripped)
            yield i, line, True
            if m and len(m.group(1)) >= opener:
                opener = None


def strip_block_wrappers(body: str) -> str:
    """Drop Pandoc's `#block[...]` wrappers from around fenced code.

    Pandoc wraps every code block (and every executed chunk's output) in a
    `#block[...]`. At the top level Calepin renders a bare fence as a code
    block already, so the wrapper only adds noise and an empty `<div>`.

    Indented wrappers are kept. Calepin rewrites fenced blocks into its own
    code-block element, and that rewrite does not stay inside a list item: an
    indented bare fence ends the list and the code — plus everything after it
    in that item — escapes to the top level. `#block[...]` is what holds it in
    place. Four wrappers in these posts are of that kind.

    A wrapper is only removed when everything it contains is fences, blank
    lines, and further wrappers; anything else and it is left alone.
    """
    lines = body.splitlines()
    marks = list(_fence_scan(lines))

    stack, drop, content = [], set(), {}
    for i, line, in_fence in marks:
        if in_fence:
            for start in stack:
                content[start].append("fence")
            continue
        stripped = line.strip()
        if stripped == "#block[":
            for start in stack:
                content[start].append("block")
            stack.append(i)
            content[i] = []
        elif stripped == "]" and stack:
            start = stack.pop()
            at_top_level = lines[start].startswith("#block[")
            if at_top_level and all(
                kind in ("fence", "block", "") for kind in content[start]
            ):
                drop.add(start)
                drop.add(i)
        elif stack:
            for start in stack:
                content[start].append(stripped and "text" or "")

    if not drop:
        return body

    kept = [line for i, line in enumerate(lines) if i not in drop]

    # Removing the wrappers leaves runs of blank lines behind. Collapse them,
    # but only outside fences, where blank lines are content.
    out = []
    for i, line, in_fence in _fence_scan(kept):
        if not in_fence and not line.strip() and out and not out[-1].strip():
            continue
        out.append(line)
    return "\n".join(out) + "\n"


def parse_header(body: str):
    """Pull title/description/date out of the Tufted `template.with(...)` call."""
    call = re.search(r"#show: template\.with\((.*?)\n\)", body, re.S).group(1)
    title = re.search(r'title:\s*"((?:[^"\\]|\\.)*)"', call).group(1)
    desc = re.search(r'description:\s*"((?:[^"\\]|\\.)*)"', call)
    date = re.search(
        r"date:\s*datetime\(year:\s*(\d+),\s*month:\s*(\d+),\s*day:\s*(\d+)\)", call
    )
    return (
        title,
        desc.group(1) if desc else "",
        "{}-{:02d}-{:02d}".format(*(int(g) for g in date.groups())) if date else "",
    )


def convert(body: str, slug: str) -> str:
    title, description, date = parse_header(body)

    # The listing and the directory name are the canonical date; one post
    # (the Distill gallery one) carries a later date in its template call.
    date = slug[:10]

    # Drop everything up to and including the template call: the Tufted
    # imports, the RSS comment, and the `#show: template.with(...)` block.
    body = body[re.search(r"#show: template\.with\(.*?\n\)\n", body, re.S).end() :]

    # `#title()` renders the H1, so drop Pandoc's duplicate title heading and
    # its anchor label.
    body = re.sub(r"\A\s*=\s[^\n]*\n(<[^>]+>\n)?", "", body)

    # Promote the remaining headings so the top section level lands back on
    # `=`. Quarto emitted the title as `#` in most posts (making sections `##`),
    # but five posts use `#` for their sections too — shifting those blindly
    # would turn `= Section` into a plain text line starting with a space.
    levels = [len(m) for m in re.findall(r"^(=+)(?= )", body, re.M)]
    if levels:
        shift = min(levels) - 1
        if shift:
            body = re.sub(
                r"^(=+)(?= )", lambda m: m.group(1)[shift:], body, flags=re.M
            )

    # The old theme rendered footnotes as margin notes; sidenotes are the
    # Tufte theme's equivalent and work in both HTML and PDF.
    body = body.replace("#footnote[", "#calepin.elements.sidenote[")

    body = strip_block_wrappers(body)

    meta = [f'title: "{title}"', 'kind: "post"', f'date: "{date}"']
    if description:
        meta.append(f'summary: "{description}"')

    head = f"""#import "/.calepin/calepin.typ" as calepin

#set document(title: [{title}])
#metadata((
  {",\n  ".join(meta)},
)) <website-metadata>

// Code blocks in these posts are already-rendered output from the original
// Quarto build, not live chunks. Keep Calepin from executing them.
#calepin.setup(eval: false, fenced-chunks: false)

#title()
"""
    # The blank line matters: without it Typst reads `#title()` and the first
    # paragraph as one paragraph and joins them with a space.
    return head + "\n" + body.lstrip("\n").rstrip() + "\n"


def copy_assets(src_dir: Path, dst_dir: Path) -> int:
    n = 0
    for path in src_dir.rglob("*"):
        rel = path.relative_to(src_dir)
        if not path.is_file() or path.name == "index.typ":
            continue
        if any(part in SKIP_DIRS or part.endswith("_cache") for part in rel.parts):
            continue
        if path.suffix in SKIP_SUFFIXES:
            continue
        target = dst_dir / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, target)
        n += 1
    return n


def main(with_assets: bool = True):
    for src in sorted(SRC.glob("*/index.typ")):
        slug = src.parent.name
        out_dir = DST / slug
        out_dir.mkdir(parents=True, exist_ok=True)

        lines = src.read_text().splitlines(keepends=True)
        (out_dir / "index.typ").write_text(convert("".join(lines[BODY_START - 1 :]), slug))
        n = copy_assets(src.parent, out_dir) if with_assets else 0
        print(f"{slug}: {n} asset(s)")


if __name__ == "__main__":
    main()
