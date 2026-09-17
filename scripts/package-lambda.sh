# Empaqueta la Lambda y conecta el trigger S3 input/*.log -> output/*.csv

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REGION="${AWS_REGION:-$(aws configure get region 2>/dev/null || true)}"
REGION="${REGION:-us-east-1}"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
BUCKET="${BUCKET_NAME:-logging-$ACCOUNT_ID}"
FN="${LAMBDA_NAME:-log-processing}"
ROLE="${LAMBDA_ROLE_NAME:-LabRole}"
ZIP="$ROOT/build/lambda.zip"
ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE}"

mkdir -p "$ROOT/build"
rm -f "$ZIP"
python3 - "$ZIP" "$ROOT/src/logging-system/lambda_function.py" <<'PY'
import sys
import zipfile
from pathlib import Path

zip_path, src = sys.argv[1], Path(sys.argv[2])
with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
    zf.write(src, src.name)
PY

if aws lambda get-function --function-name "$FN" --region "$REGION" >/dev/null 2>&1; then
  aws lambda update-function-code --function-name "$FN" --zip-file "fileb://$ZIP" --region "$REGION" >/dev/null
else
  aws lambda create-function \
    --function-name "$FN" \
    --runtime python3.12 \
    --role "$ROLE_ARN" \
    --handler lambda_function.lambda_handler \
    --zip-file "fileb://$ZIP" \
    --timeout 30 \
    --region "$REGION" >/dev/null
fi

aws lambda add-permission \
  --function-name "$FN" \
  --statement-id AllowS3Invoke \
  --action lambda:InvokeFunction \
  --principal s3.amazonaws.com \
  --source-arn "arn:aws:s3:::${BUCKET}" \
  --source-account "$ACCOUNT_ID" \
  --region "$REGION" >/dev/null 2>&1 || true

ARN="$(aws lambda get-function --function-name "$FN" --region "$REGION" --query Configuration.FunctionArn --output text)"
aws s3api put-bucket-notification-configuration --bucket "$BUCKET" --notification-configuration "{
  \"LambdaFunctionConfigurations\": [{
    \"Id\": \"ProcessLogBatches\",
    \"LambdaFunctionArn\": \"$ARN\",
    \"Events\": [\"s3:ObjectCreated:*\"],
    \"Filter\": {\"Key\": {\"FilterRules\": [
      {\"Name\":\"prefix\",\"Value\":\"input/\"},
      {\"Name\":\"suffix\",\"Value\":\".log\"}
    ]}}
  }]
}"

echo "Listo. $FN (rol $ROLE) <- s3://$BUCKET/input/*.log -> s3://$BUCKET/output/"
