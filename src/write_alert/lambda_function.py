"""Guarda una linea sospechosa en SecurityAlerts."""

import os

import boto3

table = boto3.resource("dynamodb").Table(os.environ.get("TABLE_NAME", "SecurityAlerts"))


def lambda_handler(event, context):
    table.put_item(
        Item={
            "pk": event["pk"],
            "sk": event["sk"],
            "id": event.get("id") or event["sk"],
            "timestamp": event.get("timestamp", ""),
            "host": event.get("host") or event.get("hostname", ""),
            "log": event.get("log", ""),
            "severity": event.get("severity", "high"),
            "LastModified": event.get("LastModified", ""),
            "batch": event.get("batch", ""),
        }
    )
    return event
