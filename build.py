#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.10"
# ///

"""
Tufted Blog Template Build Script

A cross-platform build script that compiles Typst (.typ) files into HTML and PDF,
and copies static assets to the output directory.

Supports incremental compilation: only recompiles modified files to speed up builds.

Usage:
    uv run build.py build       # Full build (HTML + PDF + assets)
    uv run build.py html        # Build HTML files only
    uv run build.py pdf         # Build PDF files only
    uv run build.py assets      # Copy static assets only
    uv run build.py clean       # Clean generated files
    uv run build.py preview     # Start local preview server (default port 8000)
    uv run build.py preview -p 3000  # Use a custom port
    uv run build.py --help      # Show help information

Incremental compilation options:
    --force, -f                 # Force full rebuild, ignore incremental checks

Preview server options:
    --port, -p PORT             # Specify server port (default: 8000)

Can also be run directly with Python:
    python build.py build
    python build.py build --force
    python build.py preview -p 3000
"""

import argparse
import concurrent.futures
import os
import re
import shutil
import subprocess
import sys
import threading
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from html.parser import HTMLParser
from pathlib import Path
from typing import Literal

# ============================================================================
# Configuration
# ============================================================================

CONTENT_DIR = Path("content")  # Source file directory
SITE_DIR = Path("_site")  # Output directory
ASSETS_DIR = Path("assets")  # Static assets directory
CONFIG_FILE = Path("config.typ")  # Global configuration file


@dataclass
class BuildStats:
    """Build statistics"""

    success: int = 0
    skipped: int = 0
    failed: int = 0

    def format_summary(self) -> str:
        """Format statistics summary"""
        parts = []
        if self.success > 0:
            parts.append(f"compiled: {self.success}")
        if self.skipped > 0:
            parts.append(f"skipped: {self.skipped}")
        if self.failed > 0:
            parts.append(f"failed: {self.failed}")
        return ", ".join(parts) if parts else "no files to process"

    @property
    def has_failures(self) -> bool:
        """Whether there are any failures"""
        return self.failed > 0


class HTMLMetadataParser(HTMLParser):
    """
    Parser for extracting metadata from HTML files.

    Parses the following metadata:
    - lang: from the <html lang="..."> attribute
    - title: from the <title> tag
    - description: from <meta name="description" content="...">
    - link: from <link rel="canonical" href="...">
    - date: from <meta name="date" content="...">
    """

    def __init__(self):
        super().__init__()
        self.metadata = {"title": ""}
        self._in_title = False

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]):
        attrs_dict = {k: v for k, v in attrs if v}

        match tag:
            case "html":
                self.metadata["lang"] = attrs_dict.get("lang", "")
            case "title":
                self._in_title = True
            case "meta":
                name = attrs_dict.get("name", "")
                if name in {"description", "date"}:
                    self.metadata[name] = attrs_dict.get("content", "")
            case "link":
                if attrs_dict.get("rel") == "canonical":
                    self.metadata["link"] = attrs_dict.get("href", "")

    def handle_endtag(self, tag: str):
        if tag == "title":
            self._in_title = False

    def handle_data(self, data: str):
        if self._in_title:
            self.metadata["title"] += data


# ============================================================================
# Incremental compilation helpers
# ============================================================================


def get_file_mtime(path: Path) -> float:
    """
    Get the modification timestamp of a file.

    Args:
        path: File path

    Returns:
        float: Modification timestamp, returns 0 if the file doesn't exist
    """
    try:
        return path.stat().st_mtime
    except (OSError, FileNotFoundError):
        return 0.0


def is_dep_file(path: Path) -> bool:
    """
    Determine whether a file is tracked as a dependency.

    Regular page files under content/ are not considered dependency files,
    since they are independent pages and should not depend on each other.

    Args:
        path: File path

    Returns:
        bool: Whether the file is a dependency
    """
    try:
        resolved_path = path.resolve()
        project_root = Path(__file__).parent.resolve()
        content_dir = (project_root / CONTENT_DIR).resolve()

        # config.typ is a dependency file
        if resolved_path == (project_root / CONFIG_FILE).resolve():
            return True

        # Check if it's under the content/ directory
        try:
            relative_to_content = resolved_path.relative_to(content_dir)
            # Files under content/_* directories are treated as dependencies
            parts = relative_to_content.parts
            if len(parts) > 0 and parts[0].startswith("_"):
                return True
            # Other files under content/ are not dependencies
            return False
        except ValueError:
            # Not under content/, treat as dependency (e.g., config.typ)
            return True

    except Exception:
        return True


