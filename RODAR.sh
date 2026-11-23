#!/bin/bash
# RODAR.sh - tudo num clique. Duplo clique -> "Executar no terminal".
cd "$(dirname "$(readlink -f "$0")")"

echo "============================================================"
echo "   CRACK BOOTSTRAPPER - LINUX / WINE"
echo "============================================================"
echo ""

# garante +x em tudo
chmod +x setup.sh run.sh triage.py 2>/dev/null

# setup so se o prefix nao existir
if [ ! -d "$HOME/.wine_crack" ]; then
  echo "[*] Primeira vez: rodando setup (vai pedir senha do sudo)..."
  echo ""
  ./setup.sh
  if [ $? -ne 0 ]; then
    echo ""
    echo "[!] setup falhou. Verifica a senha e tenta de novo."
    read -p "Enter pra sair..."
    exit 1
  fi
else
  echo "[*] Wine ja configurado (~/.wine_crack existe), pulando setup."
fi

echo ""
echo "============================================================"
echo "   Rodando o Bootstrapper no Wine com captura..."
echo "============================================================"
echo ""

./run.sh

echo ""
echo "============================================================"
echo "   TERMINOU. Abrindo a pasta do loot..."
echo "============================================================"
# abre a ultima pasta loot_* no gerenciador de arquivos
LAST=$(ls -td loot_* 2>/dev/null | head -1)
if [ -n "$LAST" ]; then
  xdg-open "$LAST" 2>/dev/null &
  xdg-open "$LAST/TRIAGE.md" 2>/dev/null &
fi
read -p "Enter pra fechar..."
