resource "aws_iam_role" "iot_msk_rule_role" {
  name               = "iot_msk_rule_role"
  assume_role_policy = data.aws_iam_policy_document.assume_iot_role.json
}

resource "aws_iam_role_policy" "iam_policy_for_iotmsk" {
  name   = "iot_msk_policy"
  role   = aws_iam_role.iot_msk_rule_role.id
  policy = data.aws_iam_policy_document.iam_policy_for_iotmsk.json
}

resource "aws_iot_topic_rule_destination" "iot_msk_destination" {
  vpc_configuration {
    role_arn        = aws_iam_role.iot_msk_rule_role.arn
    security_groups = [module.msk_sg.security_group_id]
    subnet_ids      =  module.vpc.private_subnets
    vpc_id          = module.vpc.vpc_id
  }
}

resource "aws_iot_topic_rule" "iot_msk_rule" {
  name        = "IoT_MSK_Rule"
  description = "Rule to forward MQTT messages to MSK"
  enabled     = true
  sql         = "SELECT * FROM '${var.iot_topic}'"
  sql_version = "2016-03-23"
  
  kafka {
    client_properties = {
        "sasl.mechanism"      = "SCRAM-SHA-512"
        "security.protocol"   = "SASL_SSL"        
        "bootstrap.servers"   = module.msk_kafka_cluster.bootstrap_brokers_sasl_scram 
        #"ssl.keystore"        = 
        "sasl.scram.username" = "$${get_secret('AmazonMSK_${random_string.random.result}','SecretString', 'username','${aws_iam_role.iot_msk_rule_role.arn}')}"
        "sasl.scram.password" = "$${get_secret('AmazonMSK_${random_string.random.result}','SecretString', 'password','${aws_iam_role.iot_msk_rule_role.arn}')}"
    }
    destination_arn   = aws_iot_topic_rule_destination.iot_msk_destination.arn
    topic             = var.kafka_topic
  }
 
}