def find_typ_dependencies(typ_file: Path) -> set[Path]:
    """
    Parse dependencies in a .typ file (files imported via #import and #include).

    Only tracks .typ file dependencies, ignoring regular page files under content/.
    Other resource files (e.g., .md, .bib, images) are handled by copy_content_assets.

    Args:
        typ_file: Path to the .typ file

    Returns:
        set[Path]: Set of dependent .typ file paths
    """
    dependencies: set[Path] = set()

    try:
        content = typ_file.read_text(encoding="utf-8")
    except Exception:
        return dependencies

    # Get the file's directory for resolving relative paths
    base_dir = typ_file.parent

    patterns = [
        r'#import\s+"([^"]+)"',
        r"#import\s+'([^']+)'",
        r'#include\s+"([^"]+)"',
        r"#include\s+'([^']+)'",
    ]

    for pattern in patterns:
        for match in re.finditer(pattern, content):
            dep_path_str = match.group(1)

            # Skip package imports (e.g., @preview/xxx)
            if dep_path_str.startswith("@"):
                continue

            # Resolve relative paths
            if dep_path_str.startswith("/"):
                # Path relative to project root
                dep_path = Path(dep_path_str.lstrip("/"))
            else:
                # Path relative to current file
                dep_path = base_dir / dep_path_str

            # Normalize path, only track .typ files
            try:
                dep_path = dep_path.resolve()
                if dep_path.exists() and dep_path.suffix == ".typ" and is_dep_file(dep_path):
                    dependencies.add(dep_path)
            except Exception:
                pass

    return dependencies


def get_all_dependencies(typ_file: Path, visited: set[Path] | None = None) -> set[Path]:
    """
    Recursively get all dependencies of a .typ file (including transitive dependencies).

    Args:
        typ_file: Path to the .typ file
        visited: Set of already visited files (to avoid circular dependencies)

    Returns:
        set[Path]: Set of all dependency file paths
    """
    if visited is None:
        visited = set()

    # Avoid circular dependencies
    abs_path = typ_file.resolve()
    if abs_path in visited:
        return set()
    visited.add(abs_path)

    all_deps: set[Path] = set()
    direct_deps = find_typ_dependencies(typ_file)

    for dep in direct_deps:
        all_deps.add(dep)
        # Only recursively find dependencies for .typ files
        if dep.suffix == ".typ":
            all_deps.update(get_all_dependencies(dep, visited))

    return all_deps


def needs_rebuild(source: Path, target: Path, extra_deps: list[Path] | None = None) -> bool:
    """
    Determine whether a rebuild is needed.

    A rebuild is needed when any of the following conditions are met:
    1. The target file doesn't exist
    2. The source file is newer than the target file
    3. Any extra dependency file is newer than the target file
    4. Any import dependency of the source file is newer than the target file
    5. Any non-.typ file in the same directory as the source is newer than the target (e.g., .md, .bib, images)

    Args:
        source: Source file path
        target: Target file path
        extra_deps: List of additional dependency files (e.g., config.typ)

    Returns:
        bool: Whether a rebuild is needed
    """
    # Target doesn't exist, need to build
    if not target.exists():
        return True

    target_mtime = get_file_mtime(target)

    # Source file was updated
    if get_file_mtime(source) > target_mtime:
        return True

    # Check extra dependencies
    if extra_deps:
        for dep in extra_deps:
            if dep.exists() and get_file_mtime(dep) > target_mtime:
                return True

    # Check import dependencies of the source file
    for dep in get_all_dependencies(source):
        if get_file_mtime(dep) > target_mtime:
            return True

    # Check non-.typ resource files in the same directory (e.g., .md, .bib, images)
    # Only check the same directory, not subdirectories, to avoid excessive recompilation
    source_dir = source.parent
    for item in source_dir.iterdir():
        if item.is_file() and item.suffix != ".typ":
            if get_file_mtime(item) > target_mtime:
                return True

    return False


