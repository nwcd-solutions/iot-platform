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



