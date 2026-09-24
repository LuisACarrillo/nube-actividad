"""S3 ObjectCreated -> inicia la Step Function."""

import json
import os
import urllib.parse

import boto3

sfn = boto3.client("stepfunctions")


def lambda_handler(event, context):
    arn = os.environ["STATE_MACHINE_ARN"]
    for rec in event.get("Records", []):
        key = urllib.parse.unquote_plus(rec["s3"]["object"]["key"])
        if not key.endswith(".log"):
            continue
        sfn.start_execution(
            stateMachineArn=arn,
            input=json.dumps(
                {
                    "bucket": rec["s3"]["bucket"]["name"],
                    "key": key,
                }
            ),
        )
