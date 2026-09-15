aws_region = "us-east-1"
azs        = ["us-east-1a", "us-east-1b"]

container_image = "public.ecr.aws/docker/library/nginx:latest"
container_port  = 8080

db_engine                  = "postgres"
db_instance_class          = "db.t3.large"
db_allocated_storage       = 100
db_backup_retention_period = 30   # prod: long retention
db_deletion_protection     = true # prod: protect against accidental deletion
db_multi_az                = true

ecs_task_cpu      = "1024"
ecs_task_memory   = "2048"
ecs_desired_count = 3
