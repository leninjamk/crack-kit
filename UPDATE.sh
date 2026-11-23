#!/bin/bash
# UPDATE.sh - puxa a versao mais nova do kit do GitHub
# Rodar sempre que eu dizer "atualizei o kit" - um clique e pronto.
cd "$(dirname "$(readlink -f "$0")")"
source ./config.sh

if [ "$GITHUB_USER" = "SEU_USUARIO_AQUI" ]; then
  echo "[!] Edita config.sh primeiro (botao direito -> Open With Text Editor)"
  read -p "Enter..."; exit 1
fi

# instala git se precisar
command -v git >/dev/null || sudo apt install -y git

git config --global user.name "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"
git config --global --add safe.directory "$(pwd)"

REMOTE="https://${GITHUB_TOKEN}@github.com/${GITHUB_USER}/${GITHUB_REPO}.git"

if [ ! -d ".git" ]; then
  echo "[*] Primeira vez - inicializando repo local..."
  git init
  git remote add origin "$REMOTE" 2>/dev/null || git remote set-url origin "$REMOTE"
  git fetch origin
  git checkout -t origin/main 2>/dev/null || git reset --hard origin/main
else
  git remote set-url origin "$REMOTE"
  echo "[*] git pull..."
  git fetch origin
  git reset --hard origin/main
fi

chmod +x *.sh *.py 2>/dev/null

echo ""
echo "[OK] Kit atualizado. Agora roda RESET.sh ou RODAR.sh"
read -p "Enter pra fechar..."
