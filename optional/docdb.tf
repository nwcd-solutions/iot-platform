resource "random_password" "docdb" {
  length  = 8
  special = false
}

module "docdb_secret" {
  source = "terraform-aws-modules/secrets-manager/aws"
  name        = "DocDB_Cretential_${random_string.random.result}"
  description = "This is the secret for Amazon DocumentDB cretential. This secret has a dynamically generated secret password"

  secret_string = jsonencode({
      username = var.docdb_username,
      password = random_password.docdb.result
  })

  kms_key_id = module.symmetric_key.key_arn
}


resource "aws_docdb_cluster_instance" "docdb_instances" {
  count              = 1
  identifier         = "docdb-cluster-${count.index}"
  cluster_identifier = aws_docdb_cluster.docdb_cluster.id
  instance_class     = "db.t3.medium"
}


resource "aws_docdb_cluster" "docdb_cluster" {
  cluster_identifier      = "my-docdb-cluster"
  engine                  = "docdb"
  master_username         = var.docdb_username
  master_password         = random_password.docdb.result
  backup_retention_period = 5
  skip_final_snapshot     = true
  db_subnet_group_name    = module.vpc.database_subnet_group
  vpc_security_group_ids  = [module.msk_sg.security_group_id]
}
