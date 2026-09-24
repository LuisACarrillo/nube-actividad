"""Guarda una linea sospechosa en SecurityAlerts."""

import os

import boto3

table = boto3.resource("dynamodb").Table(os.environ.get("TABLE_NAME", "SecurityAlerts"))


def lambda_handler(event, context):
    table.put_item(
        Item={
            "pk": event["pk"],
            "sk": event["sk"],
            "timestamp": event.get("timestamp", ""),
            "hostname": event.get("hostname", ""),
            "program": event.get("program", ""),
            "pid": event.get("pid", ""),
            "log": event.get("log", ""),
            "batch": event.get("batch", ""),
        }
    )
    return event
