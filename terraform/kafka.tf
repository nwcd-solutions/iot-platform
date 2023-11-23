#####################################################################################################################################################
#
#  Create credentials in AWS Secrets Manager
#  create a set of credentials that can be used by the IoT rule to connect with the Amazon MSK cluster. The credentials must be stored in AWS Secrets 
#  Manager and associated with the cluster. Before create the credentials in AWS Secrets Manager, first create a customer-managed key in AWS Key Man-
#  agement Service (KMS). Secrets encrypted with a AWS managed CMK cannot be used with an Amazon MSK cluster.
#
####################################################################################################################################################

module "symmetric_key" {
  source              = "terraform-aws-modules/kms/aws"
  description         = "Symmetric CMK to be used by Sasl secret"
  enable_key_rotation = false
  key_users           = [aws_iam_role.iot_msk_rule_role.arn]
  aliases             = ["iot-msk-key"]
}

resource "random_password" "msk" {
  length  = 8
  special = false
}

module "sasl_secret" {
  source = "terraform-aws-modules/secrets-manager/aws"
  name        = "AmazonMSK_${random_string.random.result}"
  description = "This is the secret for Amazon MSK SASL/SCRAM authentication. This secret has a dynamically generated secret password"
  
  secret_string = jsonencode({ 
      username = var.msk_username,
      password = random_password.msk.result
  })
  
  kms_key_id = module.symmetric_key.key_arn
}

#####################################################################################################################################################
#
#  Setting up an Amazon MSK cluster
#  To deliver messages from IoT devices to Amazon MSK using AWS IoT Core rule actions, you need to enable authentication on your Amazon MSK cluster. 
#  IoT rule actions can authenticate with your Amazon MSK cluster with username and password authentication using the SASL/SCRAM authentication method.
#
#####################################################################################################################################################

resource "aws_cloudwatch_log_group" "msk_connect_log_group" {
  name = "msk-connect"
}

module "msk_kafka_cluster" {
  source  = "clowdhaus/msk-kafka-cluster/aws" 

  kafka_version          = "2.8.1"
  number_of_broker_nodes = local.num_of_azs

  broker_node_client_subnets = module.vpc.private_subnets
  broker_node_storage_info = {
    ebs_storage_info = { volume_size = 100 }
  }
  broker_node_instance_type   = var.msk_instance_type
  broker_node_security_groups = [module.msk_sg.security_group_id]

  encryption_in_transit_client_broker = "TLS"
  encryption_in_transit_in_cluster    = true

  client_authentication = {
    sasl = { 
        scram = true
        iam   = true
    }
  }
  create_scram_secret_association = true
  scram_secret_association_secret_arn_list = [
     module.sasl_secret.secret_arn
  ]

  configuration_name        = "msk-cluster-configuration"
  configuration_description = "MSK Cluster configuration"
  configuration_server_properties = {
    "auto.create.topics.enable" = true
    "delete.topic.enable"       = true
  }

  jmx_exporter_enabled    = true
  node_exporter_enabled   = true
  cloudwatch_logs_enabled = true
  s3_logs_enabled         = true
  s3_logs_bucket          = module.s3_logs_bucket.s3_bucket_id
  s3_logs_prefix          = local.name

  scaling_max_capacity = 512
  scaling_target_value = 80

}

###########################################################################################################################################################
#
#  Create VPC destination for AWS IoT core
#  Create a destination to your VPC where Apache Kafka clusters reside. This destination is used to route messages from devices to your Amazon MSK cluster.
#
###########################################################################################################################################################

resource "aws_iot_topic_rule_destination" "iot_msk_destination" {
  vpc_configuration {
    role_arn        = aws_iam_role.iot_msk_rule_role.arn
    security_groups = [module.msk_sg.security_group_id]
    subnet_ids      =  module.vpc.private_subnets
    vpc_id          = module.vpc.vpc_id
  }
}

