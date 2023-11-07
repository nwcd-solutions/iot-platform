locals {
  debezium_connector_external_url = "https://repo1.maven.org/maven2/io/debezium/debezium-connector-postgres/2.3.0.Final/debezium-connector-postgres-2.3.0.Final-plugin.tar.gz"
  debezium_connector              = "debezium-connector-postgres/debezium-connector-postgres-2.3.0.Final.jar"
  mongodb_connector_external_url  = "https://repo1.maven.org/maven2/org/mongodb/kafka/mongo-kafka-connect/1.10.0/mongo-kafka-connect-1.10.0-all.jar"
  mongodb_connector               = "mongodb-connector/docdb-connector-plugin.zip"
  mongodb_trust_store             = "mongodb-connector/rds-truststore.jks"
 
}

module "s3_logs_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.0"

  bucket_prefix = "${local.name}-log-"

  acl                      = "log-delivery-write"
  control_object_ownership = true
  object_ownership         = "ObjectWriter"


  # Allow deletion of non-empty bucket for testing
  force_destroy = true

  attach_deny_insecure_transport_policy = true
  attach_lb_log_delivery_policy         = true # this allows log delivery

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = local.tags
}

module "s3_artifacts_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.0"

  bucket_prefix ="${ local.name}-raw-"
  acl           = "private"

  versioning = {
    enabled = true
  }

  # Allow deletion of non-empty bucket for testing
  force_destroy = true

  attach_deny_insecure_transport_policy = true
  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = local.tags
}


module "s3_artifacts_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.0"

  bucket_prefix ="${ local.name}-artifacts-"
  #acl           = "private"

  versioning = {
    enabled = true
  }

  # Allow deletion of non-empty bucket for testing
  force_destroy = true

  attach_deny_insecure_transport_policy = true
  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = local.tags
}

resource "aws_s3_object" "debezium_connector" {
  bucket = module.s3_artifacts_bucket.s3_bucket_id
  key    = local.debezium_connector
  source = local.debezium_connector

  depends_on = [
    null_resource.debezium_connector
  ]
}

resource "null_resource" "debezium_connector" {
  provisioner "local-exec" {
    command = <<-EOT
      wget -c ${local.debezium_connector_external_url} -O connector.tar.gz \
        && tar -zxvf connector.tar.gz  ${local.debezium_connector} \
        && rm *.tar.gz
    EOT
  }
}

resource "aws_s3_object" "mongodb_connector" {
  bucket = module.s3_artifacts_bucket.s3_bucket_id
  key    = local.mongodb_connector
  source = local.mongodb_connector

  depends_on = [
    null_resource.mongodb_connector
  ]
}
resource "aws_s3_object" "mongodb_trust_store" {
  bucket = module.s3_artifacts_bucket.s3_bucket_id
  key    = local.mongodb_trust_store
  source = local.mongodb_trust_store

  depends_on = [
    null_resource.mongodb_connector
  ]
}

#resource "null_resource" "mongodb_connector" {
#  provisioner "local-exec" {
#    command = <<-EOT
#       wget https://repo1.maven.org/maven2/org/mongodb/kafka/mongo-kafka-connect/1.10.0/mongo-kafka-connect-1.10.0-all.jar  -P docdb-connector/mongo-connector/   \
#        && wget https://github.com/aws-samples/msk-config-providers/releases/download/r0.1.0/msk-config-providers-0.1.0-with-dependencies.zip  -P docdb-connector/msk-config-providers/   \
#        && unzip docdb-connector/msk-config-providers/msk-config-providers-0.1.0-with-dependencies.zip -d docdb-connector/msk-config-providers/  \
#        && rm docdb-connector/msk-config-providers/msk-config-providers-0.1.0-with-dependencies.zip   \
#        && mkdir mongodb-connector  \
#        && zip -r mongodb-connector/docdb-connector-plugin.zip docdb-connector 
#    EOT
#  }
#}

resource "null_resource" "mongodb_connector" {
  provisioner "local-exec" {
    command = <<-EOT
      sed -i 's/<truststorePassword>/${random_password.docdb.result}/g' scripts/generate_docdb_connector_artifacts.sh \
        && /bin/bash scripts/generate_docdb_connector_artifacts.sh \
        && mkdir  mongodb-connector  \
        && cp /tmp/certs/rds-truststore.jks  mongodb-connector/ \
        && cp /tmp/docdb-connector-plugin.zip mongodb-connector/
 EOT
  }
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
      wget  mongodb-connector/
 EOT
  }
}

