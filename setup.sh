#!/bin/bash
# setup.sh - instala Wine + deps + ESCONDE Wine do VMProtect
set -e

echo "[*] Habilitando arquitetura i386..."
sudo dpkg --add-architecture i386
sudo apt update

echo "[*] Instalando Wine + ferramentas..."
sudo apt install -y --no-install-recommends \
  wine64 wine32 winetricks \
  tcpdump \
  xdotool wmctrl xclip \
  curl wget unzip \
  python3 \
  inotify-tools

export WINEPREFIX="$HOME/.wine_crack"
export WINEARCH=win64

echo "[*] Criando prefix limpo em $WINEPREFIX..."
rm -rf "$WINEPREFIX"
WINEPREFIX="$WINEPREFIX" wineboot -u
WINEPREFIX="$WINEPREFIX" wineserver -w

echo "[*] Apagando TODAS chaves 'Wine' que denunciam ambiente..."
cat > /tmp/hide_wine.reg <<'EOF'
REGEDIT4

[-HKEY_CURRENT_USER\Software\Wine]
[-HKEY_LOCAL_MACHINE\Software\Wine]

; renomeia produto pra parecer Win10 real
[HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion]
"ProductName"="Windows 10 Pro"
"CurrentBuildNumber"="19045"
"CurrentBuild"="19045"
"CurrentVersion"="6.3"
"BuildLabEx"="19041.1.amd64fre.vb_release.191206-1406"
"EditionID"="Professional"
"InstallationType"="Client"

; esconde flag de hypervisor em alguns checks
[HKEY_LOCAL_MACHINE\HARDWARE\DESCRIPTION\System]
"SystemBiosDate"="09/27/2019"
"SystemBiosVersion"=hex(7):41,00,53,00,55,00,53,00,00,00,00,00
"VideoBiosDate"="05/15/2019"
EOF
WINEPREFIX="$WINEPREFIX" wine regedit /tmp/hide_wine.reg
WINEPREFIX="$WINEPREFIX" wineserver -w
rm /tmp/hide_wine.reg

echo "[*] Instalando runtime libs (vcrun2019, d3dcompiler_47)..."
WINEPREFIX="$WINEPREFIX" winetricks -q vcrun2019 d3dcompiler_47 || true

echo ""
echo "[OK] Setup pronto."
echo "    Prefix: $WINEPREFIX"
