variable "name_prefix" { type = string }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "grafana_security_group_id" { type = string }
variable "instance_class" { type = string }
variable "allocated_storage" { type = number }
variable "backup_retention_days" { type = number }
variable "master_username" { type = string }
variable "master_password" {
  type      = string
  sensitive = true
}

resource "aws_db_subnet_group" "this" {
  name_prefix = "${var.name_prefix}-"
  subnet_ids  = var.private_subnet_ids

  tags = {
    Name = "${var.name_prefix}-rds-subnet"
  }
}

resource "aws_security_group" "rds" {
  name_prefix = "${var.name_prefix}-rds-"
  description = "PostgreSQL for Grafana"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from Grafana"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.grafana_security_group_id]
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

resource "aws_db_instance" "this" {
  identifier     = "${var.name_prefix}-postgres"
  engine         = "postgres"
  engine_version = "15"

  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage
  storage_encrypted = true

  db_name  = "grafana"
  username = var.master_username
  password = var.master_password

  multi_az               = true
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  backup_retention_period = var.backup_retention_days
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.name_prefix}-final-snapshot"

  deletion_protection = true

  tags = {
    Name = "${var.name_prefix}-rds"
  }
}

output "endpoint" {
  value = aws_db_instance.this.address
}

output "database_name" {
  value = aws_db_instance.this.db_name
}

output "instance_id" {
  value = aws_db_instance.this.id
}
