"""Devuelve las alertas de seguridad almacenadas en DynamoDB."""

import os

import boto3

table = boto3.resource("dynamodb").Table(
    os.environ.get("TABLE_NAME", "SecurityAlerts")
)


def lambda_handler(event, context):
    projection = "#id, #timestamp, #host, #log, #severity"
    names = {
        "#id": "id",
        "#timestamp": "timestamp",
        "#host": "host",
        "#log": "log",
        "#severity": "severity",
    }
    alerts = []
    scan_kwargs = {
        "ProjectionExpression": projection,
        "ExpressionAttributeNames": names,
    }

    while True:
        response = table.scan(**scan_kwargs)
        alerts.extend(response.get("Items", []))
        last_key = response.get("LastEvaluatedKey")
        if not last_key:
            break
        scan_kwargs["ExclusiveStartKey"] = last_key

    return {"alerts": alerts}
