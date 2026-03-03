# Default task: full build
default: build

build-preview:
    @uv run build.py build
    @uv run build.py preview

# Full build (HTML + PDF + assets). Usage: just build [-f/--force]
build *args:
    @uv run build.py build {{ args }}

# Build only HTML files. Usage: just html [-f/--force]
html *args:
    @uv run build.py html {{ args }}

# Build only PDF files. Usage: just pdf [-f/--force]
pdf *args:
    @uv run build.py pdf {{ args }}

# Only copy static assets
assets:
    @uv run build.py assets

# Clean the generated _site directory
clean:
    @uv run build.py clean

# Start a local preview server (default port 8000). Use 'just preview 3000' for custom port.
preview port="8000":
    @uv run build.py preview --port {{ port }}

# Start preview server without automatically opening the browser
preview-quiet port="8000":
    @uv run build.py preview --port {{ port }} --no-open
