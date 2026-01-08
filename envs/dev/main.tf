module "platform" {
  source = "../.."

  aws_region          = var.aws_region
  environment         = var.environment
  project_name        = var.project_name
  tags                = var.tags
  vpc_cidr            = var.vpc_cidr
  az_count            = var.az_count
  nat_gateway_count   = var.nat_gateway_count
  subnet_bits         = var.subnet_bits
  enable_sts_endpoint = var.enable_sts_endpoint

  ecr_repositories        = var.ecr_repositories
  ecr_scan_on_push        = var.ecr_scan_on_push
  ecr_lifecycle_keep_last = var.ecr_lifecycle_keep_last

  eks_cluster_name        = var.eks_cluster_name
  kubernetes_version      = var.kubernetes_version
  endpoint_private_access = var.endpoint_private_access
  endpoint_public_access  = var.endpoint_public_access
  public_access_cidrs     = var.public_access_cidrs
  node_instance_types     = var.node_instance_types
  node_min_size           = var.node_min_size
  node_max_size           = var.node_max_size
  node_desired_size       = var.node_desired_size
  node_disk_size          = var.node_disk_size
  node_capacity_type      = var.node_capacity_type
  enable_irsa             = var.enable_irsa
  oidc_thumbprint         = var.oidc_thumbprint
}

output "cluster_name" {
  value = module.platform.cluster_name
}

output "region" {
  value = module.platform.region
}

output "oidc_issuer_url" {
  value = module.platform.oidc_issuer_url
}

output "oidc_provider_arn" {
  value = module.platform.oidc_provider_arn
}

output "vpc_id" {
  value = module.platform.vpc_id
}

output "private_subnet_ids" {
  value = module.platform.private_subnet_ids
}

output "ecr_repository_urls" {
  value = module.platform.ecr_repository_urls
}

output "cluster_endpoint" {
  value = module.platform.cluster_endpoint
}

output "cluster_security_group_id" {
  value = module.platform.cluster_security_group_id
}

output "node_role_arn" {
  value = module.platform.node_role_arn
}
