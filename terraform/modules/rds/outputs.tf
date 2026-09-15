output "db_endpoint" {
  value = aws_db_instance.this.address
}

output "db_port" {
  value = local.port
}

output "db_instance_id" {
  value = aws_db_instance.this.id
}

output "db_secret_arn" {
  value = aws_secretsmanager_secret.db_credentials.arn
}
