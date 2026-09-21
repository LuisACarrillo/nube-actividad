# Crea el bucket S3 (input/) y la tabla DynamoDB.

set -euo pipefail

REGION="${AWS_REGION:-$(aws configure get region 2>/dev/null || true)}"
REGION="${REGION:-us-east-1}"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
BUCKET="${BUCKET_NAME:-logging-$ACCOUNT_ID}"
TABLE="${TABLE_NAME:-logging-logs}"

aws s3 mb "s3://$BUCKET" --region "$REGION" 2>/dev/null || true
aws s3api put-object --bucket "$BUCKET" --key "input/" >/dev/null

if aws dynamodb describe-table --table-name "$TABLE" --region "$REGION" >/dev/null 2>&1; then
  echo "La tabla $TABLE ya existe."
else
  aws dynamodb create-table \
    --table-name "$TABLE" \
    --attribute-definitions AttributeName=pk,AttributeType=S AttributeName=sk,AttributeType=S \
    --key-schema AttributeName=pk,KeyType=HASH AttributeName=sk,KeyType=RANGE \
    --billing-mode PAY_PER_REQUEST \
    --region "$REGION" >/dev/null
  aws dynamodb wait table-exists --table-name "$TABLE" --region "$REGION"
  echo "Tabla creada: $TABLE"
fi

echo "Listo."
echo "  s3://$BUCKET/input/"
echo "  dynamodb: $TABLE (pk=hostname, sk=batch#line)"
