resource "random_string" "random" {
  length           = 6
  special          = false
}

variable "name" {
  description = "Name of the VPC and EKS Cluster"
  type        = string
  default     = "kafaka"
}

variable "region" {
  description = "region"
  type        = string
  default     = "us-east-1"
}

variable "eks_cluster_version" {
  description = "EKS Cluster version"
  type        = string
  default     = "1.23"
}

variable "msk_username" {
  description = "MSK user name for SASL Scram"
  type        = string
  default     = "msk"
}

variable "docdb_username" {
  description = "DocumentDB user name"
  type        = string
  default     = "docdb"
}


variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "iot_topic" {
  description = "iott opic"
  type        = string
  default     = "sdk/test/js"
}

variable "kafka_topic" {
  description = "kafka opic"
  type        = string
  default     = "iottopic"
}


