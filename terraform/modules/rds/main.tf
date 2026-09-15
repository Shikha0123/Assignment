# ---------------------------------------------------------------------------
# RDS module - the data tier.
# Lives in the private "db" subnets with no internet route at all, and its
# security group only accepts connections from the ECS security group.
# Environment-specific safety knobs (backup retention, deletion protection,
# instance size, multi-AZ) are all passed in from the calling environment
# (dev/prod), not hardcoded here.
# ---------------------------------------------------------------------------

locals {
  name_prefix = "tripare-${var.environment}"
  port        = var.engine == "postgres" ? 5432 : 3306
}

resource "random_password" "master" {
  length           = 24
  special          = true
  override_special = "!#$%^&*()-_=+[]{}"
}

resource "aws_db_subnet_group" "this" {
  name       = "${local.name_prefix}-db-subnet-group"
  subnet_ids = var.private_db_subnet_ids

  tags = merge(var.tags, { Name = "${local.name_prefix}-db-subnet-group" })
}

resource "aws_db_instance" "this" {
  identifier     = "${local.name_prefix}-db"
  engine         = var.engine == "postgres" ? "postgres" : "mysql"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.master.result
  port     = local.port

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.rds_sg_id]
  publicly_accessible    = false

  multi_az = var.multi_az

  # --- environment-driven safety settings ---
  backup_retention_period   = var.backup_retention_period
  backup_window             = "03:00-04:00"
  maintenance_window        = "mon:04:30-mon:05:30"
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${local.name_prefix}-final-snapshot"

  auto_minor_version_upgrade = true
  apply_immediately          = var.environment != "prod"

  tags = merge(var.tags, { Name = "${local.name_prefix}-db" })
}

# Store the generated credentials in Secrets Manager rather than in state
# output or a tfvars file, so ECS can pull them securely at container start.
resource "aws_secretsmanager_secret" "db_credentials" {
  name = "${local.name_prefix}-db-credentials"
  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id     = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.master.result
    host     = aws_db_instance.this.address
    port     = local.port
    dbname   = var.db_name
  })
}
