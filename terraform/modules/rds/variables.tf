variable "environment" {
  type = string
}

variable "private_db_subnet_ids" {
  type = list(string)
}

variable "rds_sg_id" {
  type = string
}

variable "engine" {
  description = "postgres or mysql"
  type        = string
  default     = "postgres"
}

variable "engine_version" {
  type    = string
  default = "16.4"
}

variable "instance_class" {
  type = string
}

variable "allocated_storage" {
  type = number
}

variable "max_allocated_storage" {
  description = "Upper bound for storage autoscaling"
  type        = number
  default     = 100
}

variable "db_name" {
  type    = string
  default = "tripare"
}

variable "db_username" {
  type    = string
  default = "tripare_admin"
}

variable "backup_retention_period" {
  description = "Days to retain automated backups. Short for dev, long for prod."
  type        = number
}

variable "deletion_protection" {
  description = "false in dev (fast iteration), true in prod (safety)"
  type        = bool
}

variable "multi_az" {
  description = "High availability multi-AZ deployment (true in prod, false in dev)"
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  type    = bool
  default = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
