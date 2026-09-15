variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "azs" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}

variable "container_image" {
  type    = string
  default = "public.ecr.aws/docker/library/nginx:latest"
}

variable "container_port" {
  type    = number
  default = 8080
}

variable "db_engine" {
  type    = string
  default = "postgres"
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.large"
}

variable "db_allocated_storage" {
  type    = number
  default = 100
}

variable "db_backup_retention_period" {
  type    = number
  default = 30
}

variable "db_deletion_protection" {
  type    = bool
  default = true
}

variable "db_multi_az" {
  type    = bool
  default = true
}

variable "ecs_task_cpu" {
  type    = string
  default = "1024"
}

variable "ecs_task_memory" {
  type    = string
  default = "2048"
}

variable "ecs_desired_count" {
  type    = number
  default = 3
}
