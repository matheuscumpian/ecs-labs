# Security Group

resource "aws_security_group" "alb_sg" {
  name   = "${var.project_name}-${var.environment}-sg"
  vpc_id = var.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-sg"
    }
  )
}

resource "aws_security_group_rule" "alb_http_ingress" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.alb_sg.id
  cidr_blocks       = ["0.0.0.0/0"]

  depends_on = [aws_security_group.alb_sg]
}

resource "aws_security_group_rule" "alb_http_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.alb_sg.id
  cidr_blocks       = ["0.0.0.0/0"]

  depends_on = [aws_security_group.alb_sg]
}

resource "aws_security_group_rule" "alb_https_ingress" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.alb_sg.id
  cidr_blocks       = ["0.0.0.0/0"]

  depends_on = [aws_security_group.alb_sg]
}


# ALB

resource "aws_alb" "main" {
  name                       = "${var.project_name}-${var.environment}-alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb_sg.id]
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


  depends_on = [aws_security_group.alb_sg]
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

  depends_on = [aws_alb.main]
}

# SG Rules for ECS Nodes

resource "aws_security_group" "ecs_node_sg" {
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
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.ecs_node_sg.id

  cidr_blocks = [var.vpc_cidr]

  depends_on = [aws_security_group.ecs_node_sg]
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



# Launch template

locals {
  user_data = <<-EOF
#!/bin/bash
echo ECS_CLUSTER=${aws_ecs_cluster.main.name} >> /etc/ecs/ecs.config
EOF
}

resource "aws_launch_template" "main-on-demand" {
  name_prefix = "${var.project_name}-${var.environment}-"
  image_id    = data.aws_ssm_parameter.ecs_optimized.value

  instance_type = "t4g.small"

  vpc_security_group_ids = [aws_security_group.ecs_node_sg.id]

  update_default_version = true

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = 30
      volume_type = "gp3"
    }
  }

  iam_instance_profile {
    name = "ecsInstanceRole"
  }


  tag_specifications {
    resource_type = "instance"
    tags = merge(
      local.common_tags,
      {
        Name = "${var.project_name}-${var.environment}-ecs-node"
      }
    )
  }

  user_data = base64encode(local.user_data)

  depends_on = [aws_security_group.ecs_node_sg]
}

# ASG

resource "aws_autoscaling_group" "main" {
  name = "${var.project_name}-${var.environment}-asg"

  launch_template {
    id      = aws_launch_template.main-on-demand.id
    version = "$Latest"
  }

  min_size                  = 1
  max_size                  = 5
  desired_capacity          = 1
  vpc_zone_identifier       = var.private_subnet_ids
  health_check_type         = "EC2"
  health_check_grace_period = 300
  target_group_arns         = [aws_alb_target_group.main.arn]
  termination_policies      = ["OldestInstance"]

  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupPendingInstances",
    "GroupStandbyInstances",
    "GroupTerminatingInstances",
    "GroupTotalInstances",
  ]

  tag {
    key                 = "Name"
    value               = "${var.project_name}-${var.environment}-ecs-node"
    propagate_at_launch = true
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = "true"
    propagate_at_launch = true
  }

  depends_on = [aws_launch_template.main-on-demand]
}

resource "aws_alb_target_group_attachment" "main" {
  target_group_arn = aws_alb_target_group.main.arn
  target_id        = aws_autoscaling_group.main.id
  port             = 80

  depends_on = [aws_autoscaling_group.main]
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
