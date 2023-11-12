#---------------------------------------------------------------
# Data resources
#---------------------------------------------------------------


data "aws_availability_zones" "available" {}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_iam_policy_document" "assume_kafkaconnect_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["kafkaconnect.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "iam_policy_for_mskconnect" {
  statement {
    effect    = "Allow"
    actions   = [
      "kafka-cluster:*"
    ]
    resources = ["arn:aws:kafka:${var.region}:${var.account_id}:*/*/*"]
  }
}

data "aws_iam_policy_document" "assume_iot_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["iot.amazonaws.com"]
    }
    
    actions = ["sts:AssumeRole"]
  }
}


data "aws_iam_policy_document" "iam_policy_for_iotmsk" {
  statement {
    effect    = "Allow"
    actions   = [
        "ec2:CreateNetworkInterface",
        "ec2:DescribeNetworkInterfaces",
        "ec2:CreateNetworkInterfacePermission",
        "ec2:DescribeVpcs",
        "ec2:DeleteNetworkInterface",
        "ec2:DescribeSubnets",
        "ec2:DescribeVpcAttribute",
        "ec2:DescribeSecurityGroups",

    ]
    resources = ["*"]
  }

  statement {
    effect    = "Allow"
    actions   = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret",
    ]
    resources = ["*"]
  }

}
