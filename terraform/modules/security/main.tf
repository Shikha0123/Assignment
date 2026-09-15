# ---------------------------------------------------------------------------
# Security groups implementing strict tier-to-tier segmentation:
#   Internet -> ALB SG (80/443 open)
#   ALB SG   -> ECS SG (container_port only, from ALB SG)
#   ECS SG   -> RDS SG (db_port only, from ECS SG)
# The RDS security group never accepts traffic from anywhere except the ECS
# security group, so the database is unreachable from the ALB or the
# internet even if someone gets its endpoint.
# ---------------------------------------------------------------------------

locals {
  name_prefix = "tripare-${var.environment}"
}

resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Allow inbound HTTP/HTTPS from the internet to the ALB"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound (to reach ECS tasks)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${local.name_prefix}-alb-sg" })
}

resource "aws_security_group" "ecs" {
  name        = "${local.name_prefix}-ecs-sg"
  description = "Allow inbound traffic only from the ALB on the container port"
  vpc_id      = var.vpc_id

  ingress {
    description     = "App traffic from ALB only"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow all outbound (to reach RDS, pull images, call AWS APIs)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${local.name_prefix}-ecs-sg" })
}

resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds-sg"
  description = "Allow inbound traffic only from the ECS tasks on the db port"
  vpc_id      = var.vpc_id

  ingress {
    description     = "DB traffic from ECS tasks only"
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  # No egress rule needed for RDS in practice, but AWS default behavior
  # without an explicit egress block is to deny all outbound. We leave it
  # implicit/deny-all here intentionally -- the DB tier has no reason to
  # initiate outbound connections.

  tags = merge(var.tags, { Name = "${local.name_prefix}-rds-sg" })
}
