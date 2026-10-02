"""Descarga un batch de S3 y lo parte en lineas. No escribe a DynamoDB."""

import os
import re
import urllib.parse
from datetime import timezone

import boto3

PATTERN = re.compile(
    r"^(\w{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2})\s+(\S+)\s+([^\s\[]+)\[(\d+)\]:\s*(.*)$"
)

s3 = boto3.client("s3")


def iso_utc(dt):
    return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ")


def parse_line(line, batch, index, arrived_at):
    match = PATTERN.match(line)
    host = match.group(2) if match else "unknown"
    item = {
        "id": f"{batch}#{index:04d}",
        "host": host,
        "hostname": host,
        "sk": f"{batch}#{index:04d}",
        "batch": batch,
        "LastModified": arrived_at,
        "gsi_pk": "LOG",
    }
    if match:
        item.update(
            {
                "timestamp": match.group(1),
                "program": match.group(3),
                "pid": match.group(4),
                "log": match.group(5).rstrip(),
            }
        )
    else:
        item.update(
            {
                "timestamp": "",
                "program": "",
                "pid": "",
                "log": line.rstrip(),
            }
        )
    return item


def lambda_handler(event, context):
    bucket = event["bucket"]
    key = urllib.parse.unquote_plus(event["key"])
    batch = os.path.splitext(os.path.basename(key))[0]
    obj = s3.get_object(Bucket=bucket, Key=key)
    arrived_at = iso_utc(obj["LastModified"])
    body = obj["Body"].read().decode("utf-8", "replace")

    lines = []
    for i, line in enumerate(body.splitlines()):
        if line.strip():
            lines.append(parse_line(line, batch, i, arrived_at))
    return {"lines": lines}
