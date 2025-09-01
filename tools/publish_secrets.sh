#!/usr/bin/env bash
set -euo pipefail

# Anforderungen: gh CLI eingeloggt (gh auth status), .deploy.env vorhanden
if [[ ! -f .deploy.env ]]; then
  echo "❌ .deploy.env fehlt." >&2
  exit 1
fi

# shellcheck disable=SC1091
source .deploy.env

missing=()
for v in FTP_HOST FTP_USER FTP_PASS REMOTE_DIR; do
  [[ -z "${!v:-}" ]] && missing+=("$v")
done
if (( ${#missing[@]} > 0 )); then
  echo "❌ Fehlende Variablen in .deploy.env: ${missing[*]}" >&2
  exit 1
fi

# Secrets setzen
gh secret set FTP_HOST   -b"$FTP_HOST"
gh secret set FTP_USER   -b"$FTP_USER"
gh secret set FTP_PASS   -b"$FTP_PASS"
gh secret set REMOTE_DIR -b"$REMOTE_DIR"

echo "✅ Repo-Secrets gesetzt: FTP_HOST, FTP_USER, FTP_PASS, REMOTE_DIR"
