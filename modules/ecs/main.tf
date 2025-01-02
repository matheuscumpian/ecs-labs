# Security Group

resource "aws_security_group" "main" {
  name   = "${var.project_name}-${var.environment}-sg"
  vpc_id = var.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-sg"
    }
  )
}

resource "aws_security_group_rule" "http_ingress" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.main.id
  cidr_blocks       = ["0.0.0.0/0"]

  depends_on = [aws_security_group.main]
}

resource "aws_security_group_rule" "http_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.main.id
  cidr_blocks       = ["0.0.0.0/0"]

  depends_on = [aws_security_group.main]
}

resource "aws_security_group_rule" "https_ingress" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.main.id
  cidr_blocks       = ["0.0.0.0/0"]

  depends_on = [aws_security_group.main]
}


# ALB

resource "aws_alb" "main" {
  name                       = "${var.project_name}-${var.environment}-alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.main.id]
  subnets                    = var.public_subnet_ids
  enable_deletion_protection = false
  enable_http2               = true

  idle_timeout = 60

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-alb"
    }
  )


  depends_on = [aws_security_group.main]
}

resource "aws_alb_listener" "http" {
  load_balancer_arn = aws_alb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Hello, World!"
      status_code  = "200"
    }
  }

  depends_on = [aws_alb.main]
}

# SG Rules

resource "aws_security_group" "ecs_node" {
  name        = "${var.project_name}-${var.environment}-ecs-node-sg"
  vpc_id      = var.vpc_id
  description = "ECS Node Security Group"

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-ecs-node-sg"
    }
  )
}

resource "aws_security_group_rule" "ecs_node_ingress" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.ecs_node.id
  source_security_group_id = aws_security_group.main.id
  cidr_blocks              = [var.vpc_cidr]

  depends_on = [aws_security_group.ecs_node]
}

# ECS Cluster

resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-${var.environment}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-cluster"
    }
  )
}


# SSM Parameters

resource "aws_ssm_parameter" "ecs_cluster_name" {
  name  = "/${var.project_name}/${var.environment}/ecs_cluster_name"
  type  = "String"
  value = aws_ecs_cluster.main.name

  depends_on = [aws_ecs_cluster.main]

  lifecycle {
    create_before_destroy = true
  }

  tags = local.common_tags
}

resource "aws_ssm_parameter" "alb_dns_name" {
  name  = "/${var.project_name}/${var.environment}/alb_dns_name"
  type  = "String"
  value = aws_alb.main.dns_name

  depends_on = [aws_alb.main]

  lifecycle {
    create_before_destroy = true
  }

  tags = local.common_tags
}

resource "aws_ssm_parameter" "alb_arn" {
  name  = "/${var.project_name}/${var.environment}/alb_arn"
  type  = "String"
  value = aws_alb.main.arn

  depends_on = [aws_alb.main]

  lifecycle {
    create_before_destroy = true
  }

  tags = local.common_tags
}
