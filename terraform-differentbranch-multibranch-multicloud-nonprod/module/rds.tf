##################################################### Security Group for RDS ############################################################

resource "aws_security_group" "rds_sg" {
 name        = "RDS-Security-Group-${var.env[0]}"
 description = "Allow All Traffic"
 vpc_id      = aws_vpc.test_vpc.id             ###var.vpc_id

ingress {
   description = "Allow All Traffic"
   from_port   = 5432
   to_port     = 5432
   protocol    = "tcp"
   cidr_blocks = ["10.10.0.0/16"]    ### Allow all traffic for Azure VNet CIDR
 }

egress {
   from_port   = 0
   to_port     = 0
   protocol    = "-1"
   cidr_blocks = ["0.0.0.0/0"]
 }
}

###################################################### RDS Subnet Group ################################################################## 

#resource "aws_db_parameter_group" "dbparametedgroup" {
#  name   = "rds-pg"
#  family = "mysql5.7"
#  description = "Parameter Group For RDS"

###It is also possible that we cann't provide the parametes
#  parameter {
#    name  = "character_set_server"
#    value = "utf8"
#  }

#  parameter {
#    name  = "character_set_client"
#    value = "utf8"
#  }
#}

resource "aws_db_subnet_group" "dbsubnet" {
  name = var.db_subnet_group_name
  description = "RDS DB Subnet Group"
  subnet_ids = concat(aws_subnet.public_subnet[*].id, aws_subnet.private_subnet[*].id) ##You should change this value as per your vpc subnet
}

######################################### Launch RDS PostgreSQL DB Instance ##############################################

resource "aws_db_instance" "dbinstance1" {
  identifier           = var.identifier
  allocated_storage    = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type         = var.storage_type
  engine               = var.engine
  engine_version       = var.engine_version      ### var.engine_version[11] use for postgresql
  instance_class       = var.instance_class
  db_name              = "demodb"
  username             = var.username
  password             = var.password
  parameter_group_name = var.parameter_group_name           ### var.parameter_group_name[1] use for postgresql
  multi_az             = var.multi_az
###  final_snapshot_identifier = var.final_snapshot_identifier ##To enable it skip_final_snapshot should be disabled
  skip_final_snapshot  = var.skip_final_snapshot   ##when skip_final_snapshot is true then final_snapshot_identifier should be commented
###  copy_tags_to_snapshot = var.copy_tags_to_snapshot[0]   ##You can enable it when final_snapshot_identifier is enable i.e. when final snapshot is enabled
###  availability_zone = var.availability_zone[0]  ## NOT ENABLE FOR MULTI-AZ OPTION
  vpc_security_group_ids = [aws_security_group.rds_sg.id]           ###var.vpc_security_group_ids
  db_subnet_group_name = aws_db_subnet_group.dbsubnet.name
###  parameter_group_name = aws_db_parameter_group.dbparametedgroup.name
  publicly_accessible = var.publicly_accessible
#  backup_retention_period = var.backup_retention_period[7]   ##Choose the number of days that RDS should retain automatic backups for this instance.
#  backup_window = "09:46-10:16"            ##(The daily time range (in UTC) during which automated backups are created if they are enabled. Example: "09:46-10:16". Must not overlap with maintenance window)
#  delete_automated_backups = true   ##(Specifies whether to remove automated backups immediately after the DB instance is deleted, default is true)
#  maintenance_window = "Mon:00:00-Mon:03:00" ##The window to perform maintenance in Syntax: "ddd:hh24:mi-ddd:hh24:mi" Eg: "Mon:00:00-Mon:03:00"
  deletion_protection = false ##SHOULD BE ENABLED FOR PRODUCTION ENVIRONMENT
  storage_encrypted = true
  kms_key_id = var.kms_key_id_rds    ##The ARN for the KMS encryption key. If creating an encrypted replica, set this to the destination KMS ARN.
  apply_immediately = true  ##Specifies whether any database modifications are applied immediately, or during the next maintenance window, default is false
###  replicate_source_db  ##This correlates to the identifier of another Amazon RDS Database to replicate (if replicating within a single region) or ARN of the Amazon RDS Database to replicate (if replicating cross-region).
#  auto_minor_version_upgrade = true ## true or false
  monitoring_role_arn = var.monitoring_role_arn ##arn:aws:iam::0XXXXXXXXXXXXX6:role/rds-monitoring-role
  monitoring_interval = 5 ##The interval, in seconds, between points when Enhanced Monitoring metrics are collected for the DB instance. To disable collecting Enhanced Monitoring metrics, specify 0. The default is 0. Valid Values: 0, 1, 5, 10, 15, 30, 60.
  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports     ###    ["audit", "error", "general", "slowquery"] for MySQL      ### ["postgresql", "upgrade"]  Use for PostgreSQL
  tags = {         ##use tags as required
  Environment = var.env[0]
  }
}
