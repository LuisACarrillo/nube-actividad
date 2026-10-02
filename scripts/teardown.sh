# Borra Step Function, Lambdas, bucket, tablas y archivos locales. No toca LabRole.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REGION="${AWS_REGION:-$(aws configure get region 2>/dev/null || true)}"
REGION="${REGION:-us-east-1}"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
BUCKET="${BUCKET_NAME:-logging-$ACCOUNT_ID}"
SM_NAME="${STATE_MACHINE_NAME:-LogProcessing}"

aws s3api put-bucket-notification-configuration \
  --bucket "$BUCKET" \
  --notification-configuration '{}' >/dev/null 2>&1 || true

if creds="$(aws configure export-credentials --format env 2>/dev/null)"; then
  eval "$creds"
else
  AWS_ACCESS_KEY_ID="$(aws configure get aws_access_key_id || true)"
  AWS_SECRET_ACCESS_KEY="$(aws configure get aws_secret_access_key || true)"
  AWS_SESSION_TOKEN="$(aws configure get aws_session_token || true)"
fi

delete_sm() {
  local py=$1
  "$py" - "$REGION" "$ACCOUNT_ID" "$SM_NAME" \
    "${AWS_ACCESS_KEY_ID:-}" "${AWS_SECRET_ACCESS_KEY:-}" "${AWS_SESSION_TOKEN:-}" <<'PY' || true
import sys
import boto3
region, account, name, key, secret, token = sys.argv[1:7]
arn = f"arn:aws:states:{region}:{account}:stateMachine:{name}"
kwargs = {"region_name": region}
if key and secret:
    kwargs.update(
        aws_access_key_id=key,
        aws_secret_access_key=secret,
        aws_session_token=token or None,
    )
try:
    boto3.client("stepfunctions", **kwargs).delete_state_machine(stateMachineArn=arn)
except Exception:
    pass
PY
}

if python3 -c "import boto3" 2>/dev/null; then
  delete_sm python3
elif command -v python.exe >/dev/null 2>&1 && python.exe -c "import boto3" 2>/dev/null; then
  delete_sm python.exe
fi

for fn in start_workflow parse_batch classify_line write_log write_alert log-processing; do
  aws lambda delete-function --function-name "$fn" --region "$REGION" >/dev/null 2>&1 || true
done

aws s3 rb "s3://$BUCKET" --force >/dev/null 2>&1 || true
for table in Logs SecurityAlerts logging-logs; do
  aws dynamodb delete-table --table-name "$table" --region "$REGION" >/dev/null 2>&1 || true
done

rm -rf "$ROOT/batches" "$ROOT/build"
echo "Teardown listo."
"$(dirname "$0")/delete-api.sh"
