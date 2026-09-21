
import os
import re
import urllib.parse

import boto3

PATTERN = re.compile(
    r"^(\w{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2})\s+(\S+)\s+([^\s\[]+)\[(\d+)\]:\s*(.*)$"
)

s3 = boto3.client("s3")
table = boto3.resource("dynamodb").Table(os.environ.get("TABLE_NAME", "logging-logs"))


def parse_line(line):
    match = PATTERN.match(line)
    if not match:
        return None
    timestamp, hostname, program, pid, message = match.groups()
    return {
        "timestamp": timestamp,
        "hostname": hostname,
        "program": program,
        "pid": pid,
        "log": message.rstrip(),
    }


def lambda_handler(event, context):
    for rec in event["Records"]:
        bucket = rec["s3"]["bucket"]["name"]
        key = urllib.parse.unquote_plus(rec["s3"]["object"]["key"])
        if not key.endswith(".log"):
            continue

        body = s3.get_object(Bucket=bucket, Key=key)["Body"].read().decode("utf-8", "replace")
        batch = os.path.splitext(os.path.basename(key))[0]

        with table.batch_writer() as writer:
            for i, line in enumerate(body.splitlines()):
                if not line.strip():
                    continue
                item = parse_line(line)
                if not item:
                    continue
                item["pk"] = item["hostname"]
                item["sk"] = f"{batch}#{i:04d}"
                item["batch"] = batch
                writer.put_item(Item=item)