def find_common_dependencies() -> list[Path]:
    """
    Find common dependencies for all files (e.g., config.typ).

    Returns:
        list[Path]: List of common dependency file paths
    """
    common_deps = []

    # config.typ is a global config — all pages need rebuilding when it changes
    if CONFIG_FILE.exists():
        common_deps.append(CONFIG_FILE)

    # Additional common dependencies can be added here
    # For example: find template files under content/_* directories
    if CONTENT_DIR.exists():
        for item in CONTENT_DIR.iterdir():
            if item.is_dir() and item.name.startswith("_"):
                for typ_file in item.rglob("*.typ"):
                    common_deps.append(typ_file)

    return common_deps


# ============================================================================
# Helper functions
# ============================================================================


def find_typ_files() -> list[Path]:
    """
    Find all .typ files under the content/ directory, excluding files in directories
    whose names start with an underscore or a dot (e.g. .quarto/).

    Returns:
        list[Path]: List of .typ file paths
    """
    typ_files = []
    for typ_file in CONTENT_DIR.rglob("*.typ"):
        # Check if any directory in the path starts with an underscore or dot
        parts = typ_file.relative_to(CONTENT_DIR).parts
        if not any(part.startswith("_") or part.startswith(".") for part in parts):
            typ_files.append(typ_file)
    return typ_files


def get_file_output_path(typ_file: Path, type: Literal["pdf", "html"]) -> Path:
    """
    Get the output path for a .typ file.

    Args:
        typ_file: .typ file path (relative to content/)

    Returns:
        Path: File output path (under the _site/ directory)
    """
    relative_path = typ_file.relative_to(CONTENT_DIR)
    return SITE_DIR / relative_path.with_suffix(f".{type}")


def run_typst_command(args: list[str]) -> bool:
    """
    Run a typst command.

    Args:
        args: List of typst command arguments

    Returns:
        bool: Whether the command executed successfully
    """
    try:
        result = subprocess.run(["typst"] + args, capture_output=True, text=True, encoding="utf-8")
        if result.returncode != 0:
            print(f"  Typst error: {result.stderr.strip()}")
            return False
        return True
    except FileNotFoundError:
        print("  Error: typst command not found. Please ensure Typst is installed and added to PATH.")
        print("  Installation guide: https://typst.app/open-source/#download")
        return False
    except Exception as e:
        print(f"  Error running typst command: {e}")
        return False


# ============================================================================
# Build commands
# ============================================================================


def _compile_files(
    files: list[Path],
    force: bool,
    common_deps: list[Path],
    get_output_path_func,
    build_args_func,
) -> BuildStats:
    """
    Generic file compilation function to reduce code duplication.

    Args:
        files: List of files to compile
        force: Whether to force rebuild
        common_deps: List of common dependencies
        get_output_path_func: Function to get output path
        build_args_func: Function to build compilation arguments

    Returns:
        BuildStats: Build statistics
    """
    stats = BuildStats()

    # Separate files that need rebuilding from those that can be skipped
    to_compile: list[tuple[Path, list[str]]] = []
    for typ_file in files:
        output_path = get_output_path_func(typ_file)

        if not force and not needs_rebuild(typ_file, output_path, common_deps):
            stats.skipped += 1
            continue

        output_path.parent.mkdir(parents=True, exist_ok=True)
        args = build_args_func(typ_file, output_path)
        to_compile.append((typ_file, args))

    # Compile in parallel
    def _compile_one(item: tuple[Path, list[str]]) -> tuple[Path, bool]:
        typ_file, args = item
        return typ_file, run_typst_command(args)

    if to_compile:
        with concurrent.futures.ThreadPoolExecutor() as executor:
            for typ_file, ok in executor.map(_compile_one, to_compile):
                if ok:
                    stats.success += 1
                else:
                    print(f"  {typ_file} compilation failed")
                    stats.failed += 1

    return stats


