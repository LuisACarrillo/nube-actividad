# Crea el bucket S3 y las carpetas input/ y output/.

set -euo pipefail

REGION="${AWS_REGION:-$(aws configure get region 2>/dev/null || true)}"
REGION="${REGION:-us-east-1}"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
BUCKET="${BUCKET_NAME:-logging-$ACCOUNT_ID}"

aws s3 mb "s3://$BUCKET" --region "$REGION" 2>/dev/null || true
aws s3api put-object --bucket "$BUCKET" --key "input/" >/dev/null
aws s3api put-object --bucket "$BUCKET" --key "output/" >/dev/null

echo "Listo."
echo "  s3://$BUCKET/input/"
echo "  s3://$BUCKET/output/"
