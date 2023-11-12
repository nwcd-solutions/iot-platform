locals {
  debezium_connector_external_url = "https://repo1.maven.org/maven2/io/debezium/debezium-connector-postgres/2.3.0.Final/debezium-connector-postgres-2.3.0.Final-plugin.tar.gz"
  debezium_connector              = "debezium-connector-postgres/debezium-connector-postgres-2.3.0.Final.jar"
  mongodb_connector_external_url  = "https://repo1.maven.org/maven2/org/mongodb/kafka/mongo-kafka-connect/1.10.0/mongo-kafka-connect-1.10.0-all.jar"
  mongodb_connector               = "mongodb-connector/docdb-connector-plugin.zip"
  mongodb_trust_store             = "mongodb-connector/rds-truststore.jks"
  s3_connector                    = "s3-connector/confluentinc-kafka-connect-s3-10.5.7.zip" 
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

module "s3_raw_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.0"

  bucket_prefix ="${ local.name}-raw-"
  #acl           = "private"

  versioning = {
    enabled = true
  }

  # Allow deletion of non-empty bucket for testing
  force_destroy = true

  #attach_deny_insecure_transport_policy = false
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

#resource "aws_s3_object" "lambda_python_layer" {
#  bucket = module.s3_artifacts_bucket.s3_bucket_id
#  key    = local.lambda_python_layer
#  source = local.lambda_python_layer

#  depends_on = [
#    null_resource.lambda_python_layer
#  ]
#}

#resource "null_resource" "lambda_python_layer" {
#  provisioner "local-exec" {
#    command = <<-EOT
#      cd src/lambda/layer  \ 
#        && pip install -r requirements.txt -t python/ \
#        && zip -r ../layer.zip python
# EOT
#  }
#}

