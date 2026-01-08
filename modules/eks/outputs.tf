output "cluster_name" {
  description = "EKS cluster name."
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_security_group_id" {
  description = "EKS cluster security group ID."
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL for IRSA."
  value       = local.oidc_issuer_url
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA."
  value       = var.enable_irsa ? aws_iam_openid_connect_provider.this[0].arn : null
}

output "node_role_arn" {
  description = "IAM role ARN for node group."
  value       = aws_iam_role.node.arn
}