def build_html(force: bool = False) -> bool:
    """
    Compile all .typ files to HTML (excluding files with PDF in the name).

    Args:
        force: Whether to force rebuild all files
    """
    SITE_DIR.mkdir(parents=True, exist_ok=True)

    typ_files = find_typ_files()

    # Exclude files marked as PDF
    html_files = [f for f in typ_files if "pdf" not in f.stem.lower()]

    if not html_files:
        print("  No HTML files found.")
        return True

    print("Building HTML files...")

    # Get common dependencies
    common_deps = find_common_dependencies()

    def build_html_args(typ_file: Path, output_path: Path) -> list[str]:
        """Build HTML compilation arguments"""
        try:
            rel_path = typ_file.relative_to(CONTENT_DIR)

            if rel_path.name == "index.typ":
                # index.typ uses the parent directory name as the path
                # content/Blog/index.typ -> "Blog"
                # content/index.typ -> "" (Homepage)
                page_path = rel_path.parent.as_posix()
                if page_path == ".":
                    page_path = ""
            else:
                # Common files use the filename as the path
                # content/about.typ -> "about"
                page_path = rel_path.with_suffix("").as_posix()
        except ValueError:
            page_path = ""

        return [
            "compile",
            "--root",
            ".",
            "--font-path",
            str(ASSETS_DIR),
            "--features",
            "html",
            "--format",
            "html",
            "--input",
            f"page-path={page_path}",
            str(typ_file),
            str(output_path),
        ]

    stats = _compile_files(
        html_files,
        force,
        common_deps,
        lambda typ_file: get_file_output_path(typ_file, "html"),
        build_html_args,
    )

    print(f"HTML build complete. {stats.format_summary()}")
    return not stats.has_failures


def build_pdf(force: bool = False) -> bool:
    """
    Compile .typ files with "PDF" in their filename to PDF.

    Args:
        force: Whether to force rebuild all files
    """
    SITE_DIR.mkdir(parents=True, exist_ok=True)

    typ_files = find_typ_files()
    pdf_files = [f for f in typ_files if "pdf" in f.stem.lower()]

    if not pdf_files:
        return True

    print("Building PDF files...")

    # Get common dependencies
    common_deps = find_common_dependencies()

    def build_pdf_args(typ_file: Path, output_path: Path) -> list[str]:
        """Build PDF compilation arguments"""
        return [
            "compile",
            "--root",
            ".",
            "--font-path",
            str(ASSETS_DIR),
            str(typ_file),
            str(output_path),
        ]

    stats = _compile_files(
        pdf_files,
        force,
        common_deps,
        lambda typ_file: get_file_output_path(typ_file, "pdf"),
        build_pdf_args,
    )

    print(f"PDF build complete. {stats.format_summary()}")
    return not stats.has_failures


def copy_assets() -> bool:
    """
    Copy static assets to the output directory.
    """
    if not ASSETS_DIR.exists():
        print(f"  Assets directory {ASSETS_DIR} does not exist.")
        return True

    SITE_DIR.mkdir(parents=True, exist_ok=True)
    target_dir = SITE_DIR / "assets"

    try:
        if target_dir.exists():
            shutil.rmtree(target_dir)
        shutil.copytree(ASSETS_DIR, target_dir)
        return True
    except Exception as e:
        print(f"  Failed to copy static assets: {e}")
        return False


def copy_content_assets(force: bool = False) -> bool:
    """
    Copy non-.typ files (e.g., images) from the content directory to the output directory.
    Supports incremental copying: only copies modified files.

    Args:
        force: Whether to force copy all files
    """
    SITE_DIR.mkdir(parents=True, exist_ok=True)

    if not CONTENT_DIR.exists():
        print(f"  Content directory {CONTENT_DIR} does not exist, skipping.")
        return True

    try:
        copy_count = 0
        skip_count = 0

        for item in CONTENT_DIR.rglob("*"):
            # Skip directories and .typ files
            if item.is_dir() or item.suffix == ".typ":
                continue

            # Skip paths starting with an underscore or dot
            relative_path = item.relative_to(CONTENT_DIR)
            if any(part.startswith("_") or part.startswith(".") for part in relative_path.parts):
                continue

            # Calculate target path
            target_path = SITE_DIR / relative_path

            # Incremental copy check
            if not force and target_path.exists():
                if get_file_mtime(item) <= get_file_mtime(target_path):
                    skip_count += 1
                    continue

            # Create target directory
            target_path.parent.mkdir(parents=True, exist_ok=True)

            # Copy file
            shutil.copy2(item, target_path)
            copy_count += 1

        return True
    except Exception as e:
        print(f"  Failed to copy content assets: {e}")
        return False


