locals {
  s3_connector                    = "s3-connector/confluentinc-kafka-connect-s3-10.5.7.zip" 
}

resource "aws_s3_object" "s3_connector" {
  bucket = module.s3_artifacts_bucket.s3_bucket_id
  key    = local.s3_connector
  source = local.s3_connector

  depends_on = [
    null_resource.s3_connector
  ]
}

resource "null_resource" "s3_connector" {
  provisioner "local-exec" {
    command = <<-EOT
      wget https://nwcd-solutions-global.s3.amazonaws.com/iot-platform/msk-connector-packages/confluentinc-kafka-connect-s3-10.5.7.zip -P s3-connector/
 EOT
  }
}

resource "aws_mskconnect_custom_plugin" "s3" {
  name         = "s3"
  content_type = "ZIP"
  location {
    s3 {
      bucket_arn = module.s3_artifacts_bucket.s3_bucket_arn
      file_key   = aws_s3_object.s3_connector.id
      object_version = aws_s3_object.s3_connector.version_id
    }
  }
}

resource "aws_iam_role" "msk_s3_connect_role" {
  name               = "msk_s3_connect_role"
  assume_role_policy = data.aws_iam_policy_document.assume_kafkaconnect_role.json
}

resource "aws_iam_role_policy" "iam_policy_for_mskconnect" {
  name   = "msk_connect_policy"
  role   = aws_iam_role.msk_s3_connect_role.id
  policy = data.aws_iam_policy_document.iam_policy_for_mskconnect.json
}

resource "aws_iam_role_policy_attachment" "s3_full_access_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  role       = aws_iam_role.msk_s3_connect_role.name
}

resource "aws_mskconnect_connector" "s3_connector" {
  name = "s3-connector-new"
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
    "s3.region"= var.region
    "format.class"="io.confluent.connect.s3.format.json.JsonFormat"
    "flush.size"="1"
    "schema.compatibility" = "NONE"
    "tasks.max"            = "2"
    "topics"               = var.kafka_topic
    "partitioner.class"    = "io.confluent.connect.storage.partitioner.DefaultPartitioner"
    "storage.class"="io.confluent.connect.s3.storage.S3Storage"
    "s3.bucket.name"= module.s3_raw_bucket.s3_bucket_id
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
      arn      = aws_mskconnect_custom_plugin.s3.arn
      revision = aws_mskconnect_custom_plugin.s3.latest_revision
    }
  }
  log_delivery {
    worker_log_delivery {
      cloudwatch_logs {
        enabled = true
        log_group = "msk-connect"
      }
    }
  }

  service_execution_role_arn = aws_iam_role.msk_s3_connect_role.arn
}
