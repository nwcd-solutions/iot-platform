##################################################################################################################################################
#
# Create a DynamoDB to store credentials information.
#
##################################################################################################################################################

module "MQTTAuthTable" {
  source   = "terraform-aws-modules/dynamodb-table/aws"

  name     = "MQTTAuthTable"
  hash_key = "Client_ID"

  attributes = [
    {
      name = "Client_ID"
      type = "S"
    }
  ]

  #read_capacity  = 1
  #write_capacity = 1

}

###################################################################################################################################################
#
# Create a Lambda function acting as the authorizer. it  will look for the attributes associated with the key for the Client_ID, out of those 
# attributes it will get a Username and password to figure out whether the credentials that it's using are valid.
#
##################################################################################################################################################

module "lambda_layer_s3" {
  source = "terraform-aws-modules/lambda/aws"

  create_layer = true

  layer_name          = "lambda-layer-s3"
  description         = "My amazing lambda layer (deployed from S3)"
  compatible_runtimes = ["python3.8"]

  source_path = "src/lambda/layer/"

  store_on_s3 = true
  s3_bucket   = module.s3_artifacts_bucket.s3_bucket_id
}

module "mqtt_auth_lambda" {
  source = "terraform-aws-modules/lambda/aws"

  function_name = "authorizer"
  description   = "Lambda fuction used for MQTT custom auth"
  handler       = "app.handler"
  runtime       = "python3.8"
  layers = [
    module.lambda_layer_s3.lambda_layer_arn,
  ]
  source_path = "src/lambda/mqtt-username-password"
  environment_variables = {
    AWS_ACCOUNT_ID = var.account_id,
    AWS_REGION_NAME = var.region
    DYNAMO_TABLE_NAME =  "MQTTAuthTable"
    RULE_NAME = "iot_msk_rule"
  }
  attach_policy_json = true
  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action   = [
        "dynamodb:Get*",
        "dynamodb:Query"
      ]
      Resource = [module.MQTTAuthTable.dynamodb_table_arn]
    },]
  })
   
}

resource "aws_iot_authorizer" "UnsignedAuthorizer" {
  authorizer_function_arn = module.mqtt_auth_lambda.lambda_function_arn
  name         = "MqttAuth-Unsigned"
  enable_caching_for_http = true
  signing_disabled        = true
  status                  = "ACTIVE"
}


resource "aws_lambda_permission" "UnsignedAuthorizerPermission" {
  action        = "lambda:InvokeFunction"
  function_name = module.mqtt_auth_lambda.lambda_function_arn
  principal     = "iot.amazonaws.com"
  source_arn    = aws_iot_authorizer.UnsignedAuthorizer.arn
}

