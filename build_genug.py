#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os, re, sys, json, datetime
from pathlib import Path
from urllib.parse import urljoin
try:
    import markdown
except ImportError:
    print("Das Modul 'markdown' fehlt. Bitte: pip install markdown")
    sys.exit(1)

# ====== Einstellungen ======
# Basis-URL deiner Live-Seite (ohne trailing slash)
BASE_URL = os.environ.get("BASE_URL", "https://justthis.space/genug")

# HTML-Template (sehr schlicht; gern anpassen)
HTML_TMPL = """<!DOCTYPE html>
<html lang="de">
<head>
  <meta charset="UTF-8">
  <title>{title}</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="generator" content="genug-prerender">
  <style>
    body {{ font-family: system-ui, -apple-system, Segoe UI, Roboto, sans-serif;
           margin: 0; padding: 2rem; max-width: 900px; margin-inline: auto;
           line-height: 1.6; color:#222; background:#fdfdfd; }}
    main {{ display:block }}
    h1,h2,h3 {{ line-height:1.25 }}
    a {{ color:#006688; text-decoration:none }}
    a:hover {{ text-decoration:underline }}
    nav.breadcrumbs {{ font-size:.9rem; margin:.5rem 0 2rem; color:#666 }}
    footer {{ margin-top: 4rem; font-size:.9rem; color:#666; text-align:center }}
    pre,code {{ font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace }}
    blockquote {{ margin:1rem 0; padding-left:1rem; border-left:4px solid #ddd; color:#444 }}
    img {{ max-width:100%; height:auto }}
  </style>
</head>
<body>
  <nav class="breadcrumbs"><a href="{base}/">/genug</a></nav>
  <main>
{content}
  </main>
  <footer>
    <p><a href="{base}/">← zurück zur Übersicht</a> · <a href="/index.html">zur Hauptseite</a></p>
  </footer>
</body>
</html>
"""

MD_EXT = [
    "extra",         # Tabellen, Fußnoten, etc.
    "toc",           # Inhaltsverzeichnis (optionale Nutzung)
    "sane_lists",
    "smarty",
]

ROOT = Path.cwd()

def first_h1(md_text: str, fallback: str) -> str:
    """erste Markdown-H1 (# Überschrift) als Titel; sonst Dateiname"""
    for line in md_text.splitlines():
        m = re.match(r"^\s*#\s+(.+?)\s*$", line)
        if m:
            return m.group(1).strip()
    return fallback

def rewrite_md_links(html: str) -> str:
    """Verweise auf .md → .html (einfach, deckt 90% ab)"""
    html = re.sub(r'href="([^"]+?)\.md(\#[^"]*)?"',
                  lambda m: f'href="{m.group(1)}.html{m.group(2) or ""}"',
                  html)
    return html

def render_md_to_html(md_path: Path) -> Path:
    rel = md_path.relative_to(ROOT)
    html_path = ROOT / rel.with_suffix(".html")

    md_text = md_path.read_text(encoding="utf-8")
    title = first_h1(md_text, fallback=md_path.stem)
    body = markdown.markdown(md_text, extensions=MD_EXT, output_format="html5")
    body = rewrite_md_links(body)

    html = HTML_TMPL.format(title=title, content=indent_html(body, 2), base=BASE_URL)
    html_path.parent.mkdir(parents=True, exist_ok=True)
    html_path.write_text(html, encoding="utf-8")
    return html_path

def indent_html(html: str, level: int = 2) -> str:
    indent = "  " * level
    return "\n".join(f"{indent}{line}" if line.strip() else "" for line in html.splitlines())

def build_sitemap(urls):
    now = datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
    out = ['<?xml version="1.0" encoding="UTF-8"?>',
           '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">']
    for u in sorted(urls):
        out.append("  <url>")
        out.append(f"    <loc>{u}</loc>")
        out.append(f"    <lastmod>{now}</lastmod>")
        out.append("    <changefreq>weekly</changefreq>")
        out.append("    <priority>0.6</priority>")
        out.append("  </url>")
    out.append("</urlset>\n")
    return "\n".join(out)

def main():
    md_files = []
    for p in ROOT.rglob("*.md"):
        # Optional: bestimmte Pfade/Dateien ausschließen
        if any(part.startswith(".") for part in p.parts):
            continue
        md_files.append(p)

    if not md_files:
        print("Keine .md gefunden.")
        return

    print(f"Gefundene Markdown-Dateien: {len(md_files)}")
    generated = []

    for md in md_files:
        html = render_md_to_html(md)
        generated.append(html)
        print(f"✓ {md.relative_to(ROOT)} → {html.relative_to(ROOT)}")

    # statische Zusatzseiten in die Sitemap aufnehmen (falls vorhanden)
    extra = []
    for name in ["index.html", "viewer.html"]:
        candidate = ROOT / name
        if candidate.exists():
            extra.append(candidate)

    all_pages = generated + extra

    # Sitemap schreiben
    urls = []
    for f in all_pages:
        rel = f.relative_to(ROOT).as_posix()
        # Nur HTML listen
        if rel.lower().endswith(".html"):
            urls.append(urljoin(BASE_URL + "/", rel))

    sitemap = build_sitemap(urls)
    (ROOT / "sitemap.xml").write_text(sitemap, encoding="utf-8")
    print(f"\nSitemap geschrieben: {ROOT/'sitemap.xml'} (Einträge: {len(urls)})")

if __name__ == "__main__":
    main()
