variable "name" {
  description = "Name of the VPC and EKS Cluster"
  type        = string
  default     = "kafka"
}

variable "region" {
  description = "region"
  type        = string
  default     = "us-east-1"
}

variable "account_id" {
  description = "Account ID"
  type        = string
  default     = "1234567890"
}

variable "msk_username" {
  description = "MSK user name for SASL Scram"
  type        = string
  default     = "msk"
}

variable "msk_instance_type" {
  description = "Instance Type of Kafka Broker"
  type        = string
  default     = "kafka.t3.small"
}

variable "docdb_username" {
  description = "Device Auth Credential db"
  type        = string
  default     = "docdb"
}


variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "iot_topic" {
  description = "iot opic"
  type        = string
  default     = "device/#"
}

variable "kafka_topic" {
  description = "kafka opic"
  type        = string
  default     = "iottopic"
}


