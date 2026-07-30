variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Short project name used in resource naming"
  type        = string
  default     = "grafana-platform"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "domain_name" {
  description = "FQDN for Grafana (e.g. grafana.example.com). Required when use_custom_domain is true."
  type        = string
  default     = null
  nullable    = true
}

variable "hosted_zone_id" {
  description = "Route 53 hosted zone ID for domain_name. Required when use_custom_domain is true."
  type        = string
  default     = null
  nullable    = true
}

variable "use_custom_domain" {
  description = "When true (production), Route 53 + ACM HTTPS on your domain. When false, ALB DNS over HTTP only (POC / no domain)."
  type        = bool
  default     = true
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "grafana_ami_id" {
  description = "AMI ID from Packer build (or SSM parameter path)"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for Grafana nodes"
  type        = string
  default     = "t3.medium"
}

variable "asg_min_size" {
  type    = number
  default = 2
}

variable "asg_desired_capacity" {
  type    = number
  default = 2
}

variable "asg_max_size" {
  type    = number
  default = 5
}

variable "rds_instance_class" {
  type    = string
  default = "db.t3.medium"
}

variable "rds_allocated_storage" {
  type    = number
  default = 50
}

variable "rds_backup_retention_days" {
  type    = number
  default = 14
}

variable "allowed_ingress_cidrs" {
  description = "CIDR blocks allowed to reach ALB HTTPS (use client IPs for whitelisting)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "prometheus_url" {
  description = "Client Prometheus base URL (configured in Ansible)"
  type        = string
  default     = ""
}

variable "enable_vpc_flow_logs" {
  type    = bool
  default = true
}

variable "enable_alb_access_logs" {
  type    = bool
  default = true
}

variable "ansible_repo_url" {
  description = "Optional Git URL for ansible-pull on instance bootstrap"
  type        = string
  default     = ""
}

variable "poc_mode" {
  description = "POC/sandbox: RDS destroy without protection or final snapshot, S3 force_destroy, secrets delete immediately. Set false for real production."
  type        = bool
  default     = false
}

variable "enable_destroy_protection" {
  description = "When true, Terraform blocks destroy on RDS, Secrets Manager, and logs S3 until set false. Defaults to true when poc_mode is false."
  type        = bool
  default     = null
  nullable    = true
}
