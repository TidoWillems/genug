#!/usr/bin/env bash
set -euo pipefail

### ------------------------------------------------------------------
### Deploy-Skript – genug
### First-Run Checkliste:
### 1. Datei `.deploy.env` anlegen mit:
###      FTP_USER=...
###      FTP_PASS=...
###      FTP_HOST=...
###      REMOTE_DIR=/htdocs/genug
### 2. Pakete installieren:
###      pkg install lftp jq python
### 3. Hilfsskripte ausführbar machen:
###      chmod +x make_md_zip.sh make_html_zip.sh
### 4. Datei `generate_filelist.py` muss vorhanden und lauffähig sein
### 5. Start: ./deploy.sh
### ------------------------------------------------------------------

### 1) Env laden
if [[ -f .deploy.env ]]; then
  # shellcheck disable=SC1091
  source .deploy.env
else
  echo "Fehlt: .deploy.env" >&2
  exit 1
fi

BASE_DIR="${BASE_DIR:-$(pwd)}"

### 2) Build-Version (UTC + optional Git-Short)
STAMP="$(date -u +%Y%m%d-%H%M%S)"
if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  GIT_SHORT="$(git rev-parse --short HEAD 2>/dev/null || true)"
else
  GIT_SHORT=""
fi
BUILD_VERSION="${STAMP}${GIT_SHORT:+-$GIT_SHORT}"
export BUILD_VERSION

### 3) filelist erzeugen
python3 generate_filelist.py
echo "✅ filelist.json erstellt"

### 3a) Vorherige / neue Listen vorbereiten
PREV_LIST="tools/.build/md_list_prev.txt"
NEW_LIST="tools/.build/md_list_new.txt"
mkdir -p tools/.build

if [[ -f "$PREV_LIST" ]]; then
  cp "$PREV_LIST" "${PREV_LIST}.bak"
fi
jq -r '.[]' filelist.json | sort > "$NEW_LIST"

### 3b) ZIPs bauen
./make_md_zip.sh
./make_html_zip.sh

### 4) Staging-Verzeichnis anlegen und Projekt hineinkopieren
STAGE="$(mktemp -d 2>/dev/null || mktemp -d -t genug_stage)"
cp -a "$BASE_DIR/." "$STAGE/"

# Platzhalter __BUILD__ in viewer.html und index.html ersetzen (nur Wert!)
for f in viewer.html index.html; do
  if [[ -f "$STAGE/$f" ]]; then
    sed "s/__BUILD__/${BUILD_VERSION}/g" "$STAGE/$f" > "$STAGE/$f.tmp" && mv "$STAGE/$f.tmp" "$STAGE/$f"
  fi
done

### 5) CHANGELOG aktualisieren
FILES_COUNT="$(jq 'length' filelist.json 2>/dev/null || wc -l < filelist.json)"
{
  echo "### ${BUILD_VERSION}"
  echo
  echo "- Deployed: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
  echo "- Ziel: \`${FTP_HOST}:${REMOTE_DIR}\`"
  echo "- Dateien (Markdown gezählt): ${FILES_COUNT}"

  if [[ -f "$PREV_LIST" ]]; then
    NEW_FILES=$(comm -13 "$PREV_LIST" "$NEW_LIST" || true)

    # Filter: diese Dateien nicht als "neu" listen
    FILTERED_FILES=""
    for f in $NEW_FILES; do
      case "$f" in
        CHANGELOG.md|README.md|index.md) ;;   # ignoriere
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

# Neue Liste als prev speichern
cp "$NEW_LIST" "$PREV_LIST"

# Auch die aktualisierte CHANGELOG in die Staging-Kopie legen
cp -f CHANGELOG.md "$STAGE/"

echo "✅ Staging vorbereitet (Build ${BUILD_VERSION}) -> $STAGE"

### 6) Upload
lftp -u "$FTP_USER","$FTP_PASS" "$FTP_HOST" <<EOF_LFTP
set ssl:verify-certificate no
set cmd:fail-exit yes

cd "$REMOTE_DIR" || (mkdir -p "$REMOTE_DIR"; cd "$REMOTE_DIR")

mirror -R --verbose --parallel=2 --no-perms --no-symlinks \
  --exclude-glob '.git*' \
  --exclude-glob '*.sh' \
  --exclude-glob '*.py' \
  --exclude '.deploy.env' \
  "$STAGE" .

bye
EOF_LFTP

echo "✅ Upload fertig nach ${FTP_HOST}:${REMOTE_DIR} (Build ${BUILD_VERSION})"

### 7) Aufräumen
rm -rf "$STAGE"
