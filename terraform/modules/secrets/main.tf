variable "name_prefix" { type = string }

variable "poc_mode" {
  description = "When true, delete secrets immediately on destroy (no recovery window)."
  type        = bool
  default     = false
}

resource "random_password" "rds" {
  length  = 32
  special = false
}

resource "random_password" "grafana_admin" {
  length  = 24
  special = true
}

resource "aws_secretsmanager_secret" "grafana_config" {
  name_prefix = "${var.name_prefix}-grafana-config-"
  description = "Grafana and RDS configuration for Ansible/runtime"

  recovery_window_in_days = var.poc_mode ? 0 : 7
}

resource "aws_secretsmanager_secret_version" "grafana_config" {
  secret_id = aws_secretsmanager_secret.grafana_config.id
  secret_string = jsonencode({
    grafana_admin_user     = "admin"
    grafana_admin_password = random_password.grafana_admin.result
    rds_username           = "grafana"
    rds_password           = random_password.rds.result
    prometheus_url         = ""
  })

}

output "grafana_config_secret_arn" {
  value = aws_secretsmanager_secret.grafana_config.arn
}

output "rds_username" {
  value = "grafana"
}

output "rds_password" {
  value     = random_password.rds.result
  sensitive = true
}
