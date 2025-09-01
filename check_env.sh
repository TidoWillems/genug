#!/usr/bin/env bash
set -euo pipefail
: "${FTP_HOST:?FTP_HOST fehlt}"
: "${FTP_USER:?FTP_USER fehlt}"
: "${FTP_PASS:?FTP_PASS fehlt}"
: "${REMOTE_DIR:?REMOTE_DIR fehlt}"

command -v lftp   >/dev/null || { echo "lftp fehlt (Termux: pkg install lftp)"; exit 1; }
command -v jq     >/dev/null || { echo "jq fehlt (Termux: pkg install jq)"; exit 1; }
command -v python >/dev/null || command -v python3 >/dev/null || { echo "python fehlt (Termux: pkg install python)"; exit 1; }

echo "✓ env ok"
