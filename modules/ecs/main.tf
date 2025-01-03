# Random String Generator for Unique Suffixes
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Common Tags (Recommended Best Practice)
locals {
  common_tags = merge(
    {
      Environment = var.environment
      Project     = var.project_name
    },
    var.additional_tags
  )
}

# Security Group for ALB
resource "aws_security_group" "alb_sg" {
  name   = "${var.project_name}-${var.environment}-alb-${random_string.suffix.result}"
  vpc_id = var.vpc_id

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-alb-${random_string.suffix.result}"
    }
  )
}

# Security Group Rules for ALB
resource "aws_security_group_rule" "alb_http_ingress" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.alb_sg.id
  cidr_blocks       = var.allowed_http_ingress_cidr_blocks
}

resource "aws_security_group_rule" "alb_https_ingress" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.alb_sg.id
  cidr_blocks       = var.allowed_https_ingress_cidr_blocks
}

resource "aws_security_group_rule" "alb_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.alb_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
}

# Security Group for ECS Nodes
resource "aws_security_group" "ecs_node_sg" {
  name        = "${var.project_name}-${var.environment}-ecs-node-${random_string.suffix.result}"
  vpc_id      = var.vpc_id
  description = "ECS Node Security Group"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-ecs-node-${random_string.suffix.result}"
    }
  )
}

resource "aws_security_group_rule" "ecs_node_ingress" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.ecs_node_sg.id
  cidr_blocks       = [var.vpc_cidr]
}

resource "aws_security_group_rule" "ecs_node_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.ecs_node_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
}

# ALB Configuration
resource "aws_alb" "main" {
  name                       = "${var.project_name}-${var.environment}-alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb_sg.id]
  subnets                    = var.public_subnet_ids
  enable_deletion_protection = false
  enable_http2               = true
  idle_timeout               = 60

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-alb"
    }
  )
}

# Listener and Target Group Configuration
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
}

resource "aws_alb_target_group" "main" {
  name     = "${var.project_name}-${var.environment}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# ECS Cluster Configuration
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

# Launch Template and ASG
locals {
  ecs_user_data = <<-EOF
#!/bin/bash
echo ECS_CLUSTER=${aws_ecs_cluster.main.name} >> /etc/ecs/ecs.config
EOF
}

resource "aws_launch_template" "main" {
  name_prefix            = "${var.project_name}-${var.environment}-"
  image_id               = data.aws_ssm_parameter.ecs_optimized.value
  instance_type          = "t3a.small"
  vpc_security_group_ids = [aws_security_group.ecs_node_sg.id]
  user_data              = base64encode(local.ecs_user_data)
  update_default_version = true

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 30
      volume_type = "gp2"
    }
  }

  tags = local.common_tags
}

resource "aws_autoscaling_group" "main" {
  name = "${var.project_name}-${var.environment}-asg"
  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }
  min_size                  = 1
  max_size                  = 5
  desired_capacity          = 1
  vpc_zone_identifier       = var.private_subnet_ids
  health_check_type         = "EC2"
  health_check_grace_period = 300

  target_group_arns = [aws_alb_target_group.main.arn]

  tag {
    key                 = "Name"
    value               = "${var.project_name}-${var.environment}-ecs-node"
    propagate_at_launch = true
  }
}
