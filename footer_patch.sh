#!/usr/bin/env bash
set -euo pipefail
for f in index.html viewer.html; do
  if [[ -f "$f" ]]; then
    if ! grep -q "STATUS.md" "$f"; then
      sed -i '/<\/footer>/i \
<p><a href="https:\/\/github.com\/TidoWillems\/genug\/blob\/main\/STATUS.md">📖 Projektstatus</a></p>' "$f"
    fi
  fi
done
echo "✅ STATUS-Link in index.html und viewer.html ergänzt."
