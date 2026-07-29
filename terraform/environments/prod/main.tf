terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  grafana_root_url = var.use_custom_domain ? "https://${var.domain_name}" : "http://${module.alb.dns_name}"
}

check "custom_domain_inputs" {
  assert {
    condition = (
      !var.use_custom_domain
      || (var.domain_name != null && var.domain_name != "" && var.hosted_zone_id != null && var.hosted_zone_id != "")
    )
    error_message = "Set domain_name and hosted_zone_id when use_custom_domain is true."
  }
}

module "logging" {
  source = "../../modules/logging"

  name_prefix   = local.name_prefix
  force_destroy = var.poc_mode
}

module "vpc" {
  source = "../../modules/vpc"

  name_prefix          = local.name_prefix
  vpc_cidr             = var.vpc_cidr
  enable_flow_logs     = var.enable_vpc_flow_logs
  flow_logs_bucket_arn = var.enable_vpc_flow_logs ? module.logging.logs_bucket_arn : null
}

module "secrets" {
  source = "../../modules/secrets"

  name_prefix = local.name_prefix
  poc_mode    = var.poc_mode
}

module "dns" {
  count  = var.use_custom_domain ? 1 : 0
  source = "../../modules/dns"

  domain_name    = var.domain_name
  hosted_zone_id = var.hosted_zone_id
  create_cert    = true
  create_record  = false
}

module "alb" {
  source = "../../modules/alb"

  name_prefix           = local.name_prefix
  vpc_id                = module.vpc.vpc_id
  public_subnet_ids     = module.vpc.public_subnet_ids
  enable_https          = var.use_custom_domain
  certificate_arn       = var.use_custom_domain ? module.dns[0].certificate_arn : null
  allowed_ingress_cidrs = var.allowed_ingress_cidrs
  access_logs_bucket    = var.enable_alb_access_logs ? module.logging.logs_bucket_id : null
}

module "security" {
  source = "../../modules/security"

  name_prefix           = local.name_prefix
  vpc_id                = module.vpc.vpc_id
  alb_security_group_id = module.alb.security_group_id
}

module "rds" {
  source = "../../modules/rds"

  name_prefix               = local.name_prefix
  vpc_id                    = module.vpc.vpc_id
  private_subnet_ids        = module.vpc.private_subnet_ids
  grafana_security_group_id = module.security.grafana_security_group_id
  instance_class            = var.rds_instance_class
  allocated_storage         = var.rds_allocated_storage
  backup_retention_days     = var.poc_mode ? 0 : var.rds_backup_retention_days
  master_username           = module.secrets.rds_username
  master_password           = module.secrets.rds_password
  poc_mode                  = var.poc_mode
}

module "asg" {
  source = "../../modules/asg"

  name_prefix               = local.name_prefix
  vpc_id                    = module.vpc.vpc_id
  private_subnet_ids        = module.vpc.private_subnet_ids
  ami_id                    = var.grafana_ami_id
  instance_type             = var.instance_type
  target_group_arn          = module.alb.target_group_arn
  grafana_security_group_id = module.security.grafana_security_group_id
  min_size                  = var.asg_min_size
  desired_capacity          = var.asg_desired_capacity
  max_size                  = var.asg_max_size
  secrets_arn               = module.secrets.grafana_config_secret_arn
  rds_endpoint              = module.rds.endpoint
  rds_database_name         = module.rds.database_name
  grafana_root_url          = local.grafana_root_url
  prometheus_url            = var.prometheus_url
  ansible_repo_url          = var.ansible_repo_url
}

module "dns_record" {
  count  = var.use_custom_domain ? 1 : 0
  source = "../../modules/dns"

  domain_name    = var.domain_name
  hosted_zone_id = var.hosted_zone_id
  alb_dns_name   = module.alb.dns_name
  alb_zone_id    = module.alb.zone_id
  create_cert    = false
  create_record  = true
}

module "monitoring" {
  source = "../../modules/monitoring"

  name_prefix             = local.name_prefix
  alb_arn_suffix          = module.alb.arn_suffix
  target_group_arn_suffix = module.alb.target_group_arn_suffix
  rds_instance_id         = module.rds.instance_id
  sns_topic_email         = null
}
