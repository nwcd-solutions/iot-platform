from awscrt.mqtt import Connection, QoS
from awsiot.mqtt_connection_builder import direct_with_custom_authorizer
from pathlib import Path
from urllib.request import urlretrieve
import json
import time

client_id = "test001"
username = "TestUserChangeMe"
password = "<password>"
aws_endpoint = <aws_endpoint>
authorizer_name = <authorizer_name>

# Download CA certificate
aws_ca = Path(__file__).parent / "awsCA.pem"
urlretrieve("https://www.amazontrust.com/repository/AmazonRootCA1.pem",aws_ca)

aws_iot_connection = direct_with_custom_authorizer(
    auth_username=username,
    auth_authorizer_name=authorizer_name,
    auth_password=password,
    **dict(
        endpoint=aws_endpoint,
        client_id=client_id,
        ca_filepath=aws_ca.absolute().__str__(),
        port=443),
        )
connect_future = aws_iot_connection.connect()
connect_future.result()
print("Connected!")
message_count = 0
message_topic = "$aws/rules/iot_msk_rule/TestUserChangeMe"
message_string = "{currect:.002}"
# Publish message to server desired number of times.
# This step is skipped if message is blank.
# This step loops forever if count was set to 0.
if message_string:
    if message_count == 0:
        print("Sending messages until program killed")
    else:
        print("Sending {} message(s)".format(message_count))
    publish_count = 1
    while (publish_count <= message_count) or (message_count == 0):
        message = "{} [{}]".format(message_string, publish_count)
        print("Publishing message to topic '{}': {}".format(message_topic, message))
        message_json = json.dumps(message)
        print(message_json)
        aws_iot_connection.publish(
            topic=message_topic,
            payload=message_json,
            qos=QoS.AT_LEAST_ONCE)
        time.sleep(100)
        publish_count += 1
