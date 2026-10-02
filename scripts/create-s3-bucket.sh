# Crea el bucket S3 y las tablas Logs (con GSI) y SecurityAlerts.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REGION="${AWS_REGION:-$(aws configure get region 2>/dev/null || true)}"
REGION="${REGION:-us-east-1}"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
BUCKET="${BUCKET_NAME:-logging-$ACCOUNT_ID}"

ensure_table() {
  local name=$1
  if aws dynamodb describe-table --table-name "$name" --region "$REGION" >/dev/null 2>&1; then
    echo "La tabla $name ya existe."
    return
  fi
  aws dynamodb create-table \
    --table-name "$name" \
    --attribute-definitions AttributeName=pk,AttributeType=S AttributeName=sk,AttributeType=S \
    --key-schema AttributeName=pk,KeyType=HASH AttributeName=sk,KeyType=RANGE \
    --billing-mode PAY_PER_REQUEST \
    --region "$REGION" >/dev/null
  aws dynamodb wait table-exists --table-name "$name" --region "$REGION"
  echo "Tabla creada: $name"
}

if aws dynamodb describe-table --table-name Logs --region "$REGION" >/dev/null 2>&1; then
  echo "La tabla Logs ya existe."
else
  aws dynamodb create-table \
    --cli-input-json "file://${ROOT}/scripts/logs-table.json" \
    --region "$REGION" >/dev/null
  aws dynamodb wait table-exists --table-name Logs --region "$REGION"
  echo "Tabla creada: Logs"
fi

aws s3 mb "s3://$BUCKET" --region "$REGION" 2>/dev/null || true
aws s3api put-object --bucket "$BUCKET" --key "input/" >/dev/null
ensure_table SecurityAlerts

echo "Listo. s3://$BUCKET/input/  Logs + SecurityAlerts"
