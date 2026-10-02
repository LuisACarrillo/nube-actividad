#!/usr/bin/env bash
# Borra el HTTP API LogsApi (lo llama teardown.sh)
set -uo pipefail

API_NAME="LogsApi"
REGION="$(aws configure get region || true)"
REGION="${REGION:-us-east-1}"

ids="$(aws apigatewayv2 get-apis --region "$REGION" \
  --query "Items[?Name=='$API_NAME'].ApiId" --output text)"

if [ -z "$ids" ] || [ "$ids" = "None" ]; then
  echo "No hay API $API_NAME que borrar"
else
  for id in $ids; do
    aws apigatewayv2 delete-api --api-id "$id" --region "$REGION"
    echo "API eliminado: $id"
  done
fi

rm -f api-url.txt
