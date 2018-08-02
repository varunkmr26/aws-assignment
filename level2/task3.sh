#!/bin/bash

#Create the lambda function
aws lambda create-function --function-name varun-pe-shell-function \
--runtime python3.6 --role arn:aws:iam::488599217855:role/varun_pe_assignment1 \
--handler lambda_function.lambda_handler \
--code S3Bucket="varun-pe-bucket",S3Key="function.zip" \
--memory-size 512 \
--timeout 300 \
--region us-east-1

#Get the ARN of the function
arn=`aws lambda get-function --function-name varun-pe-shell-function --region us-east-1 --query Configuration.FunctionArn`
#Add permission to trigger the function
aws lambda add-permission --function-name varun-pe-shell-function \
--statement-id varun-kuch-bhi \
--action "lambda:*" \
--principal s3.amazonaws.com \
--source-arn "arn:aws:s3:::varun-pe-bucket" \
--region us-east-1

#Generate a json for notification configuration
json="{
  \"LambdaFunctionConfigurations\": [
    {
     \"Id\": \"varun-pe-kuchbhi\",
      \"LambdaFunctionArn\": "$arn",
      \"Events\": [\"s3:ObjectCreated:*\"],
	  \"Filter\": {
          \"Key\": {
          \"FilterRules\": [
            {
              \"Name\": \"prefix\",
              \"Value\": \"images/\"
            }
          ]
        }
      }
    }
  ]
}"

echo $json > notification.json

#Create a notification configuration in S3 bucket
aws s3api put-bucket-notification-configuration \
--bucket varun-pe-bucket \
--notification-configuration=file://notification.json