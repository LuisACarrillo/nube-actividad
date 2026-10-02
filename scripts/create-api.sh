#!/usr/bin/env bash
# Crea el HTTP API (API Gateway v2) con:
#   GET /alerts -> Lambda get_alerts
#   GET /logs   -> Lambda get_logs   (se usa como /logs?top=N)
# Si el API ya existe lo borra y lo vuelve a crear, asi se puede correr varias veces.
set -euo pipefail

API_NAME="LogsApi"
REGION="$(aws configure get region || true)"
REGION="${REGION:-us-east-1}"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"

# Borrar API previo con el mismo nombre (si existe)
for old in $(aws apigatewayv2 get-apis --region "$REGION" \
    --query "Items[?Name=='$API_NAME'].ApiId" --output text); do
  aws apigatewayv2 delete-api --api-id "$old" --region "$REGION"
  echo "API anterior eliminado: $old"
done

API_ID="$(aws apigatewayv2 create-api \
  --name "$API_NAME" \
  --protocol-type HTTP \
  --region "$REGION" \
  --query ApiId --output text)"
echo "HTTP API creado: $API_ID"

add_route() {
  local route_key="$1"
  local fn="$2"
  local fn_arn="arn:aws:lambda:$REGION:$ACCOUNT_ID:function:$fn"

  local integ_id
  integ_id="$(aws apigatewayv2 create-integration \
    --api-id "$API_ID" \
    --integration-type AWS_PROXY \
    --integration-uri "$fn_arn" \
    --payload-format-version 2.0 \
    --region "$REGION" \
    --query IntegrationId --output text)"

  aws apigatewayv2 create-route \
    --api-id "$API_ID" \
    --route-key "$route_key" \
    --target "integrations/$integ_id" \
    --region "$REGION" >/dev/null

  # Permiso para que API Gateway pueda invocar la Lambda
  aws lambda remove-permission --function-name "$fn" \
    --statement-id "apigw-$fn" --region "$REGION" >/dev/null 2>&1 || true
  aws lambda add-permission \
    --function-name "$fn" \
    --statement-id "apigw-$fn" \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:$REGION:$ACCOUNT_ID:$API_ID/*/*" \
    --region "$REGION" >/dev/null

  echo "Ruta: $route_key -> $fn"
}

add_route "GET /alerts" "get_alerts"
add_route "GET /logs"   "get_logs"

# Stage $default con auto-deploy (no hace falta hacer deploy a mano)
aws apigatewayv2 create-stage \
  --api-id "$API_ID" \
  --stage-name '$default' \
  --auto-deploy \
  --region "$REGION" >/dev/null

URL="https://$API_ID.execute-api.$REGION.amazonaws.com"
echo "$URL" > api-url.txt

echo
echo "Listo. URLs:"
echo "  $URL/alerts"
echo "  $URL/logs?top=10"
echo "(guardado en api-url.txt)"
