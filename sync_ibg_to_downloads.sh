#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$(dirname "$0")"

SRC="$HOME/projekte/ich_bin_genug"
DST="$HOME/storage/downloads/ich_bin_genug"

echo "🚚 Sync: dist/ich_bin_genug → downloads/ich_bin_genug"
echo "Quelle: $SRC"
echo "Ziel:   $DST"
echo

mkdir -p "$DST"
cp -ruv "$SRC/" "$DST/"

echo
echo "✅ Alles synchronisiert – bereit für Upload."
