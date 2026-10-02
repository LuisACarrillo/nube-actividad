"""Devuelve los logs recientes usando el indice secundario global."""

import os

import boto3
from boto3.dynamodb.conditions import Key

table = boto3.resource("dynamodb").Table(os.environ.get("TABLE_NAME", "Logs"))
index_name = os.environ.get("INDEX_NAME", "LogsByArrival")


def lambda_handler(event, context):
    requested_limit = event.get("N")
    if isinstance(requested_limit, bool) or requested_limit is None:
        raise ValueError("El evento debe incluir N como entero positivo.")
    try:
        limit = int(requested_limit)
    except (TypeError, ValueError) as error:
        raise ValueError("N debe ser un entero positivo.") from error
    if limit <= 0 or str(limit) != str(requested_limit).strip():
        raise ValueError("N debe ser un entero positivo.")

    response = table.query(
        IndexName=index_name,
        KeyConditionExpression=Key("gsi_pk").eq("LOG"),
        Limit=limit,
        ScanIndexForward=False,
    )
    return {"logs": response.get("Items", [])}