def clean() -> bool:
    """
    Clean generated files.
    """
    print("Cleaning generated files...")

    if not SITE_DIR.exists():
        print(f"  Output directory {SITE_DIR} does not exist, nothing to clean.")
        return True

    try:
        # Delete all contents under the _site directory
        for item in SITE_DIR.iterdir():
            if item.is_dir():
                shutil.rmtree(item)
            else:
                item.unlink()

        print(f"  Cleaned {SITE_DIR}/ directory.")
        return True
    except Exception as e:
        print(f"  Clean failed: {e}")
        return False


def preview(port: int = 8000, open_browser_flag: bool = True) -> bool:
    """
    Start a local preview server.

    First tries uvx livereload (supports live reload),
    falls back to Python's built-in http.server if that fails.

    Args:
        port: Server port number, default is 8000
        open_browser_flag: Whether to automatically open the browser, default is True
    """
    import webbrowser

    if not SITE_DIR.exists():
        print(f"  Output directory {SITE_DIR} does not exist. Please run the build command first.")
        return False

    print("Starting local preview server (press Ctrl+C to stop)...")
    print()

    if open_browser_flag:

        def open_browser():
            time.sleep(1.5)  # Wait for server to start
            url = f"http://localhost:{port}"
            print(f"  Opening browser: {url}")
            webbrowser.open(url)

        # Open browser in a background thread
        threading.Thread(target=open_browser, daemon=True).start()

    # First try uvx livereload
    try:
        result = subprocess.run(
            ["uvx", "livereload", str(SITE_DIR), "-p", str(port)],
            check=False,
        )
        return result.returncode == 0
    except FileNotFoundError:
        print("  uv not found, trying Python http.server...")
    except KeyboardInterrupt:
        print("\nServer stopped.")
        return True

    # Fall back to Python http.server
    try:
        print("Using Python built-in http.server...")
        result = subprocess.run(
            [sys.executable, "-m", "http.server", str(port), "--directory", str(SITE_DIR)],
            check=False,
        )
        return result.returncode == 0
    except KeyboardInterrupt:
        print("\nServer stopped.")
        return True
    except Exception as e:
        print(f"  Failed to start server: {e}")
        return False


def parse_html_metadata(html_path: Path) -> dict[str, str]:
    """
    Parse an HTML file and return metadata.

    Args:
        html_path (Path): Path to the HTML file

    Returns:
        dict[str, str]: Dictionary containing parsed metadata
    """
    parser = HTMLMetadataParser()
    parser.feed(html_path.read_text(encoding="utf-8"))
    return parser.metadata


def get_site_url() -> str | None:
    """
    Parse the site URL from the generated homepage HTML file.

    Extracts site-url from the <link rel="canonical" href="..."> in _site/index.html.

    Returns:
        str: The site's root URL (e.g., "https://example.com"), without trailing slash.
            Returns None if not configured or parsing fails.
    """
    index_html = SITE_DIR / "index.html"
    parser = parse_html_metadata(index_html)

    if parser.get("link"):
        return parser["link"].rstrip("/")

    return None


def get_feed_dirs() -> set[str]:
    """
    Parse RSS feed configuration from the config.typ file.

    Parses the feed configuration block in config.typ to extract directory list.

    Returns:
        set[str]: Set of article directories to include, defaults to empty set
    """
    if not CONFIG_FILE.exists():
        return set()

    try:
        content = CONFIG_FILE.read_text(encoding="utf-8")

        # Remove comments
        content = re.sub(r"//.*", "", content)
        content = re.sub(r"/\*[\s\S]*?\*/", "", content)

        match = re.search(r"feed-dir\s*:\s*\((.*?)\)", content, re.DOTALL)
        if match:
            return set(
                c.strip("/") for c in re.findall(r'"([^"]*)"', match.group(1)) if c and c.strip("/")
            )
    except Exception as e:
        print(f"Failed to parse feed-dir: {e}")

    return set()


