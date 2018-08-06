echo "Creating 2 buckets: "
aws s3 mb s3://crr-buck1 --region='us-east-1'
aws s3 mb s3://crr-buck2 --region='us-east-1'
echo "Enablining Versioning: "
aws s3api put-bucket-versioning --bucket crr-buck1 --versioning-configuration Status=Enabled
aws s3api put-bucket-versioning --bucket crr-buck2 --versioning-configuration Status=Enabled
echo "import boto3
import json
import time
s3 = boto3.client('s3')
iam = boto3.client('iam')
AMI = 'ami-b70554c8'
INSTANCE_TYPE = 't2.micro' 
EC2 = boto3.client('ec2', region_name='us-east-1')
def lambda_handler(event, context):
    source_bucket = event['Records'][0]['s3']['bucket']['name']
    key = event['Records'][0]['s3']['object']['key']
    eventName = event['Records'][0]['eventName']
    copy_source = {'Bucket':source_bucket, 'Key':key}
    target_bucket = 'crr-buck2'
    if eventName == 'ObjectCreated:Put':
        size = event['Records'][0]['s3']['object']['size']
        if int(size) <= 500000000 : 
            print (\"Using lambda for compying..... \")
            s3.copy_object(Bucket=target_bucket, Key=key, CopySource=copy_source)
        else :
            print(\"inside else of create\")
            #use ec2 instance
    if eventName == 'ObjectRemoved:DeleteMarkerCreated':
        s3.delete_object(Bucket=target_bucket, Key=key)
    return \"Hello\"" > mylambda.py

zip $myzip.zip mylambda.py

echo "creating function"
temp=$(aws lambda create-function --function-name lambda-crr --runtime python3.6 --role arn:aws:iam::488599217855:role/FullAccess --handler copylambda.lambda_handler --zip-file fileb://$myzip.zip --timeout 300 --region us-east-1)

echo "Lambda Created"
echo "Adding Permissions"
temp=$(aws lambda add-permission --function-name lambda-crr --region us-east-1 --statement-id "1" --action "lambda:InvokeFunction" --principal s3.amazonaws.com --source-arn arn:aws:s3:::crr-buck1)

arn=$(aws lambda get-function-configuration --function-name lambda-crr --region us-east-1 --query "FunctionArn" --output text)
echo "{
  \"LambdaFunctionConfigurations\": [
    {
      \"LambdaFunctionArn\":"\""$arn"\"",
      \"Events\": [\"s3:ObjectCreated:*\"]
    },
    {
      \"LambdaFunctionArn\":"\""$arn"\"",
      \"Events\": [\"s3:ObjectRemoved:*\"]
    }
  ]
}" > mynoti.json 

echo "Adding trigger....."
aws s3api put-bucket-notification-configuration --bucket crr-buck1 --notification-configuration file://mynoti.json

rm mynoti.json $myzip.zip copylambda.py
