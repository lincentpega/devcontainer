#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = ["httpx", "beautifulsoup4", "markdownify", "readabilipy"]
# ///
"""Fetch a web page, return its main content as markdown.

Adapted from full-stack-biz/fetch-urls-skill (fetch_anchor.py) — Mozilla
Readability (readabilipy) for main-content extraction + markdownify for GFM.

Usage:
    fetch.py <url>                    # full page as markdown
    fetch.py <url> --list-anchors     # list heading anchors (h1-h6 hierarchy)
    fetch.py <url> --anchor <id>      # one section: heading + its content
"""
import argparse
import sys

import httpx
import markdownify
import readabilipy.simple_json
from bs4 import BeautifulSoup, Tag

USER_AGENT = ("Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
              "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36")
HEADING_TAGS = {"h1", "h2", "h3", "h4", "h5", "h6"}
HEADING_RANK = {"h1": 1, "h2": 2, "h3": 3, "h4": 4, "h5": 5, "h6": 6}


def fetch_page(url: str) -> tuple[str, str]:
    with httpx.Client(follow_redirects=True, timeout=30) as client:
        resp = client.get(url, headers={
            "User-Agent": USER_AGENT,
            "Accept": "text/html,application/xhtml+xml,*/*;q=0.8",
            "Accept-Language": "en-US,en;q=0.9",
        })
        resp.raise_for_status()
        return resp.text, resp.headers.get("content-type", "")


def is_html(raw: str, content_type: str) -> bool:
    return "<html" in raw[:100].lower() or "text/html" in content_type or not content_type


def resolve_heading_level(target: Tag) -> tuple[Tag, int] | None:
    """Heading level for an anchor element: itself, its parent, or a child heading."""
    if target.name in HEADING_TAGS:
        return target, HEADING_RANK[target.name]
    parent = target.parent
    if parent and parent.name in HEADING_TAGS:
        return parent, HEADING_RANK[parent.name]
    child = target.find(HEADING_TAGS)
    if child:
        return target, HEADING_RANK[child.name]
    return None


def collect_section(heading_el: Tag, rank: int) -> str:
    """Heading + all siblings until the next same-or-higher-level heading."""
    nodes = [heading_el]
    for sibling in heading_el.next_siblings:
        if isinstance(sibling, Tag):
            resolved = resolve_heading_level(sibling)
            if resolved and resolved[1] <= rank:
                break
        nodes.append(sibling)
    wrapper = BeautifulSoup("", "html.parser").new_tag("div")
    for node in nodes:
        wrapper.append(node.extract())
    return str(wrapper)


def to_markdown(html: str) -> str:
    return markdownify.markdownify(html, heading_style=markdownify.ATX)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("url")
    ap.add_argument("--list-anchors", action="store_true")
    ap.add_argument("--anchor", help="extract only the section with this id")
    args = ap.parse_args()

    try:
        raw, content_type = fetch_page(args.url)
    except Exception as e:
        print(f"web-fetch: fetch failed: {e}", file=sys.stderr)
        return 4

    if not is_html(raw, content_type):
        print(raw)  # JSON / plain text / non-HTML as-is
        return 0

    soup = BeautifulSoup(raw, "html.parser")

    if args.list_anchors:
        for el in soup.find_all(id=True):
            resolved = resolve_heading_level(el)
            if not resolved:
                continue
            level = resolved[1]
            text = el.get_text(strip=True)[:120]
            print(f"{'  ' * (level - 1)}h{level} #{el['id']} {text}")
        return 0

    if args.anchor:
        target = soup.find(id=args.anchor)
        if target is None:
            print(f"web-fetch: anchor #{args.anchor} not found (use --list-anchors)", file=sys.stderr)
            return 4
        resolved = resolve_heading_level(target)
        if resolved:
            section = collect_section(*resolved)
        else:
            section = str(target)
        print(to_markdown(section).strip())
        return 0

    # Full page: Readability main-content, fall back to raw HTML if undetected
    ret = readabilipy.simple_json.simple_json_from_html_string(raw, use_readability=True)
    content = ret.get("content") or raw
    title = (soup.title.get_text(strip=True) if soup.title else "").strip()
    if title:
        print(f"# {title}\n")
    print(to_markdown(content).strip())
    return 0


if __name__ == "__main__":
    sys.exit(main())
