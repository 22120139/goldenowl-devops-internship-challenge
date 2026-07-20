locals {
  image_parameter_name = "/${var.project_name}/image-uri"
}

resource "aws_ssm_parameter" "app_image" {
  name        = local.image_parameter_name
  description = "Docker image deployed by the Auto Scaling Group"
  type        = "String"

  value = "${aws_ecr_repository.app.repository_url}:${var.image_tag}"

  lifecycle {
    ignore_changes = [
      value
    ]
  }
}

resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-alb-"
  description = "Allow public HTTP access to the load balancer"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Public HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "autoscaling_instances" {
  name_prefix = "${var.project_name}-asg-"
  description = "Allow application traffic only from the load balancer"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Application traffic from ALB"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"

    security_groups = [
      aws_security_group.alb.id
    ]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_target_group" "app" {
  name        = var.project_name
  port        = 3000
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = data.aws_vpc.default.id

  deregistration_delay = 30

  health_check {
    enabled             = true
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb" "app" {
  name               = var.project_name
  internal           = false
  load_balancer_type = "application"

  security_groups = [
    aws_security_group.alb.id
  ]

  subnets = data.aws_subnets.default.ids
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_launch_template" "app" {
  name_prefix   = "${var.project_name}-"
  image_id      = data.aws_ssm_parameter.amazon_linux_2023_ami.value
  instance_type = var.instance_type

  update_default_version = true

  iam_instance_profile {
    name = aws_iam_instance_profile.app.name
  }

  network_interfaces {
    associate_public_ip_address = true

    security_groups = [
      aws_security_group.autoscaling_instances.id
    ]
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh.tftpl", {
    aws_region           = var.aws_region
    image_parameter_name = local.image_parameter_name
  }))

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_type           = "gp3"
      volume_size           = 8
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${var.project_name}-asg"
    }
  }

  tag_specifications {
    resource_type = "volume"

    tags = {
      Name = "${var.project_name}-asg"
    }
  }
}

resource "aws_autoscaling_group" "app" {
  name = var.project_name

  min_size         = 2
  desired_capacity = 2
  max_size         = 4

  vpc_zone_identifier = data.aws_subnets.default.ids

  target_group_arns = [
    aws_lb_target_group.app.arn
  ]

  health_check_type         = "ELB"
  health_check_grace_period = 180
  default_instance_warmup   = 120

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 120
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-asg"
    propagate_at_launch = true
  }

  lifecycle {
    ignore_changes = [
      desired_capacity
    ]
  }

  depends_on = [
    aws_lb_listener.http
  ]
}

resource "aws_autoscaling_policy" "cpu" {
  name                   = "${var.project_name}-cpu-target"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 50
  }
}
