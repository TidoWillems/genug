#!/usr/bin/env bash
set -euo pipefail

: "${FTP_HOST:=}"; : "${FTP_USER:=}"; : "${FTP_PASS:=}"; : "${REMOTE_DIR:=}"
if [[ -z "$FTP_HOST$FTP_USER$FTP_PASS$REMOTE_DIR" ]]; then
  [[ -f .deploy.env ]] && source .deploy.env || { echo "Fehlt: ENV oder .deploy.env"; exit 1; }
fi

BASE_DIR="${BASE_DIR:-$(pwd)}"
STAMP="$(date -u +%Y%m%d-%H%M%S)"
if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  GIT_SHORT="$(git rev-parse --short HEAD 2>/dev/null || true)"
else
  GIT_SHORT=""
fi
BUILD_VERSION="${STAMP}${GIT_SHORT:+-$GIT_SHORT}"
export BUILD_VERSION

python3 generate_filelist.py
echo "✅ filelist.json erstellt"

PREV_LIST="tools/.build/md_list_prev.txt"
NEW_LIST="tools/.build/md_list_new.txt"
mkdir -p tools/.build
[[ -f "$PREV_LIST" ]] && cp "$PREV_LIST" "${PREV_LIST}.bak" || true
jq -r '.[]' filelist.json | sort > "$NEW_LIST"

./make_md_zip.sh
./make_html_zip.sh

STAGE="$(mktemp -d 2>/dev/null || mktemp -d -t genug_stage)"
cp -a "$BASE_DIR/." "$STAGE/"

for f in viewer.html index.html; do
  [[ -f "$STAGE/$f" ]] && sed "s/__BUILD__/${BUILD_VERSION}/g" "$STAGE/$f" > "$STAGE/$f.tmp" && mv "$STAGE/$f.tmp" "$STAGE/$f"
done

FILES_COUNT="$(jq 'length' filelist.json 2>/dev/null || wc -l < filelist.json)"
{
  echo "### ${BUILD_VERSION}"
  echo
  echo "- Deployed: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
  echo "- Ziel: \`${FTP_HOST}:${REMOTE_DIR}\`"
  echo "- Dateien (Markdown gezählt): ${FILES_COUNT}"
} >> CHANGELOG.md

cp "$NEW_LIST" "$PREV_LIST"
cp -f CHANGELOG.md "$STAGE/"

echo "✅ Staging vorbereitet (Build ${BUILD_VERSION}) -> $STAGE"

lftp -u "$FTP_USER","$FTP_PASS" "$FTP_HOST" <<EOF_LFTP
set ssl:verify-certificate no
set cmd:fail-exit yes
cd "$REMOTE_DIR" || (mkdir -p "$REMOTE_DIR"; cd "$REMOTE_DIR")
mirror -R --only-newer --parallel=2 --no-perms --no-symlinks \
  --exclude-glob '.git*' \
  --exclude-glob '*.sh' \
  --exclude-glob '*.py' \
  --exclude '.deploy.env' \
  "$STAGE" .
bye
EOF_LFTP

echo "✅ Upload fertig nach ${FTP_HOST}:${REMOTE_DIR} (Build ${BUILD_VERSION})"
rm -rf "$STAGE"

echo "↪️  Git-Sync: commit & push …"
git add -A
git commit -m "deploy: ${BUILD_VERSION}" || echo "ℹ️  Nichts zu committen"
git pull --rebase origin main || true
git push origin main
echo "✅ Git-Sync abgeschlossen."
