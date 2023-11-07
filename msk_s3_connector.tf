resource "aws_iam_role" "msk_connect_role" {
  name               = "msk_connect_role"
  assume_role_policy = data.aws_iam_policy_document.assume_kafkaconnect_role.json
}

resource "aws_iam_role_policy" "iam_policy_for_mskconnect" {
  name   = "msk_connect_policy"
  role   = aws_iam_role.msk_connect_role.id
  policy = data.aws_iam_policy_document.iam_policy_for_mskconnect.json
}

resource "aws_mskconnect_connector" "s3_connector" {
  name = "s3-connector"
  kafkaconnect_version = "2.7.1"

  capacity {
    autoscaling {
      mcu_count        = 1
      min_worker_count = 1
      max_worker_count = 2

      scale_in_policy {
        cpu_utilization_percentage = 20
      }

      scale_out_policy {
        cpu_utilization_percentage = 80
      }
    }
  }

  connector_configuration = {
    "connector.class" = "io.confluent.connect.s3.S3SinkConnector"
    "s3.region"=local.region
    "format.class"="io.confluent.connect.s3.format.json.JsonFormat"
    "flush.size"="1"
    "schema.compatibility"="NONE"
    "tasks.max"       = "2"
    "topics"          = 
    "partitioner.class"="io.confluent.connect.storage.partitioner.DefaultPartitioner"
    "storage.class"="io.confluent.connect.s3.storage.S3Storage"
    "s3.bucket.name"=
  }

  kafka_cluster {
    apache_kafka_cluster {
      bootstrap_servers = module.msk_kafka_cluster.bootstrap_brokers_sasl_iam
      vpc {
        security_groups = [module.msk_sg.security_group_id]
        subnets         = module.vpc.private_subnets
      }
    }
  }

  kafka_cluster_client_authentication {
    authentication_type = "IAM"
  }

  kafka_cluster_encryption_in_transit {
    encryption_type = "TLS"
  }

  plugin {
    custom_plugin {
      arn      = module.msk_kafka_cluster.connect_custom_plugins.s3.arn
      revision = module.msk_kafka_cluster.connect_custom_plugins.s3.latest_revision
    }
  }

  service_execution_role_arn = aws_iam_role.msk_connect_role.arn
}
