#!/usr/bin/env bash
# make_html_zip.sh
set -euo pipefail

BASENAME="${1:-genug_html}"
BUILD="${BUILD_VERSION:-$(date -u +%Y%m%d-%H%M%S)}"

BASE_DIR="$(pwd)"
OUT_ZIP_BUILD="${BASE_DIR}/${BASENAME}_${BUILD}.zip"
OUT_ZIP_STABLE="${BASE_DIR}/${BASENAME}.zip"

# Staging mit Unterordner 'genug/'
STAGE="$(mktemp -d 2>/dev/null || mktemp -d -t htmlzip)"
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/genug"

# Alle .html mit Struktur kopieren (relativ, sortiert)
while IFS= read -r rel; do
  mkdir -p "$STAGE/genug/$(dirname "$rel")"
  cp -a "$rel" "$STAGE/genug/$rel"
done < <(find . -type f -name '*.html' -print | sed 's|^\./||' | sort)

# Beipackzettel
cat > "$STAGE/genug/LESEN_STARTEN.txt" <<'TXT'
Danke fürs Herunterladen der HTML-Version.

So startest du offline:
• Öffne die Datei viewer.html (empfohlen) ODER index.html im Browser.

Hinweis:
• Je nach Browser sind lokale Datei-URLs eingeschränkt (z.B. CORS).
• Online-Variante: https://justthis.space/genug/viewer.html
TXT

# ZIP bauen – Unterordner 'genug' ins Root legen
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

echo "✅ HTML-ZIP erstellt:"
echo "   • $OUT_ZIP_BUILD"
echo "   • $OUT_ZIP_STABLE (stabiler Name)"
