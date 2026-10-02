"""Devuelve los logs recientes usando el indice secundario global."""

import json
import os

import boto3
from boto3.dynamodb.conditions import Key

table = boto3.resource("dynamodb").Table(os.environ.get("TABLE_NAME", "Logs"))
index_name = os.environ.get("INDEX_NAME", "LogsByArrival")

DEFAULT_LIMIT = 10


def respond(status, body):
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body, default=str),
    }


def lambda_handler(event, context):
    # Desde API Gateway llega como ?top=N (texto); desde la consola como {"N": 10}
    qs = event.get("queryStringParameters") or {}
    requested_limit = qs.get("top", event.get("N", DEFAULT_LIMIT))

    if isinstance(requested_limit, bool):
        return respond(400, {"error": "top debe ser un entero positivo."})
    try:
        limit = int(requested_limit)
    except (TypeError, ValueError):
        return respond(400, {"error": "top debe ser un entero positivo."})
    if limit <= 0 or str(limit) != str(requested_limit).strip():
        return respond(400, {"error": "top debe ser un entero positivo."})

    response = table.query(
        IndexName=index_name,
        KeyConditionExpression=Key("gsi_pk").eq("LOG"),
        Limit=limit,
        ScanIndexForward=False,
    )
    return respond(200, {"logs": response.get("Items", [])})