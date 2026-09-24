# Crea o actualiza la Step Function LogProcessing.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REGION="${AWS_REGION:-$(aws configure get region 2>/dev/null || true)}"
REGION="${REGION:-us-east-1}"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
ROLE_ARN="$(aws iam get-role --role-name LabRole --query 'Role.Arn' --output text)"
SM_NAME="${STATE_MACHINE_NAME:-LogProcessing}"
DEF="$ROOT/scripts/state_machine.json"
SCRIPT="$ROOT/scripts/upsert_state_machine.py"

if creds="$(aws configure export-credentials --format env 2>/dev/null)"; then
  eval "$creds"
else
  AWS_ACCESS_KEY_ID="$(aws configure get aws_access_key_id)"
  AWS_SECRET_ACCESS_KEY="$(aws configure get aws_secret_access_key)"
  AWS_SESSION_TOKEN="$(aws configure get aws_session_token || true)"
fi

run_upsert() {
  local py=$1
  local script=$SCRIPT
  local def=$DEF
  if [[ "$py" == *python.exe ]]; then
    script="$(wslpath -w "$script")"
    def="$(wslpath -w "$def")"
  fi
  "$py" "$script" "$REGION" "$ACCOUNT_ID" "$ROLE_ARN" "$SM_NAME" "$def" \
    "$AWS_ACCESS_KEY_ID" "$AWS_SECRET_ACCESS_KEY" "${AWS_SESSION_TOKEN:-}"
}

if python3 -c "import boto3" 2>/dev/null; then
  run_upsert python3
  exit 0
fi

if command -v python.exe >/dev/null 2>&1 && python.exe -c "import boto3" 2>/dev/null; then
  run_upsert python.exe
  exit 0
fi

echo "No hay boto3. En WSL: sudo apt install -y python3-boto3" >&2
exit 1
