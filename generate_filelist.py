#!/usr/bin/env python3
import os
import json

# Basis-Verzeichnis (dort wo README.md, index.md usw. liegen)
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_FILE = os.path.join(BASE_DIR, "filelist.json")

md_files = []
for root, dirs, files in os.walk(BASE_DIR):
    for file in files:
        if file.lower().endswith(".md"):
            rel_path = os.path.relpath(os.path.join(root, file), BASE_DIR)
            md_files.append(rel_path.replace("\\", "/"))

# Sortieren für schöne Anzeige
md_files.sort(key=lambda x: x.lower())

with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
    json.dump(md_files, f, indent=2, ensure_ascii=False)

print(f"✅ filelist.json erstellt mit {len(md_files)} Markdown-Dateien")
