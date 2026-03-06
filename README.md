This is my website, made with [Tufted-Blog-Template](https://github.com/Yousa-Mirage/Tufted-Blog-Template).

## Setup

- [Typst](https://typst.app/)
- [Quarto](https://quarto.org/)
- Python (using [uv](https://docs.astral.sh/uv/) is recommended)
- [just](https://github.com/casey/just)

## Commands

- `just clean` to delete the `_site` folder
- `just build-preview` to build and open a preview of the site
- `quarto render path/to/file.qmd --to typst` to render a `.qmd` file to a `.typ` file. See files in `content/posts` for an example of the YAML to be used. Note that Quarto will also try to render the `.typ` file to `.pdf` but will fail because of wrong paths. This is not important, we just need Quarto for `.qmd` to `.typ`.

(see the `justfile` for other commands)
