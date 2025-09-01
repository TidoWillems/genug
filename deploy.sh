#!/usr/bin/env bash
set -euo pipefail

### ------------------------------------------------------------------
### Deploy-Skript – genug (ENV-first)
### First-Run Checkliste:
### 1. Entweder ENV setzen (FTP_HOST/FTP_USER/FTP_PASS/REMOTE_DIR)
###    ODER .deploy.env anlegen (siehe .deploy.env.example)
### 2. Termux Pakete: pkg install lftp jq python
### 3. Hilfsskripte ausführbar: chmod +x make_md_zip.sh make_html_zip.sh
### ------------------------------------------------------------------

# ENV-first, dann Fallback auf .deploy.env
: "${FTP_HOST:=}"
: "${FTP_USER:=}"
: "${FTP_PASS:=}"
: "${REMOTE_DIR:=}"
if [[ -z "$FTP_HOST$FTP_USER$FTP_PASS$REMOTE_DIR" ]]; then
  if [[ -f .deploy.env ]]; then
    # shellcheck disable=SC1091
    source .deploy.env
  else
    echo "Fehlt: ENV Variablen oder .deploy.env" >&2
    exit 1
  fi
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
  if [[ -f "$STAGE/$f" ]]; then
    sed "s/__BUILD__/${BUILD_VERSION}/g" "$STAGE/$f" > "$STAGE/$f.tmp" && mv "$STAGE/$f.tmp" "$STAGE/$f"
  fi
done

FILES_COUNT="$(jq 'length' filelist.json 2>/dev/null || wc -l < filelist.json)"
{
  echo "### ${BUILD_VERSION}"
  echo
  echo "- Deployed: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
  echo "- Ziel: \`${FTP_HOST}:${REMOTE_DIR}\`"
  echo "- Dateien (Markdown gezählt): ${FILES_COUNT}"

  if [[ -f "$PREV_LIST" ]]; then
    NEW_FILES=$(comm -13 "$PREV_LIST" "$NEW_LIST" || true)
    FILTERED_FILES=""
    for f in $NEW_FILES; do
      case "$f" in
        CHANGELOG.md|README.md|index.md) ;;
        *) FILTERED_FILES+="$f"$'\n' ;;
      esac
    done
    if [[ -n "${FILTERED_FILES:-}" ]]; then
      echo "- Neu hinzugefügt:"
      while IFS= read -r f; do
        [[ -n "$f" ]] && echo "  - $f"
      done <<< "$FILTERED_FILES"
    fi
  fi
  echo
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

### 8) Git-Sync (immer, falls Repo existiert)
if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "↪️  Git-Sync: commit & push …"

  git add -A

  if ! git diff --cached --quiet; then
    git commit -m "deploy: ${BUILD_VERSION}"
  else
    echo "ℹ️  Keine neuen Änderungen zu committen."
  fi

  BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)"
  if git remote get-url origin >/dev/null 2>&1; then
    git pull --rebase origin "$BRANCH" || true
    git push -u origin "$BRANCH"
    echo "✅ Git-Sync abgeschlossen."
  else
    echo "ℹ️  Kein Remote 'origin' – Push übersprungen."
  fi
else
  echo "ℹ️  Kein Git-Repo – Git-Sync übersprungen."
fi
