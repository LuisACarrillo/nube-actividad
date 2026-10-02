# Parte OpenSSH_2k.log en batches de ~1KB sin cortar lineas.
# Salida: batches/openssh-<timestamp>.log

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/data/OpenSSH_2k.log"
OUT="$ROOT/batches"
URL="https://raw.githubusercontent.com/logpai/loghub/master/OpenSSH/OpenSSH_2k.log"
LIMIT=1024

mkdir -p "$ROOT/data" "$OUT"
rm -f "$OUT"/openssh-*.log
[[ -f "$SRC" ]] || curl -fsSL "$URL" -o "$SRC"

ts=$(date +%s)
n=0
size=0
file=

open_batch() {
  while [[ -e "$OUT/openssh-$ts.log" ]]; do
    ts=$((ts + 1))
  done
  file="$OUT/openssh-$ts.log"
  : > "$file"
  ts=$((ts + 1))
  size=0
  n=$((n + 1))
}

echo "Partiendo $SRC en batches de ~$LIMIT bytes..."
open_batch
while IFS= read -r line || [[ -n $line ]]; do
  len=$(( ${#line} + 1 ))
  if (( size > 0 && size + len > LIMIT )); then
    open_batch
  fi
  printf '%s\n' "$line" >> "$file"
  size=$((size + len))
done < "$SRC"

echo "Generados $n archivos en $OUT"
