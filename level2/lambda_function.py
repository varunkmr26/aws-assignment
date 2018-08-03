import subprocess
import boto3


def lambda_handler(event, context):
    command = ["./aws", "s3", "sync", "s3://varun-pe-source", "s3://varun-pe-destination"]
    print(subprocess.check_output(command, stderr=subprocess.STDOUT))
