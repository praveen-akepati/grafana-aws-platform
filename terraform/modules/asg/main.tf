variable "name_prefix" { type = string }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "ami_id" { type = string }
variable "instance_type" { type = string }
variable "target_group_arn" { type = string }
variable "grafana_security_group_id" { type = string }
variable "min_size" { type = number }
variable "desired_capacity" { type = number }
variable "max_size" { type = number }
variable "secrets_arn" { type = string }
variable "rds_endpoint" { type = string }
variable "rds_database_name" { type = string }
variable "grafana_root_url" { type = string }
variable "prometheus_url" { type = string }
variable "ansible_repo_url" { type = string }

data "aws_region" "current" {}

resource "aws_iam_role" "grafana" {
  name_prefix = "${var.name_prefix}-ec2-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "grafana" {
  name_prefix = "${var.name_prefix}-ec2-"
  role        = aws_iam_role.grafana.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [var.secrets_arn]
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.grafana.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "grafana" {
  name_prefix = "${var.name_prefix}-"
  role        = aws_iam_role.grafana.name
}

resource "aws_launch_template" "grafana" {
  name_prefix   = "${var.name_prefix}-"
  image_id      = var.ami_id
  instance_type = var.instance_type

  iam_instance_profile {
    arn = aws_iam_instance_profile.grafana.arn
  }

  vpc_security_group_ids = [var.grafana_security_group_id]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size           = 30
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", {
    region            = data.aws_region.current.name
    secrets_arn       = var.secrets_arn
    rds_endpoint      = var.rds_endpoint
    rds_database_name = var.rds_database_name
    grafana_root_url  = var.grafana_root_url
    prometheus_url    = var.prometheus_url
    ansible_repo_url  = var.ansible_repo_url
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.name_prefix}-grafana"
      Role = "grafana"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "grafana" {
  name_prefix         = "${var.name_prefix}-"
  vpc_zone_identifier = var.private_subnet_ids
  target_group_arns   = [var.target_group_arn]
  health_check_type   = "ELB"
  health_check_grace_period = 300

  min_size         = var.min_size
  desired_capacity = var.desired_capacity
  max_size         = var.max_size

  launch_template {
    id      = aws_launch_template.grafana.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.name_prefix}-grafana"
    propagate_at_launch = true
  }

  tag {
    key                 = "Role"
    value               = "grafana"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_policy" "cpu_target" {
  name                   = "${var.name_prefix}-cpu-target"
  autoscaling_group_name = aws_autoscaling_group.grafana.name
  policy_type            = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

output "asg_name" {
  value = aws_autoscaling_group.grafana.name
}
