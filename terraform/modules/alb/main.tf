# ---------------------------------------------------------------------------
# Application Load Balancer - the public entry point.
# Internet -> [this ALB, public subnets] -> target group -> ECS/Fargate tasks
# ---------------------------------------------------------------------------

locals {
  name_prefix = "tripare-${var.environment}"
}

resource "aws_lb" "this" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = var.environment == "prod" ? true : false

  tags = merge(var.tags, { Name = "${local.name_prefix}-alb" })
}

resource "aws_lb_target_group" "app" {
  name        = "${local.name_prefix}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip" # required for Fargate tasks

  health_check {
    path                = var.health_check_path
    protocol            = "HTTP"
    matcher             = "200-299"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = merge(var.tags, { Name = "${local.name_prefix}-tg" })
}

# Plain HTTP listener. In a real production rollout this would redirect to
# HTTPS on 443 behind an ACM certificate; kept to HTTP here to avoid
# requiring a domain/certificate for this assessment. Documented as a
# follow-up in the README.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
