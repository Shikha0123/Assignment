locals {
  environment = "dev"
  tags        = {
    Project     = "tripare"
    Environment = local.environment
  }
}

module "network" {
  source = "../../modules/network"

  environment        = local.environment
  azs                = var.azs
  single_nat_gateway = true # dev: one shared NAT gateway to keep cost down
  tags               = local.tags
}

module "security" {
  source = "../../modules/security"

  environment    = local.environment
  vpc_id         = module.network.vpc_id
  container_port = var.container_port
  db_port        = var.db_engine == "postgres" ? 5432 : 3306
  tags           = local.tags
}

module "rds" {
  source = "../../modules/rds"

  environment           = local.environment
  private_db_subnet_ids = module.network.private_db_subnet_ids
  rds_sg_id             = module.security.rds_sg_id

  engine            = var.db_engine
  instance_class    = var.db_instance_class
  allocated_storage = var.db_allocated_storage

  # dev: smaller instance, shorter backup retention, deletion protection off
  backup_retention_period = var.db_backup_retention_period
  deletion_protection     = var.db_deletion_protection
  multi_az                = var.db_multi_az
  skip_final_snapshot     = true

  tags = local.tags
}

module "alb" {
  source = "../../modules/alb"

  environment       = local.environment
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
  alb_sg_id         = module.security.alb_sg_id
  container_port    = var.container_port

  tags = local.tags
}

module "ecs" {
  source = "../../modules/ecs"

  environment            = local.environment
  private_app_subnet_ids = module.network.private_app_subnet_ids
  ecs_sg_id              = module.security.ecs_sg_id
  target_group_arn       = module.alb.target_group_arn
  container_image        = var.container_image
  container_port         = var.container_port
  task_cpu               = var.ecs_task_cpu
  task_memory            = var.ecs_task_memory
  desired_count          = var.ecs_desired_count
  db_host                = module.rds.db_endpoint
  db_name                = "tripare"
  db_secret_arn          = module.rds.db_secret_arn
  aws_region             = var.aws_region

  tags = local.tags
}
