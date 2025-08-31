#!/usr/bin/env bash
set -euo pipefail

ROOT="${ROOT:-$HOME/zenova/justthisspace/projekte/genug}"
BASE_URL="${BASE_URL:-https://justthisspace.ct.ws/genug}"
cd "$ROOT"

mkdir -p tools/.build

# Vorher-Liste (für Diff neuer .md)
PREV_LIST="tools/.build/md_list_prev.txt"
NEW_LIST="tools/.build/md_list_new.txt"
[ -f "$PREV_LIST" ] || touch "$PREV_LIST"

# Argumente parsen
MENTIONS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mention)
      shift
      [ $# -gt 0 ] && MENTIONS+=("$1")
      ;;
    *)
      ROOT="$1"
      ;;
  esac
  shift || true
done

# 1) Rendern & Sitemap
if [ -f "${ROOT}/build_genug.py" ]; then
  BASE_URL="$BASE_URL" python3 "${ROOT}/build_genug.py"
fi

# 2) filelist.json
if [ -f "${ROOT}/generate_filelist.py" ]; then
  python3 "${ROOT}/generate_filelist.py" || true
fi

# 3) Neu-Liste erstellen und Diff
find . -type f -name '*.md' | sort > "$NEW_LIST"
NEW_FILES=$(comm -13 "$PREV_LIST" "$NEW_LIST" || true)

# 4) Zähler & Timestamps
COUNT_MD="$(wc -l < "$NEW_LIST" | awk '{print $1}')"
STAMP="$(date -u +%Y%m%d-%H%M%S)"
HUMAN="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

# 5) CHANGELOG-Eintrag
{
  echo ""
  echo "### ${STAMP}"
  echo ""
  echo "- Deployed: ${HUMAN}"
  echo "- Ziel: \`ftpupload.net:/htdocs/genug\`"
  echo "- Dateien (Markdown gezählt): ${COUNT_MD}"
  if [ -n "$NEW_FILES" ]; then
    echo "- Neu hinzugefügt:"
    echo "$NEW_FILES" | sed 's#^\./##' | sed 's#^#  - #'
  fi
  if [ ${#MENTIONS[@]} -gt 0 ]; then
    echo "- Erwähnt:"
    for m in "${MENTIONS[@]}"; do
      echo "  - $m"
    done
  fi
} >> "${ROOT}/CHANGELOG.md"

# 6) Neu-Liste als prev speichern
cp "$NEW_LIST" "$PREV_LIST"

echo "OK: Build fertig, Sitemap/Dateiliste aktualisiert, CHANGELOG ergänzt."
