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

module "msk_kafka_cluster" {
  source  = "clowdhaus/msk-kafka-cluster/aws" 

  kafka_version          = "2.8.1"
  number_of_broker_nodes = local.num_of_azs

  broker_node_client_subnets = module.vpc.private_subnets
  broker_node_storage_info = {
    ebs_storage_info = { volume_size = 100 }
  }
  broker_node_instance_type   = "kafka.t3.small"
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

  # Connect custom plugin(s)
  connect_custom_plugins = {
    debezium = {
      name         = "debezium-postgresql"
      description  = "Debezium PostgreSQL connector"
      content_type = "JAR"

      s3_bucket_arn     = module.s3_artifacts_bucket.s3_bucket_arn
      s3_file_key       = aws_s3_object.debezium_connector.id
      s3_object_version = aws_s3_object.debezium_connector.version_id

      timeouts = {
        create = "20m"
      }
    }
    mongodb = {
      name         = "mongodb"
      description  = "Amazon DocumentDB connector"
      content_type = "ZIP"

      s3_bucket_arn     = module.s3_artifacts_bucket.s3_bucket_arn
      s3_file_key       = aws_s3_object.mongodb_connector.id
      s3_object_version = aws_s3_object.mongodb_connector.version_id

      timeouts = {
        create = "20m"
      }
    }

  }

}
