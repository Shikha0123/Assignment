aws_region = "us-east-1"
azs        = ["us-east-1a", "us-east-1b"]

container_image = "public.ecr.aws/docker/library/nginx:latest"
container_port  = 80

db_engine                  = "postgres"
db_instance_class          = "db.t3.micro"
db_allocated_storage       = 20
db_backup_retention_period = 1     # dev: short retention
db_deletion_protection     = false # dev: allow fast teardown
db_multi_az                = false

ecs_task_cpu      = "256"
ecs_task_memory   = "512"
ecs_desired_count = 1
