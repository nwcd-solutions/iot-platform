#---------------------------------------------------------------
# Local variables
#---------------------------------------------------------------
locals {
  name   = var.name
  region = var.region

  vpc_cidr                      = var.vpc_cidr
  num_of_azs                    = 2
  azs                           = slice(data.aws_availability_zones.available.names, 0, local.num_of_azs)
  airflow_name                  = "airflow"
  airflow_service_account       = "airflow-webserver-sa"
  airflow_webserver_secret_name = "airflow-webserver-secret-key"
  efs_storage_class             = "efs-sc"
  efs_pvc                       = "airflowdags-pvc"


  tags = {
    Name  = local.name
  }
}

resource "random_string" "random" {
  length           = 6
  special          = false
}

