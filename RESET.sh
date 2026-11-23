#!/bin/bash
# RESET.sh - apaga prefix quebrado, recria limpo, roda tudo de novo.
cd "$(dirname "$(readlink -f "$0")")"

echo "============================================================"
echo "   RESET - apagando prefix quebrado e recriando"
echo "============================================================"
echo ""

# mata qualquer wine orfao
wineserver -k 2>/dev/null
pkill -9 -f wine 2>/dev/null
sleep 2

# apaga o prefix
echo "[*] Apagando ~/.wine_crack..."
rm -rf "$HOME/.wine_crack"

# garante +x
chmod +x setup.sh run.sh triage.py 2>/dev/null

# roda setup de novo
echo "[*] Rodando setup limpo..."
./setup.sh
if [ $? -ne 0 ]; then
  echo "[!] setup falhou. Olha os erros acima."
  read -p "Enter pra sair..."
  exit 1
fi

# instala deps extras que o Bootstrapper pode precisar
echo ""
echo "[*] Instalando libs extras (dotnet48, vcrun, d3d)..."
export WINEPREFIX="$HOME/.wine_crack"
WINEPREFIX="$WINEPREFIX" winetricks -q --force vcrun2019 d3dcompiler_47 2>&1 | tail -20

echo ""
echo "[*] Testando prefix..."
WINEPREFIX="$WINEPREFIX" wine cmd /c "echo WINE_OK" 2>&1 | head -5

echo ""
echo "============================================================"
echo "   Rodando o Bootstrapper agora..."
echo "============================================================"
./run.sh

LAST=$(ls -td loot_* 2>/dev/null | head -1)
if [ -n "$LAST" ]; then
  xdg-open "$LAST" 2>/dev/null &
  xdg-open "$LAST/TRIAGE.md" 2>/dev/null &
fi
read -p "Enter pra fechar..."
