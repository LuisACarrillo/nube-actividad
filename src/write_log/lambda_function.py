"""Guarda una linea normal en la tabla Logs."""

import os

import boto3

table = boto3.resource("dynamodb").Table(os.environ.get("TABLE_NAME", "Logs"))


def lambda_handler(event, context):
    table.put_item(
        Item={
            "pk": event["pk"],
            "sk": event["sk"],
            "gsi_pk": event.get("gsi_pk", "LOG"),
            "LastModified": event["LastModified"],
            "id": event.get("id") or event["sk"],
            "timestamp": event.get("timestamp", ""),
            "host": event.get("host") or event.get("hostname", ""),
            "log": event.get("log", ""),
            "severity": event.get("severity", "info"),
            "program": event.get("program", ""),
            "pid": event.get("pid", ""),
            "batch": event.get("batch", ""),
        }
    )
    return event