def extract_post_metadata(index_html: Path) -> tuple[str, str, str, datetime | None]:
    """
    Extract article metadata from the generated HTML file.

    Extracts:
    1. title: from the <title> tag
    2. description: from <meta name="description">
    3. link: from <link rel="canonical" href="...">
    4. date: tries in order:
        - <meta name="date" content="..."> in the HTML
        - YYYY-MM-DD format date in the folder name

    Args:
        index_html (Path): Path to the article's index.html file

    Returns:
        tuple[str, str, str, datetime | None]: A tuple containing:
            - str: Article title
            - str: Article description (may be empty)
            - str: Article link (full URL)
            - datetime | None: Article date (with UTC timezone), None if unavailable
    """
    parser = parse_html_metadata(index_html)

    title = parser["title"].strip()
    description = parser.get("description", "").strip()
    link = parser.get("link", "")
    date_obj = None

    # Try to parse date from <meta name="date">
    if parser.get("date"):
        try:
            date_obj = datetime.strptime(parser["date"].split("T")[0], "%Y-%m-%d")
            date_obj = date_obj.replace(tzinfo=timezone.utc)
        except Exception:
            pass

    # If no date found, try to extract from folder name (YYYY-MM-DD)
    if not date_obj:
        date_match = re.search(r"(\d{4}-\d{2}-\d{2})", index_html.parent.name)
        if date_match:
            try:
                date_obj = datetime.strptime(date_match.group(1), "%Y-%m-%d")
                date_obj = date_obj.replace(tzinfo=timezone.utc)
            except ValueError:
                pass

    return title, description, link, date_obj


def collect_posts(dirs: set[str], site_url: str) -> list[dict]:
    """
    Collect metadata for all articles from the specified directories.

    Traverses subdirectories under _site for the specified directories, extracting
    metadata for each article. Only processes directories (each representing an article),
    skipping regular files. Articles without a determinable date are skipped with a warning.

    Args:
        dirs (set[str]): Set of directory names to scan (e.g., {"Blog", "Docs"})
        site_url (str): The site's root URL (e.g., "https://example.com")

    Returns:
        list[dict]: List of article data dictionaries, each containing:
            - title (str): Article title
            - description (str): Article description
            - dir (str): Article category (directory name)
            - link (str): Full article URL
            - date (datetime): Article date (with timezone)
    """
    posts = []

    for d in dirs:
        dir_path = SITE_DIR / d

        for item in dir_path.iterdir():
            if not item.is_dir():
                continue

            index_html = item / "index.html"
            if not index_html.exists():
                continue

            title, description, link, date_obj = extract_post_metadata(index_html)

            if not date_obj:
                print(f"Could not determine date for article '{item.name}', skipping.")
                continue

            posts.append(
                {
                    "title": title,
                    "description": description,
                    "dir": d,
                    "link": link,
                    "date": date_obj,
                }
            )

    return posts


def build_rss_xml(posts: list[dict], config: dict) -> str:
    """
    Build an RSS 2.0 compliant XML content string.

    Uses Python's standard library xml.etree.ElementTree to generate a complete RSS Feed XML
    from article data and site configuration. Supports conditional description tags
    (only output when a description exists).

    Args:
        posts (list[dict]): List of article data, each dict should contain:
            - title: Title
            - description: Description (optional)
            - link: Article link
            - date: datetime object
            - dir: Category name (path name)
        config (dict): Site configuration dictionary, should contain:
            - site_url: Site root URL
            - site_title: Site title
            - site_description: Site description
            - lang: Language code (e.g., "zh", "en")

    Returns:
        str: Complete RSS 2.0 XML string, including XML declaration and all necessary namespaces.
    """
    import xml.etree.ElementTree as ET
    from email.utils import format_datetime

    # Register atom namespace prefix
    ATOM_NS = "http://www.w3.org/2005/Atom"
    ET.register_namespace("atom", ATOM_NS)

    # Create RSS root element (namespace declarations handled automatically by register_namespace)
    rss = ET.Element("rss", version="2.0")

    # Channel metadata
    channel = ET.SubElement(rss, "channel")
    ET.SubElement(channel, "title").text = config["site_title"]
    ET.SubElement(channel, "link").text = config["site_url"]
    ET.SubElement(channel, "description").text = config["site_description"]
    ET.SubElement(channel, "language").text = config["lang"]
    ET.SubElement(channel, "lastBuildDate").text = format_datetime(datetime.now(timezone.utc))

    # Add atom:link self-link
    atom_link = ET.SubElement(channel, f"{{{ATOM_NS}}}link")
    atom_link.set("href", f"{config['site_url']}/feed.xml")
    atom_link.set("rel", "self")
    atom_link.set("type", "application/rss+xml")

    # Add article entries
    for post in posts:
        item = ET.SubElement(channel, "item")

        ET.SubElement(item, "title").text = post["title"]
        ET.SubElement(item, "link").text = post["link"]
        ET.SubElement(item, "guid", isPermaLink="true").text = post["link"]
        ET.SubElement(item, "pubDate").text = format_datetime(post["date"])
        ET.SubElement(item, "category").text = post["dir"]

        # Only add description when present
        if des := post["description"]:
            ET.SubElement(item, "description").text = des

    # Generate XML string
    ET.indent(rss, space="  ")
    xml_str = ET.tostring(rss, encoding="unicode", xml_declaration=False)

    return f'<?xml version="1.0" encoding="UTF-8"?>\n{xml_str}'


