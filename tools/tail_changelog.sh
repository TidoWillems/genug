#!/usr/bin/env bash
set -euo pipefail

# zeigt die letzten 30 Zeilen vom CHANGELOG an, eingerahmt
echo "─── 📜 Letzte Deploy-Einträge ───"
tail -n 30 "$(dirname "$0")/../CHANGELOG.md"
echo "────────────────────────────────"
