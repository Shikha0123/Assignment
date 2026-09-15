output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "vpc_id" {
  value = module.network.vpc_id
}

output "db_endpoint" {
  value = module.rds.db_endpoint
}

output "ecs_cluster_id" {
  value = module.ecs.cluster_id
}
