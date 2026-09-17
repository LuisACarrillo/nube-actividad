# Sube batches/openssh-*.log a s3://<bucket>/input/ con N segundos entre cada uno.

set -euo pipefail

DELAY="${1:?Uso: $0 <segundos>}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
BUCKET="${BUCKET_NAME:-logging-$ACCOUNT_ID}"

shopt -s nullglob
files=("$ROOT"/batches/openssh-*.log)
((${#files[@]})) || { echo "No hay batches. Corre ./scripts/split-log.sh" >&2; exit 1; }

echo "Subiendo ${#files[@]} archivos a s3://$BUCKET/input/ (pausa ${DELAY}s)"
for f in "${files[@]}"; do
  aws s3 cp "$f" "s3://$BUCKET/input/"
  sleep "$DELAY"
done
echo "Listo."
