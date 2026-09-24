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

python3 -c "import boto3" 2>/dev/null || python3 -m pip install -q boto3
python3 - "$REGION" "$ACCOUNT_ID" "$SM_NAME" <<'PY' || true
import sys
import boto3
region, account, name = sys.argv[1], sys.argv[2], sys.argv[3]
arn = f"arn:aws:states:{region}:{account}:stateMachine:{name}"
try:
    boto3.client("stepfunctions", region_name=region).delete_state_machine(stateMachineArn=arn)
except Exception:
    pass
PY

for fn in start_workflow parse_batch classify_line write_log write_alert log-processing; do
  aws lambda delete-function --function-name "$fn" --region "$REGION" >/dev/null 2>&1 || true
done

aws s3 rb "s3://$BUCKET" --force >/dev/null 2>&1 || true
for table in Logs SecurityAlerts logging-logs; do
  aws dynamodb delete-table --table-name "$table" --region "$REGION" >/dev/null 2>&1 || true
done

rm -rf "$ROOT/batches" "$ROOT/build"
echo "Teardown listo."
