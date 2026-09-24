"""Crea o actualiza la Step Function LogProcessing."""

import sys
from pathlib import Path

import boto3
from botocore.exceptions import ClientError

region, account, role, name, def_path, key, secret, token = sys.argv[1:9]
definition = Path(def_path).read_text(encoding="utf-8")
definition = definition.replace("$AWS_ACCOUNT", account).replace("$AWS_REGION", region)
arn = f"arn:aws:states:{region}:{account}:stateMachine:{name}"

sfn = boto3.client(
    "stepfunctions",
    region_name=region,
    aws_access_key_id=key,
    aws_secret_access_key=secret,
    aws_session_token=token or None,
)

try:
    sfn.describe_state_machine(stateMachineArn=arn)
    sfn.update_state_machine(stateMachineArn=arn, definition=definition)
    print(f"Step Function actualizada: {arn}")
except ClientError as exc:
    if exc.response["Error"]["Code"] != "StateMachineDoesNotExist":
        raise
    out = sfn.create_state_machine(
        name=name, definition=definition, roleArn=role, type="STANDARD"
    )
    print(f"Step Function creada: {out['stateMachineArn']}")
