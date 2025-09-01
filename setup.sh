#!/usr/bin/env bash
set -euo pipefail
echo "== genug – Setup (.deploy.env) =="

read -rp "FTP Host (z.B. ftpupload.net): " FTP_HOST
read -rp "FTP User: " FTP_USER
read -rsp "FTP Pass (wird nicht angezeigt): " FTP_PASS; echo
read -rp "Remote Dir (z.B. /htdocs/genug): " REMOTE_DIR

cat > .deploy.env <<ENV
FTP_HOST=${FTP_HOST}
FTP_USER=${FTP_USER}
FTP_PASS=${FTP_PASS}
REMOTE_DIR=${REMOTE_DIR}
ENV

echo "✅ .deploy.env geschrieben."
echo "Abhängigkeiten: lftp jq python  (Termux: pkg install lftp jq python)"
echo
echo "Los geht's:"
echo "  ./deploy.sh       # nur FTP"
echo "  ./deploy_git.sh   # FTP + Git Push"
