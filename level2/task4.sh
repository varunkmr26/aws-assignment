#create instance profile
aws iam create-instance-profile --instance-profile-name utsav-lambda

#create lambda role
role_arn=$(aws iam create-role --role-name utsav-lambda-role --assume-role-policy-document "{\"Version\": \"2012-10-17\", \"Statement\": [{\"Effect\": \"Allow\",\"Principal\": {\"Service\": [\"lambda.amazonaws.com\",\"events.amazonaws.com\",\"s3.amazonaws.com\"]},\"Action\": \"sts:AssumeRole\"}]}" --query 'Role.Arn' --output text)


#add role to instance profile
aws iam add-role-to-instance-profile\
 --instance-profile-name utsav-lambda --role-name utsav-lambda-role

#put role policy
aws iam put-role-policy --role-name utsav-lambda-role --policy-name utsav-lambda-access-policy --policy-document "{
    \"Version\": \"2012-10-17\",
    \"Statement\": [
        {
            \"Effect\": \"Allow\",
            \"Action\": \"s3:*\",
            \"Resource\": \"*\"
        },
        {
            \"Action\": \"ec2:*\",
            \"Effect\": \"Allow\",
            \"Resource\": \"*\"
        },
        {
            \"Effect\": \"Allow\",
            \"Action\": \"elasticloadbalancing:*\",
            \"Resource\": \"*\"
        },
        {
            \"Effect\": \"Allow\",
            \"Action\": \"cloudwatch:*\",
            \"Resource\": \"*\"
        },
        {
            \"Effect\": \"Allow\",
            \"Action\": \"autoscaling:*\",
            \"Resource\": \"*\"
        },
        {
            \"Effect\": \"Allow\",
            \"Action\": \"iam:CreateServiceLinkedRole\",
            \"Resource\": \"*\",
            \"Condition\": {
                \"StringEquals\": {
                    \"iam:AWSServiceName\": [
                        \"autoscaling.amazonaws.com\",
                        \"ec2scheduled.amazonaws.com\",
                        \"elasticloadbalancing.amazonaws.com\",
                        \"spot.amazonaws.com\",
                        \"spotfleet.amazonaws.com\"
                    ]
                }
            }
        },
        {
            \"Sid\": \"CloudWatchEventsFullAccess\",
            \"Effect\": \"Allow\",
            \"Action\": \"events:*\",
            \"Resource\": \"*\"
        },
        {
            \"Sid\": \"IAMPassRoleForCloudWatchEvents\",
            \"Effect\": \"Allow\",
            \"Action\": \"iam:PassRole\",
            \"Resource\": \"arn:aws:iam::*:role/AWS_Events_Invoke_Targets\"
        }
    ]
}"

aws s3 create-bucket --bucket code-bucket --region us-east-1


