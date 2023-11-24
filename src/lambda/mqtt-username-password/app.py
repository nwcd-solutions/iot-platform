import base64
import boto3
import os
import re

def handler(event, context):
    print(event)
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table(os.environ['DYNAMO_TABLE_NAME'])

    if 'protocolData' in event and 'mqtt' in event['protocolData']:
        client_id = event['protocolData']['mqtt']['clientId']
        username = event['protocolData']['mqtt']['username']
        password = base64.b64decode(event['protocolData']['mqtt']['password']).decode('utf-8')
        print(f"Got [{username}] and [{password}]")
        match = re.match(r'^(.*)\?(.*)$', username)
        query = None
        if match:
            username = match.group(1)
            query = match.group(2)
            response = table.get_item(
                Key={
                    'Client_ID': client_id,
                },
                #ProjectionExpression='Password,Username'
            )
            if 'Item' in response:
                item = response['Item']
                column_password = item['Password']
                column_username = item['Username']
                print(f"Password value: {column_password}")
                print(f"Username value: {column_username}")
                if username == column_username and password == column_password:
                    if '&' in  username:
                        parts =  username.split('&')
                        topic = f"/{parts[1]}/{parts[0]}"
                    else :
                        topic = username                    
                    print("authorize success")
                    return build_policy(topic, True)
            else:
                print("Item not found")
 
    if 'token' in event and event['token'] == os.environ['TOKEN']:
        return build_policy(username, True)
    print('Invalid or missing username/password')
    return build_policy(None, False)

def build_policy(username, authenticated):
    print(username, authenticated)
    if authenticated:
        return {
            'context': {},
            'isAuthenticated': True,
            'principalId': f"{re.sub(r'[^a-zA-Z0-9]', '', username)}",
            'disconnectAfterInSeconds': 300,
            'refreshAfterInSeconds': 300,
            'policyDocuments': [
                {
                    'Version': '2012-10-17',
                    'Statement': [
                        {
                            'Action': 'iot:Connect',
                            'Effect': 'Allow',
                            'Resource': [
                                '*'
                            ]
                        },
                        {
                            'Action': 'iot:Subscribe',
                            'Effect': 'Allow',
                            'Resource': [
                                f"arn:aws:iot:{os.environ['AWS_REGION_NAME']}:{os.environ['AWS_ACCOUNT_ID']}:topicfilter/{username}/*"
                            ]
                        },
                        {
                            'Action': 'iot:Publish',
                            'Effect': 'Allow',
                            'Resource': [
                                f"arn:aws:iot:{os.environ['AWS_REGION_NAME']}:{os.environ['AWS_ACCOUNT_ID']}:topic/{username}/*",
                                f"arn:aws:iot:{os.environ['AWS_REGION_NAME']}:{os.environ['AWS_ACCOUNT_ID']}:topic/$aws/rules/{os.environ['RULE_NAME']}{username}/*"
                            ]
                        }
                    ]
                }
            ]
        }
    else:
        return {
            'context': {},
            'isAuthenticated': False,
            'disconnectAfterInSeconds': 0,
            'refreshAfterInSeconds': 0,
            'policyDocuments': []
        }

