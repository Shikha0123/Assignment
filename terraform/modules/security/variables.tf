variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "container_port" {
  description = "Port the application container listens on"
  type        = number
  default     = 8080
}

variable "db_port" {
  description = "Port the database listens on (5432 for Postgres, 3306 for MySQL)"
  type        = number
  default     = 5432
}

variable "tags" {
  type    = map(string)
  default = {}
}
