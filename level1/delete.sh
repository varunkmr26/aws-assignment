readFile=`ids.txt`
ids=($readFile)

APIID=${ids[0]}
NAME=${ids[1]}
REGION=${ids[2]}

aws apigateway delete-rest-api --rest-api-id ${APIID} --region ${REGION}
aws lambda delete-function --function-name ${NAME} --region ${REGION}
aws dynamodb delete-table --table-name varun-pe-shell