def generate_rss(site_url: str) -> bool:
    """
    Generate the website's RSS feed file.

    Complete RSS Feed generation flow:
    1. Read target directories (categories) from config.typ
    2. Collect metadata for all articles in the specified directories
    3. Sort by date
    4. Build RSS XML and write to file

    Returns:
        bool: Whether generation was successful. Returns True when:
            - RSS file generated successfully
            - No category directories found (generation skipped)
            - No articles found (empty feed generated)
        Only returns False when an exception occurs.
    """
    rss_file = SITE_DIR / "feed.xml"
    dirs = get_feed_dirs()

    if not dirs:
        print("Skipping RSS feed generation: no directories configured.")
        return True

    # Check if at least one directory exists
    existing = {d for d in dirs if (SITE_DIR / d).exists()}
    missing = dirs - existing

    for d in missing:
        print(f"Warning: configured directory '{d}' does not exist.")

    if not existing:
        print("Skipping RSS feed generation: none of the configured directories exist.")
        return True

    # Collect articles
    posts = collect_posts(existing, site_url)

    if not posts:
        print("No articles found, RSS feed is empty.")
        return True

    # Sort by date descending
    posts = sorted(posts, key=lambda x: x["date"], reverse=True)

    # Get configuration info
    index_html = SITE_DIR / "index.html"
    parser = parse_html_metadata(index_html)

    lang = parser["lang"]
    site_title = parser["title"].strip()
    site_description = parser.get("description", "").strip()

    config = {
        "site_url": site_url,
        "site_title": site_title,
        "site_description": site_description,
        "lang": lang,
    }

    # Build RSS XML
    try:
        rss_content = build_rss_xml(posts, config)
        rss_file.write_text(rss_content, encoding="utf-8")
        print(f"RSS feed generated successfully: {rss_file} ({len(posts)} articles)")
        return True
    except ValueError as e:
        print("Error: RSS feed generation failed")
        print(f"   Reason: feedgen library error - {e}")
        print("   Fix: Please check the required config fields in config.typ (title and description)")
        return False
    except Exception as e:
        print("Error: Failed to generate RSS feed")
        print(f"   Exception: {type(e).__name__}: {e}")
        return False


def generate_sitemap(site_url: str) -> bool:
    """
    Generate sitemap.xml using Python's standard library xml.etree.ElementTree.
    """
    import xml.etree.ElementTree as ET

    sitemap_path = SITE_DIR / "sitemap.xml"
    sitemap_ns = "http://www.sitemaps.org/schemas/sitemap/0.9"

    # Register default namespace
    ET.register_namespace("", sitemap_ns)

    # Create root element
    urlset = ET.Element("urlset", xmlns=sitemap_ns)

    # Traverse the _site directory
    for file_path in sorted(SITE_DIR.rglob("*.html")):
        rel_path = file_path.relative_to(SITE_DIR).as_posix()

        # Determine URL path
        if rel_path == "index.html":
            url_path = ""
        elif rel_path.endswith("/index.html"):
            url_path = rel_path.removesuffix("index.html")
        elif rel_path.endswith(".html"):
            url_path = rel_path.removesuffix(".html") + "/"
        else:
            url_path = rel_path

        full_url = f"{site_url}/{url_path}"

        # Get last modification time
        mtime = file_path.stat().st_mtime
        lastmod = datetime.fromtimestamp(mtime).strftime("%Y-%m-%d")

        # Create url element
        url_elem = ET.SubElement(urlset, "url")
        ET.SubElement(url_elem, "loc").text = full_url
        ET.SubElement(url_elem, "lastmod").text = lastmod

    # Generate XML string
    ET.indent(urlset, space="  ")
    xml_str = ET.tostring(urlset, encoding="unicode", xml_declaration=False)
    sitemap_content = f'<?xml version="1.0" encoding="UTF-8"?>\n{xml_str}'

    try:
        sitemap_path.write_text(sitemap_content, encoding="utf-8")
        print(f"Sitemap build complete: {len(urlset)} pages")
        return True
    except Exception as e:
        print(f"Sitemap build failed: {e}")
        return False