echo -e "import json import boto3 import calendar import datetime
# Enter the region your instances are in. Include only the region without specifying Availability Zone; e.g.; 'us-east-1'
region = 'us-east-1'
# Enter your instances here: ex. ['X-XXXXXXXX', 'X-XXXXXXXX']
instances = ['i-0a1661145e5b3c8ed'] def lambda_handler(event, context):
    ec2 = boto3.client('ec2', region_name=region)
    ec2.start_instances(InstanceIds=instances)
    print ('started your instances: ' + str(instances))
    
    #getting next day
    today = datetime.datetime.now() + datetime.timedelta(days=1)
    next_day=today.strftime(\"%A\")
    next_day=next_day[0:3]
    print(next_day)
    
    #changing rule
    client = boto3.client('s3')
    
    json_object = client.get_object(Bucket='s3-read-weakly', Key='weekly.json')
    print(json_object)
    jsonFileReader = json_object['Body'].read()
    print(jsonFileReader)
    jsonDict = json.loads(jsonFileReader)
    #print(type(jsonDict)
    cron=jsonDict[next_day][2]['cronstart']
    print(cron)
    
    c = boto3.client('events')
    
    response = c.put_rule(
           Name='start_rule',
           ScheduleExpression=cron,
           State='ENABLED'
           )
    
    return 'Hello from Lambda'" > lambda_function.py

zip lambda_start.zip lambda_function.py

startFunctionArn=$(aws lambda create-function --function-name start-function-utsav --region us-east-1 --runtime python3.6 \
--role arn:aws:iam::488599217855:role/utsav-lambda-role \
--zip-file="fileb://lambda_start.zip" --timeout 300 --memory-size 512 --handler lambda_function.lambda_handler --query 'FunctionArn')

rm lambda_function.py

#creating ec2 stop lambda function

echo -e "import boto3 import json import datetime
# Enter the region your instances are in. Include only the region without specifying Availability Zone; e.g., 'us-east-1'
region = 'us-east-1'
# Enter your instances here: ex. ['X-XXXXXXXX', 'X-XXXXXXXX']
instances = ['i-0a1661145e5b3c8ed'] def lambda_handler(event, context):
    
    today = datetime.datetime.now() + datetime.timedelta(days=1)
    next_day=today.strftime(\"%A\")
    next_day=next_day[0:3]
    print(next_day)
    
    #changing rule
    client = boto3.client('s3')
    
    json_object = client.get_object(Bucket='s3-read-weakly', Key='weekly.json')
    print(json_object)
    jsonFileReader = json_object['Body'].read()
    print(jsonFileReader)
    jsonDict = json.loads(jsonFileReader)
    #print(type(jsonDict)
    cron=jsonDict[next_day][3]['cronstop']
    print(cron)
    
    c = boto3.client('events')
    
    response = c.put_rule(
           Name='stop_rule',
           ScheduleExpression=cron,
           State='ENABLED'
           )
    
    ec2 = boto3.client('ec2', region_name=region)
    ec2.stop_instances(InstanceIds=instances)
    print ('stopped your instances: ' + str(instances))" > lambda_function.py

zip lambda_stop.zip lambda_function.py

rm lambda_function.py

stopFunctionArn=$(aws lambda create-function --function-name stop-function-utsav --region us-east-1 --runtime python3.6 \
--role arn:aws:iam::488599217855:role/utsav-lambda-role \
--zip-file="fileb://lambda_stop.zip" --timeout 300 --memory-size 512 --handler lambda_function.lambda_handler --query 'FunctionArn')


#creating s3 trigger function
echo -e "import boto3 import json from datetime import date import calendar s3_client = boto3.client('s3') client = 
boto3.client('events') my_date = date.today() today = calendar.day_name[my_date.weekday()]
#print(today)
def lambda_handler(event, context):
    bucket = event['Records'][0]['s3']['bucket']['name']
    json_file_name = event['Records'][0]['s3']['object']['key']
    #print(bucket) print(json_file_name)
    json_object = s3_client.get_object(Bucket=bucket, Key=json_file_name)
    #print(json_object)
    jsonFileReader = json_object['Body'].read()
    #print(jsonFileReader)
    jsonDict = json.loads(jsonFileReader)
    #print(type(jsonDict))
    case = today[0:3]
    if case == 'Mon':
        cronstart = jsonDict['Mon'][2]['cronstart']
        cronstop = jsonDict['Mon'][3]['cronstop']
        response_start = client.put_rule(
            Name='start_rule',
            ScheduleExpression=cronstart,
            State='ENABLED'
            )
        response_stop = client.put_rule(
            Name='start_rule',
            ScheduleExpression=cronstop,
            State='ENABLED'
            )
    elif case == 'Tue':
        cronstart = jsonDict['Tue'][2]['cronstart']
        cronstop = jsonDict['Tue'][3]['cronstop']
        response_start = client.put_rule(
            Name='start_rule',
            ScheduleExpression=cronstart,
            State='ENABLED'
            )
        response_stop = client.put_rule(
            Name='start_rule',
            ScheduleExpression=cronstop,
            State='ENABLED'
            )
    elif case == 'Wed':
        cronstart = jsonDict['Wed'][2]['cronstart']
        cronstop = jsonDict['Wed'][3]['cronstop']
        response_start = client.put_rule(
            Name='start_rule',
            ScheduleExpression=cronstart,
            State='ENABLED'
            )
        response_stop = client.put_rule(
            Name='start_rule',
            ScheduleExpression=cronstop,
            State='ENABLED'
            )
    elif case == 'Thu':
        cronstart = jsonDict['Thu'][2]['cronstart']
        cronstop = jsonDict['Thu'][3]['cronstop']
        response_start = client.put_rule(
            Name='start_rule',
            ScheduleExpression=cronstart,
            State='ENABLED'
            )
        response_stop = client.put_rule(
            Name='start_rule',
            ScheduleExpression=cronstop,
            State='ENABLED'
            )
    elif case == 'Fri':
        cronstart = jsonDict['Fri'][2]['cronstart']
        cronstop = jsonDict['Fri'][3]['cronstop']
        response_start = client.put_rule(
            Name='start_rule',
            ScheduleExpression=cronstart,
            State='ENABLED'
            )
        response_stop = client.put_rule(
            Name='start_rule',
            ScheduleExpression=cronstop,
            State='ENABLED'
            )
    elif case == 'Sat':
        cronstart = jsonDict['Sat'][2]['cronstart']
        cronstop = jsonDict['Sat'][3]['cronstop']
        response_start = client.put_rule(
            Name='start_rule',
            ScheduleExpression=cronstart,
            State='ENABLED'
            )
        response_stop = client.put_rule(
            Name='start_rule',
            ScheduleExpression=cronstop,
            State='ENABLED'
            )
    elif case == 'Sun':
        cronstart = jsonDict['Sun'][2]['cronstart']
        cronstop = jsonDict['Sun'][3]['cronstop']
        response_start = client.put_rule(
            Name='start_rule',
            ScheduleExpression=cronstart,
            State='ENABLED'
            )
        response_stop = client.put_rule(
            Name='start_rule',
            ScheduleExpression=cronstop,
            State='ENABLED'
            )
    return 'Hello from Lambda'" > lambda_function.py

zip lambda-s3-weekly.zip lambda_function.py

rm lambda_function.py

s3FunctionArn=$(aws lambda create-function --function-name s3-function-utsav --region us-east-1 --runtime python3.6 \
--role arn:aws:iam::488599217855:role/utsav-lambda-role \
--zip-file="fileb://lambda-s3-weekly.zip" --timeout 300 --memory-size 512 --handler lambda_function.lambda_handler --query 'FunctionArn')


start_rule_arn=$(aws events put-rule --name start-rule-utsav --schedule-expression "cron(0 20 * * ? *)" --role-arn "$role_arn" --region us-east-1 --query 'RuleArn' --output text)

stop_rule_arn=$(aws events put-rule --name stop-rule-utsav --schedule-expression "cron(0 20 * * ? *)"  --role-arn "$role_arn" --region us-east-1 --query 'RuleArn' --output text)


aws lambda add-permission --function-name start-function-utsav \
--action lambda:InvokeFunction \
--statement-id start-ec2 \
--principal events.amazonaws.com \
--source-arn $start_rule_arn \
--region us-east-1

aws lambda add-permission --function-name stop-function-utsav \
--action lambda:InvokeFunction \
--statement-id stop-ec2 \
--principal events.amazonaws.com \
--source-arn $stop_rule_arn \
--region us-east-1

aws lambda add-permission --function-name s3-function-utsav \
--action lambda:InvokeFunction \
--statement-id weekly-s3-func \
--principal s3.amazonaws.com \
--source-arn arn:aws:s3:::s3-read-weakly \
--region us-east-1 

aws events put-targets --rule start-ec2 --targets file://targets.json

aws events put-targets --rule stop-ec2 --targets file://targets.json

aws events put-targets --rule weekly-s3-func --targets file://targets.json

#taking inputs from user
read -p "Enter Day: " day
read -p "Enter starttime ,stoptime, cronstart, cronstop in the given sequence" starttime stoptime cronstart cronstop
string="{\"$day\":[{"\"start\"":\"$starttime\"}, {"\"stop\"":\"$stoptime\"}, {"\"cronstart\"":\"$cronstart\"},{"\"cronstop\"":\"$cronstop\"}],"
for i in {1..6}
do
read -p "Enter Day: " day
read -p "Enter starttime ,stoptime, cronstart, cronstop in the given sequence" starttime stoptime cronstart cronstop
string+="\"$day\":[{"\"start\"":\"$starttime\"}, {"\"stop\"":\"$stoptime\"}, {"\"cronstart\"":\"$cronstart\"},{"\"cronstop\"":\"$cronstop\"}],"
done
string+="}"
echo $string | sed 's/,\(.\)$/\1/' > weekly.json

aws s3 cp weekly.json s3://s3-read-weakly

