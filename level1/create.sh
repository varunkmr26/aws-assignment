aws dynamodb create-table --table-name varun-pe-s \
  --attribute-definitions AttributeName=id,AttributeType=S \
  --key-schema AttributeName=id,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region us-east-1
  
aws iam attach-role-policy --role-name Q11_DynamoDB_FullAccess --policy-arn arn:aws:iam::488599217855:role/Q11_DynamoDB_FullAccess

aws lambda create-function --function-name varun-shell-api \
  --runtime python2.6 --role arn:aws:iam::488599217855:role/Q11_DynamoDB_FullAccess \
  --handler index.writeMovie \
  --code S3Bucket="varun-pe-script-bucket",S3Key="index.py",S3ObjectVersion="Latest Version" \
  --memory-size 512 \
  --timeout 10 \
  --region us-east-1

APINAME=varun-pe-shell-api
REGION=us-east-1
NAME=varun-shell-api # function name
API_PATH=put-item
# Create an API
aws apigateway create-rest-api --name "${APINAME}" --description "Api for ${NAME}" --region ${REGION}
APIID=$(aws apigateway get-rest-apis --query "items[?name==\`${APINAME}\`].id" --output text --region ${REGION})
echo "API ID: ${APIID}"
PARENTRESOURCEID=$(aws apigateway get-resources --rest-api-id ${APIID} --query "items[?path=='/'].id" --output text --region ${REGION})
echo "Parent resource ID: ${PARENTRESOURCEI}"
# Create a resource as a path, our function will handle many tables (resources) but you can be more specific
aws apigateway create-resource --rest-api-id ${APIID} --parent-id ${PARENTRESOURCEID} --path-part ${API_PATH} --region ${REGION}
RESOURCEID=$(aws apigateway get-resources --rest-api-id ${APIID} --query "items[?path=='/db-api'].id" --output text --region ${REGION})
echo "Resource ID for path ${API_PATH}: ${APIID}"
aws apigateway put-method --rest-api-id ${APIID} --resource-id ${RESOURCEID} --http-method POST --authorization-type NONE  --no-api-key-required --region ${REGION}
LAMBDAARN=$(aws lambda list-functions --query "Functions[?FunctionName==\`${NAME}\`].FunctionArn" --output text --region ${REGION})
echo "Lambda Arn: ${LAMBDAARN}"
aws apigateway put-integration --rest-api-id ${APIID} \
--resource-id ${RESOURCEID} \
--http-method POST \
--type AWS_PROXY \
--integration-http-method POST \
--uri arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/${LAMBDAARN}/invocations
aws apigateway create-deployment --rest-api-id ${APIID} --stage-name prod --region ${REGION}
APIARN=$(echo ${LAMBDAARN} | sed -e 's/lambda/execute-api/' -e "s/function:${NAME}/${APIID}/")
echo "APIARN: $APIARN"
UUID=$(uuidgen)
aws lambda add-permission \
--function-name ${NAME} \
--statement-id apigateway-db-api-any-proxy-${UUID} \
--action lambda:InvokeFunction \
--principal apigateway.amazonaws.com \
--source-arn "${APIARN}/*/*/put-item"
aws apigateway put-method-response \
--rest-api-id ${APIID} \
--resource-id ${RESOURCEID} \
--http-method ANY \
--status-code 200 \
--response-models "{}" \
--region ${REGION}
echo "Resource URL is https://${APIID}.execute-api.${REGION}.amazonaws.com/prod/put-item/"
