locals {
  mongodb_connector_external_url  = "https://repo1.maven.org/maven2/org/mongodb/kafka/mongo-kafka-connect/1.10.0/mongo-kafka-connect-1.10.0-all.jar"
  mongodb_connector               = "mongodb-connector/docdb-connector-plugin.zip"
  mongodb_trust_store             = "mongodb-connector/rds-truststore.jks"
}



resource "aws_s3_object" "mongodb_connector" {
  bucket = module.s3_artifacts_bucket.s3_bucket_id
  key    = local.mongodb_connector
  source = local.mongodb_connector

  depends_on = [
    null_resource.mongodb_connector
  ]
}

resource "null_resource" "mongodb_connector" {
  provisioner "local-exec" {
    command = <<-EOT
      sed -i 's/<truststorePassword>/${random_password.docdb.result}/g' ../scripts/generate_docdb_connector_artifacts.sh \
        && /bin/bash scripts/generate_docdb_connector_artifacts.sh \
        && mkdir  mongodb-connector  \
        && cp /tmp/certs/rds-truststore.jks  mongodb-connector/ \
        && cp /tmp/docdb-connector-plugin.zip mongodb-connector/
 EOT
  }
}


resource "aws_s3_object" "mongodb_trust_store" {
  bucket = module.s3_artifacts_bucket.s3_bucket_id
  key    = local.mongodb_trust_store
  source = local.mongodb_trust_store

  depends_on = [
    null_resource.mongodb_connector
  ]
}

resource "aws_iam_role" "msk_docdb_connect_role" {
  name               = "msk_docdb_connect_role"
  assume_role_policy = data.aws_iam_policy_document.assume_kafkaconnect_role.json
}

resource "aws_iam_role_policy" "msk_docdb_connect_policy" {
  name   = "msk_docdb_connect_policy"
  role   = aws_iam_role.msk_docdb_connect_role.id
  policy = data.aws_iam_policy_document.iam_policy_for_mskconnect.json
}

resource "aws_mskconnect_custom_plugin" "docdb" {
  name         = "docdb"
  content_type = "ZIP"
  location {
    s3 {
      bucket_arn = module.s3_artifacts_bucket.s3_bucket_arn
      file_key   = aws_s3_object.mongodb_connector.id
      object_version = aws_s3_object.mongodb_connector.version_id
    }
  }
}


resource "aws_mskconnect_connector" "documentdb_connector" {
  name = "docdb-connector"
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
    "connector.class" = "com.mongodb.kafka.connect.MongoSinkConnector"
    "tasks.max"       = "1"
    "topics"          = "example"
    "connection.uri": "mongodb://<USERNAME>:<PASSWORD>@<HOSTNAME>:<PORT>/<DATABASE>",
    "database": "<DATABASE>",
    "collection": "<COLLECTION>",
    "key.converter": "org.apache.kafka.connect.storage.StringConverter",
    "value.converter": "org.apache.kafka.connect.json.JsonConverter",
    "value.converter.schemas.enable": "false",
    "errors.tolerance": "all",
    "errors.log.enable": "true",
    "errors.log.include.messages": "true",
    "errors.deadletterqueue.topic.name": "dlq",
    "errors.deadletterqueue.context.headers.enable": "true",
    "errors.deadletterqueue.topic.replication.factor": "3",
    "errors.retry.delay.max.ms": "60000",
    "errors.retry.timeout": "300000",
    "errors.retry.max.attempts": "10",
    "mongodb.output.format.value": "document",
    "mongodb.database": "<DATABASE>",
    "mongodb.collection": "<COLLECTION>",
    "mongodb.document.id.strategy": "com.mongodb.kafka.connect.sink.processor.id.strategy.PartialValueStrategy",
    "mongodb.document.id.strategy.partial.value.projection.list": "[\"_id\"]",
    "mongodb.document.id.strategy.partial.value.projection.type": "AllowList"
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
      arn      = aws_mskconnect_custom_plugin.docdb.arn
      revision = aws_mskconnect_custom_plugin.docdb.latest_revision
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
  service_execution_role_arn = aws_iam_role.msk_docdb_connect_role.arn
}
