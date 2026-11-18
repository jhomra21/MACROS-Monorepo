#!/usr/bin/env python3
"""Check local Markdown/HTML links in changed Markdown against the working tree.

Failure inventory: moved relative paths, missing images, broken fragments,
duplicate headings, HTML src/href, reference links, and code-example false hits.
External URLs are deliberately not fetched. Historical code paths are not links.
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import unquote, urlsplit


ROOT = Path(__file__).resolve().parents[2]


def git(*args):
    return subprocess.check_output(["git", "-C", str(ROOT), *args], text=True)


def prose(text):
    text = re.sub(r"(?ms)^(`{3,}|~{3,}).*?^\1[^\n]*$", "", text)
    return re.sub(r"`[^`\n]+`", "", text)


def anchors(text):
    counts = {}
    result = set(re.findall(r'\b(?:id|name)=["\']([^"\']+)["\']', text))
    headings = re.findall(r"(?m)^#{1,6}\s+(.+?)(?:\s+#+)?$", text)
    headings += re.findall(r"<h[2-6]\b[^>]*>(.*?)</h[2-6]>", text, re.IGNORECASE)
    for heading in headings:
        heading = re.sub(r"<[^>]+>", "", heading).lower()
        slug = "".join(c for c in heading if c.isalnum() or c in " _-").replace(" ", "-")
        slug = re.sub(r"-+", "-", slug).strip("-")
        count = counts.get(slug, 0)
        counts[slug] = count + 1
        result.add(slug + (f"-{count}" if count else ""))
    return result


def links(text):
    text = prose(text)
    targets = re.findall(r"!?\[[^\]]*\]\((<[^>]+>|(?:[^()\s]|\([^()]*\))+)(?:\s+[^)]*)?\)", text)
    targets += re.findall(r'\b(?:src|href)=["\']([^"\']+)["\']', text)
    targets += re.findall(r"(?m)^\s*\[[^\]]+\]:\s*(\S+)", text)
    return [target.strip("<>") for target in targets]


def web_route_destination(source, path):
    if "web" not in source.parts or "src" not in source.parts or "content" not in source.parts:
        return None

    route = unquote(path)
    if route == "/":
        return ROOT / "web/src/pages/index.astro"

    match = re.fullmatch(r"/(guides|blog)/([a-z0-9-]+)/?", route)
    if match:
        section, slug = match.groups()
        return ROOT / f"web/src/content/{section}/{slug}.md"

    page = route.strip("/")
    if re.fullmatch(r"[a-z0-9-]+", page):
        return ROOT / f"web/src/pages/{page}.astro"
    return None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", default="origin/main")
    args = parser.parse_args()
    paths = set(git("diff", "--name-only", "--diff-filter=ACMR", args.base).splitlines())
    paths.update(git("ls-files", "--others", "--exclude-standard").splitlines())
    paths = sorted(p for p in paths if p.endswith(".md") and (ROOT / p).is_file())
    errors = []
    checked = 0
    for name in paths:
        source = ROOT / name
        for target in links(source.read_text()):
            url = urlsplit(target)
            if url.scheme or url.netloc:
                continue
            checked += 1
            destination = web_route_destination(source, url.path) if url.path.startswith("/") else None
            destination = destination or ((source.parent / unquote(url.path)).resolve() if url.path else source)
            if not destination.exists():
                errors.append(f"{name}: missing {target}")
            elif url.fragment and destination.suffix in {".md", ".astro"}:
                candidates = [destination]
                if destination.name == "index.astro":
                    candidates.extend((ROOT / "web/src/components").glob("*.astro"))
                available = set().union(*(anchors(candidate.read_text()) for candidate in candidates))
                if unquote(url.fragment) not in available:
                    errors.append(f"{name}: missing fragment {target}")
    print(f"Checked {checked} local links in {len(paths)} changed Markdown files.")
    for error in errors:
        print(error)
    return bool(errors)


if __name__ == "__main__":
    sys.exit(main())
