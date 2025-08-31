#!/usr/bin/env bash
set -euo pipefail

if [[ ! -f .deploy.env ]]; then
  echo "❌ Fehler: .deploy.env fehlt. Bitte .deploy.env.example kopieren und anpassen."
  exit 1
fi

# shellcheck disable=SC1091
source .deploy.env

missing=()

for var in FTP_HOST FTP_USER FTP_PASS REMOTE_DIR; do
  if [[ -z "${!var:-}" ]]; then
    missing+=("$var")
  fi
done

if (( ${#missing[@]} > 0 )); then
  echo "❌ Fehler: folgende Variablen fehlen: ${missing[*]}"
  exit 1
fi

echo "✅ .deploy.env vorhanden und vollständig."
