#!/usr/bin/env bash
set -euo pipefail

BASENAME="${1:-genug_texte}"
BUILD="${BUILD_VERSION:-$(date -u +%Y%m%d-%H%M%S)}"

BASE_DIR="$(pwd)"
OUT_ZIP_BUILD="${BASE_DIR}/${BASENAME}_${BUILD}.zip"
OUT_ZIP_STABLE="${BASE_DIR}/${BASENAME}.zip"

# Staging mit Unterordner 'genug/'
STAGE="$(mktemp -d 2>/dev/null || mktemp -d -t mdzip)"
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/genug"

# Nur .md mit Struktur kopieren
while IFS= read -r rel; do
  mkdir -p "$STAGE/genug/$(dirname "$rel")"
  cp -a "$rel" "$STAGE/genug/$rel"
done < <(find . -type f -name '*.md' -print | sed 's|^\./||' | sort)

# Beipackzettel ins genug/-Ordner
cat > "$STAGE/genug/LESEN_STARTEN.txt" <<'TXT'
Danke fürs Herunterladen der Texte.

So startest du:
• Öffne die Datei index.md in einem Markdown-Viewer
  (oder lies online: https://justthis.space/genug/viewer.html)

Hinweis: Dieses ZIP enthält nur .md-Dateien (plain text).
TXT

# ZIP bauen – Unterordner genug als Ganzes ins Root legen
if command -v zip >/dev/null 2>&1; then
  ( cd "$STAGE" && zip -9 -q -r "$OUT_ZIP_BUILD" genug )
else
  python3 - <<PY
import os, zipfile
stage = r"$STAGE"
out   = r"$OUT_ZIP_BUILD"
root  = os.path.join(stage, "genug")
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for base, _, files in os.walk(root):
        for f in files:
            p = os.path.join(base, f)
            z.write(p, arcname=os.path.relpath(p, stage))
PY
fi

cp -f "$OUT_ZIP_BUILD" "$OUT_ZIP_STABLE"
echo "✅ ZIP erstellt:"
echo "   • $OUT_ZIP_BUILD"
echo "   • $OUT_ZIP_STABLE (stabiler Name)"
