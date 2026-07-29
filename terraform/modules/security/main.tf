variable "name_prefix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "alb_security_group_id" {
  type = string
}

resource "aws_security_group" "grafana" {
  name_prefix = "${var.name_prefix}-grafana-"
  description = "Grafana EC2 instances"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Grafana from ALB"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

output "grafana_security_group_id" {
  value = aws_security_group.grafana.id
}
