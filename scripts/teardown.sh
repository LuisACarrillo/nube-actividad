
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REGION="${AWS_REGION:-$(aws configure get region 2>/dev/null || true)}"
REGION="${REGION:-us-east-1}"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
BUCKET="${BUCKET_NAME:-logging-$ACCOUNT_ID}"
FN="${LAMBDA_NAME:-log-processing}"

aws s3api put-bucket-notification-configuration \
  --bucket "$BUCKET" \
  --notification-configuration '{}' >/dev/null 2>&1 || true

aws lambda delete-function --function-name "$FN" --region "$REGION" >/dev/null 2>&1 || true
aws s3 rb "s3://$BUCKET" --force >/dev/null 2>&1 || true

rm -rf "$ROOT/batches" "$ROOT/build"

echo "Teardown listo."
