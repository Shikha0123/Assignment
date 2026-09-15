variable "environment" {
  type = string
}

variable "private_app_subnet_ids" {
  type = list(string)
}

variable "ecs_sg_id" {
  type = string
}

variable "target_group_arn" {
  type = string
}

variable "container_image" {
  description = "Container image to run (e.g. <account>.dkr.ecr.<region>.amazonaws.com/tripare-app:latest)"
  type        = string
  default     = "public.ecr.aws/docker/library/nginx:latest"
}

variable "container_port" {
  type    = number
  default = 8080
}

variable "task_cpu" {
  description = "Fargate task CPU units (256 = 0.25 vCPU)"
  type        = string
  default     = "256"
}

variable "task_memory" {
  description = "Fargate task memory in MiB"
  type        = string
  default     = "512"
}

variable "desired_count" {
  description = "Number of ECS tasks to run"
  type        = number
  default     = 1
}

variable "db_host" {
  description = "RDS endpoint injected into the container as an env var"
  type        = string
}

variable "db_name" {
  type = string
}

variable "db_secret_arn" {
  description = "Secrets Manager ARN holding the DB credentials, injected securely into the container"
  type        = string
}

variable "aws_region" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