def generate_robots_txt(site_url: str) -> bool:
    """
    Generate robots.txt pointing to the sitemap.
    """
    robots_content = f"""User-agent: *
Allow: /

Sitemap: {site_url}/sitemap.xml
"""

    try:
        (SITE_DIR / "robots.txt").write_text(robots_content, encoding="utf-8")
        return True
    except Exception as e:
        print(f"Failed to generate robots.txt: {e}")
        return False


def build(force: bool = False) -> bool:
    """
    Full build: HTML + PDF + assets.

    Args:
        force: Whether to force rebuild all files
    """
    print("-" * 60)
    if force:
        clean()
        print("Starting full build...")
    else:
        print("Starting incremental build...")
    print("-" * 60)

    # Ensure output directory exists
    SITE_DIR.mkdir(parents=True, exist_ok=True)

    results = []

    print()
    results.append(build_html(force))
    results.append(build_pdf(force))
    print()

    results.append(copy_assets())
    results.append(copy_content_assets(force))

    if site_url := get_site_url():
        results.append(generate_sitemap(site_url))
        results.append(generate_robots_txt(site_url))
        results.append(generate_rss(site_url))

    print("-" * 60)
    if all(results):
        print("All build tasks complete!")
        print(f"  Output directory: {SITE_DIR.absolute()}")
    else:
        print("Build complete, but some tasks failed.")
    print("-" * 60)

    return all(results)


# ============================================================================
# Command-line interface
# ============================================================================


def create_parser() -> argparse.ArgumentParser:
    """
    Create the command-line argument parser.
    """
    parser = argparse.ArgumentParser(
        prog="build.py",
        description="Tufted Blog Template build script - compiles Typst files in content/ to HTML and PDF",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
By default, the build script only recompiles modified files. Use -f/--force to force a full rebuild:
    uv run build.py build --force
    or python build.py build -f

Use the preview command to start a local preview server:
    uv run build.py preview
    or python build.py preview -p 3000  # Use a custom port

See README.md for more information
""",
    )

    subparsers = parser.add_subparsers(dest="command", title="available commands", metavar="<command>")

    build_parser = subparsers.add_parser("build", help="Full build (HTML + PDF + assets)")
    build_parser.add_argument("-f", "--force", action="store_true", help="Force full rebuild")

    html_parser = subparsers.add_parser("html", help="Build HTML files only")
    html_parser.add_argument("-f", "--force", action="store_true", help="Force full rebuild")

    pdf_parser = subparsers.add_parser("pdf", help="Build PDF files only")
    pdf_parser.add_argument("-f", "--force", action="store_true", help="Force full rebuild")

    subparsers.add_parser("assets", help="Copy static assets only")
    subparsers.add_parser("clean", help="Clean generated files")

    preview_parser = subparsers.add_parser("preview", help="Start local preview server")
    preview_parser.add_argument(
        "-p", "--port", type=int, default=8000, help="Server port (default: 8000)"
    )
    preview_parser.add_argument(
        "--no-open", action="store_false", dest="open_browser", help="Don't automatically open browser"
    )
    preview_parser.set_defaults(open_browser=True)

    return parser


if __name__ == "__main__":
    parser = create_parser()
    args = parser.parse_args()

    if args.command is None:
        parser.print_help()
        sys.exit(0)

    # Ensure running from project root directory
    script_dir = Path(__file__).parent.absolute()
    os.chdir(script_dir)

    # Get force parameter
    force = getattr(args, "force", False)

    # Execute the corresponding command using match-case
    match args.command:
        case "build":
            success = build(force)
        case "html":
            success = build_html(force)
        case "pdf":
            success = build_pdf(force)
        case "assets":
            success = copy_assets()
        case "clean":
            success = clean()
        case "preview":
            success = preview(getattr(args, "port", 8000), getattr(args, "open_browser", True))
        case _:
            print(f"Unknown command: {args.command}")
            success = False

    sys.exit(0 if success else 1)
