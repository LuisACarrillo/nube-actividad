"""Descarga un batch de S3 y lo parte en lineas. No escribe a DynamoDB."""

import os
import re
import urllib.parse

import boto3

PATTERN = re.compile(
    r"^(\w{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2})\s+(\S+)\s+([^\s\[]+)\[(\d+)\]:\s*(.*)$"
)

s3 = boto3.client("s3")


def parse_line(line, batch, index):
    match = PATTERN.match(line)
    if match:
        timestamp, hostname, program, pid, message = match.groups()
        return {
            "timestamp": timestamp,
            "hostname": hostname,
            "program": program,
            "pid": pid,
            "log": message.rstrip(),
            "batch": batch,
            "sk": f"{batch}#{index:04d}",
        }
    return {
        "timestamp": "",
        "hostname": "unknown",
        "program": "",
        "pid": "",
        "log": line.rstrip(),
        "batch": batch,
        "sk": f"{batch}#{index:04d}",
    }


def lambda_handler(event, context):
    bucket = event["bucket"]
    key = urllib.parse.unquote_plus(event["key"])
    batch = os.path.splitext(os.path.basename(key))[0]
    body = s3.get_object(Bucket=bucket, Key=key)["Body"].read().decode("utf-8", "replace")

    lines = []
    for i, line in enumerate(body.splitlines()):
        if line.strip():
            lines.append(parse_line(line, batch, i))
    return {"lines": lines}
