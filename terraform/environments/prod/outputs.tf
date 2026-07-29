output "grafana_url" {
  description = "Grafana URL (ALB DNS for POC, or custom domain when use_custom_domain is true)"
  value       = var.use_custom_domain ? "https://${var.domain_name}" : module.alb.grafana_url
}

output "alb_dns_name" {
  value = module.alb.dns_name
}

output "rds_endpoint" {
  description = "RDS endpoint (sensitive — also in Secrets Manager)"
  value       = module.rds.endpoint
  sensitive   = true
}

output "grafana_config_secret_arn" {
  value = module.secrets.grafana_config_secret_arn
}

output "asg_name" {
  value = module.asg.asg_name
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}
