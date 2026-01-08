output "region" {
  description = "AWS region."
  value       = var.aws_region
}

output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint."
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "EKS cluster security group ID."
  value       = module.eks.cluster_security_group_id
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL for IRSA."
  value       = module.eks.oidc_issuer_url
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA."
  value       = module.eks.oidc_provider_arn
}

output "node_role_arn" {
  description = "IAM role ARN for EKS managed node group."
  value       = module.eks.node_role_arn
}

output "vpc_id" {
  description = "VPC ID."
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs."
  value       = module.vpc.private_subnet_ids
}

output "ecr_repository_urls" {
  description = "Map of ECR repository URLs."
  value       = module.ecr.repository_urls
}
