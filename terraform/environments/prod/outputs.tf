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

output "destroy_protection_enabled" {
  description = "When true, terraform destroy is blocked on RDS, secrets, and logs S3 until protection is disabled."
  value       = local.destroy_protection
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "vpc_cidr" {
  description = "VPC CIDR — share with client for VPN/firewall rules."
  value       = module.vpc.vpc_cidr
}

output "nat_gateway_public_ip" {
  description = "NAT egress IP from Grafana EC2 — share with client only if using HTTPS IP allowlist."
  value       = module.vpc.nat_gateway_public_ip
}
