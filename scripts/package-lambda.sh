# Empaqueta las Lambdas y conecta S3 -> start_workflow.
# En AWS Academy se usa LabRole.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REGION="${AWS_REGION:-$(aws configure get region 2>/dev/null || true)}"
REGION="${REGION:-us-east-1}"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
BUCKET="${BUCKET_NAME:-logging-$ACCOUNT_ID}"
ROLE_ARN="$(aws iam get-role --role-name LabRole --query 'Role.Arn' --output text)"
SM_ARN="arn:aws:states:${REGION}:${ACCOUNT_ID}:stateMachine:LogProcessing"

mkdir -p "$ROOT/build"

deploy() {
  local name=$1
  local zip_path="$ROOT/build/${name}.zip"
  python3 - "$zip_path" "$ROOT/src/${name}/lambda_function.py" <<'PY'
import sys, zipfile
from pathlib import Path
z, src = sys.argv[1], Path(sys.argv[2])
with zipfile.ZipFile(z, "w", zipfile.ZIP_DEFLATED) as zf:
    zf.write(src, src.name)
PY

  if aws lambda get-function --function-name "$name" --region "$REGION" >/dev/null 2>&1; then
    aws lambda update-function-code --function-name "$name" --zip-file "fileb://${zip_path}" --region "$REGION" >/dev/null
    aws lambda wait function-updated --function-name "$name" --region "$REGION"
  else
    aws lambda create-function \
      --function-name "$name" \
      --runtime python3.12 \
      --role "$ROLE_ARN" \
      --handler lambda_function.lambda_handler \
      --zip-file "fileb://${zip_path}" \
      --timeout 30 \
      --region "$REGION" >/dev/null
  fi
  echo "Lambda: $name"
}

deploy parse_batch
deploy classify_line
deploy write_log
deploy write_alert
deploy start_workflow

aws lambda update-function-configuration --function-name write_log \
  --environment "Variables={TABLE_NAME=Logs}" --region "$REGION" >/dev/null
aws lambda update-function-configuration --function-name write_alert \
  --environment "Variables={TABLE_NAME=SecurityAlerts}" --region "$REGION" >/dev/null

bash "$ROOT/scripts/create_state_machine.sh"

aws lambda update-function-configuration --function-name start_workflow \
  --environment "Variables={STATE_MACHINE_ARN=${SM_ARN}}" --region "$REGION" >/dev/null

aws lambda add-permission \
  --function-name start_workflow \
  --statement-id AllowS3Invoke \
  --action lambda:InvokeFunction \
  --principal s3.amazonaws.com \
  --source-arn "arn:aws:s3:::${BUCKET}" \
  --source-account "$ACCOUNT_ID" \
  --region "$REGION" >/dev/null 2>&1 || true

START_ARN="$(aws lambda get-function --function-name start_workflow --region "$REGION" --query 'Configuration.FunctionArn' --output text)"
aws s3api put-bucket-notification-configuration --bucket "$BUCKET" --notification-configuration "{
  \"LambdaFunctionConfigurations\": [{
    \"Id\": \"StartLogWorkflow\",
    \"LambdaFunctionArn\": \"${START_ARN}\",
    \"Events\": [\"s3:ObjectCreated:*\"],
    \"Filter\": {\"Key\": {\"FilterRules\": [
      {\"Name\":\"prefix\",\"Value\":\"input/\"},
      {\"Name\":\"suffix\",\"Value\":\".log\"}
    ]}}
  }]
}"

echo "Listo. s3://${BUCKET}/input/*.log -> LogProcessing -> Logs | SecurityAlerts"
