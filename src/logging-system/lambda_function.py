
import csv
import io
import os
import re
import urllib.parse

import boto3

PATTERN = re.compile(
    r"^(\w{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2})\s+(\S+)\s+([^\s\[]+)\[(\d+)\]:\s*(.*)$"
)

s3 = boto3.client("s3")


def to_csv(text):
    buf = io.StringIO()
    writer = csv.writer(buf, lineterminator="\n")
    writer.writerow(["timestamp", "hostname", "program", "pid", "log"])
    for line in text.splitlines():
        if not line.strip():
            continue
        match = PATTERN.match(line)
        writer.writerow(list(match.groups()) if match else ["", "", "", "", line])
    return buf.getvalue()


def lambda_handler(event, context):
    for rec in event["Records"]:
        bucket = rec["s3"]["bucket"]["name"]
        key = urllib.parse.unquote_plus(rec["s3"]["object"]["key"])
        if not key.endswith(".log"):
            continue
        body = s3.get_object(Bucket=bucket, Key=key)["Body"].read().decode("utf-8", "replace")
        name = os.path.splitext(os.path.basename(key))[0]
        s3.put_object(
            Bucket=bucket,
            Key=f"output/{name}.csv",
            Body=to_csv(body),
            ContentType="text/csv",
        )
