#!/bin/bash
# run.sh - roda o Bootstrapper no Wine STEALTH (sem strace/ptrace)
# Captura via inotifywait + tcpdump + snapshot periodico do prefix.
#
# Uso: ./run.sh [/caminho/Bootstrapper.exe] [KEY]

set -u
cd "$(dirname "$(readlink -f "$0")")"
BOOT="${1:-}"
KEY="${2:-2yIBvxa2mmYgdzu9j3azZbwRIq41ZHrE}"

if [ -z "$BOOT" ] || [ ! -f "$BOOT" ]; then
  for cand in \
    "./Bootstrapper.exe" \
    "../Bootstrapper.exe" \
    "$HOME/Desktop/Bootstrapper.exe" \
    "$HOME/Downloads/Bootstrapper.exe" \
    "$HOME/Bootstrapper.exe"; do
    if [ -f "$cand" ]; then BOOT="$(readlink -f "$cand")"; echo "[*] Bootstrapper achado em $BOOT"; break; fi
  done
fi
if [ -z "$BOOT" ] || [ ! -f "$BOOT" ]; then
  echo "ERRO: Bootstrapper.exe nao achado"; read -p "Enter..."; exit 1
fi

export WINEPREFIX="$HOME/.wine_crack"
export WINEDEBUG=-all

LOOT="$(pwd)/loot_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$LOOT"/{files,net,logs,snapshots}
echo "[*] Loot: $LOOT"

# -----------------------------------------------------------------------------
# apaga qualquer coisa deixada de rodadas anteriores
# -----------------------------------------------------------------------------
wineserver -k 2>/dev/null
sleep 1

# -----------------------------------------------------------------------------
# baseline
# -----------------------------------------------------------------------------
WATCH_PATHS=(
  "$WINEPREFIX/drive_c/users"
  "$WINEPREFIX/drive_c/ProgramData"
  "$WINEPREFIX/drive_c/Program Files"
  "$WINEPREFIX/drive_c/Program Files (x86)"
  "$WINEPREFIX/drive_c/windows/temp"
  "/tmp"
)
BASE="$LOOT/logs/baseline.txt"
for p in "${WATCH_PATHS[@]}"; do
  find "$p" -type f -printf "%T@ %s %p\n" 2>/dev/null >> "$BASE"
done
echo "[*] Baseline: $(wc -l < "$BASE") arquivos"

# -----------------------------------------------------------------------------
# tcpdump em background
# -----------------------------------------------------------------------------
IFACE=$(ip route | awk '/default/ {print $5; exit}')
echo "[*] tcpdump na interface $IFACE..."
sudo -b tcpdump -i "$IFACE" -s0 -w "$LOOT/net/capture.pcap" \
  'tcp or udp port 53 or tcp port 80 or tcp port 443 or tcp portrange 1024-65535' \
  >/dev/null 2>&1 &
sleep 1

# -----------------------------------------------------------------------------
# inotifywait em background pra cada pasta
# -----------------------------------------------------------------------------
INOTIFY_PIDS=()
for p in "${WATCH_PATHS[@]}"; do
  [ -d "$p" ] || continue
  (
    inotifywait -m -r -e close_write,create,moved_to --format '%w%f' "$p" 2>/dev/null |
    while read -r file; do
      [ -f "$file" ] || continue
      sz=$(stat -c%s "$file" 2>/dev/null || echo 0)
      [ "$sz" -gt 100 ] && [ "$sz" -lt 200000000 ] || continue
      safe=$(echo "$file" | tr '/' '_' | tr ' ' '_')
      cp -f "$file" "$LOOT/files/$safe" 2>/dev/null
      echo "$(date +%T) $file ($sz)" >> "$LOOT/logs/fs.log"
    done
  ) &
  INOTIFY_PIDS+=($!)
done

# -----------------------------------------------------------------------------
# auto-cola key quando janela aparecer
# -----------------------------------------------------------------------------
(
  for i in $(seq 1 60); do
    sleep 1
    WID=$(xdotool search --name "Bootstrapper\|Bootstrap\|Loader\|Login\|License\|Launcher\|Key" 2>/dev/null | head -1)
    if [ -n "$WID" ]; then
      sleep 2
      xdotool windowactivate --sync "$WID" 2>/dev/null
      echo -n "$KEY" | xclip -selection clipboard 2>/dev/null
      xdotool key --window "$WID" ctrl+v 2>/dev/null
      sleep 0.5
      xdotool key --window "$WID" Return 2>/dev/null
      echo "[*] Key colada (wid=$WID)" >> "$LOOT/logs/autotype.log"
      break
    fi
  done
) &

# -----------------------------------------------------------------------------
# SEM STRACE - roda o Bootstrapper direto via wine
# -----------------------------------------------------------------------------
echo "[*] Rodando Bootstrapper via Wine (modo stealth, sem ptrace)..."
echo "    Fecha a janela do Bootstrapper quando o hack estiver carregado."
echo "    Limite: 10 minutos."

timeout 600 wine "$BOOT" > "$LOOT/logs/wine_stdout.log" 2> "$LOOT/logs/wine_stderr.log" &
WINE_PID=$!

# snapshot periodico do prefix a cada 15s enquanto roda
(
  n=0
  while kill -0 $WINE_PID 2>/dev/null; do
    sleep 15
    n=$((n+1))
    snap="$LOOT/snapshots/snap_$n.txt"
    find "$WINEPREFIX/drive_c" -type f -newer "$BASE" -printf "%T@ %s %p\n" 2>/dev/null > "$snap"
    # copia arquivos novos tb
    while IFS= read -r line; do
      path=$(echo "$line" | awk '{for(i=3;i<=NF;i++) printf "%s%s",$i,(i<NF?" ":"")}')
      [ -f "$path" ] || continue
      safe=$(echo "$path" | tr '/' '_' | tr ' ' '_')
      [ ! -f "$LOOT/files/$safe" ] && cp -f "$path" "$LOOT/files/$safe" 2>/dev/null
    done < "$snap"
  done
) &
SNAP_PID=$!

wait $WINE_PID 2>/dev/null
echo "[*] Wine terminou. Ultimo sweep em 5s..."
sleep 5

# cleanup
kill $SNAP_PID 2>/dev/null
for pid in "${INOTIFY_PIDS[@]}"; do kill $pid 2>/dev/null; done
pkill -f "inotifywait" 2>/dev/null
sudo pkill tcpdump 2>/dev/null
wineserver -k 2>/dev/null

# sweep final
for p in "${WATCH_PATHS[@]}"; do
  find "$p" -type f -printf "%T@ %s %p\n" 2>/dev/null
done > "$LOOT/logs/final.txt"
comm -13 <(sort "$BASE") <(sort "$LOOT/logs/final.txt") > "$LOOT/logs/new_files.txt"
echo "[*] Arquivos novos totais: $(wc -l < "$LOOT/logs/new_files.txt")"

while IFS= read -r line; do
  path=$(echo "$line" | awk '{for(i=3;i<=NF;i++) printf "%s%s",$i,(i<NF?" ":"")}')
  [ -f "$path" ] || continue
  safe=$(echo "$path" | tr '/' '_' | tr ' ' '_')
  [ ! -f "$LOOT/files/$safe" ] && cp -f "$path" "$LOOT/files/$safe" 2>/dev/null
done < "$LOOT/logs/new_files.txt"

# triage
python3 "$(dirname "$0")/triage.py" "$LOOT"

echo ""
echo "============================================================"
echo "   TUDO EM: $LOOT"
echo "   Veja: $LOOT/TRIAGE.md"
echo "============================================================"
