variable "aws_region" {
  type        = string
  description = "AWS region for this environment."
  default     = "us-east-1"
}

variable "environment" {
  type        = string
  description = "Environment name."
  default     = "prod"
}

variable "project_name" {
  type        = string
  description = "Project name for resource naming."
  default     = "platform"
}

variable "tags" {
  type        = map(string)
  description = "Additional tags."
  default     = {}
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR."
  default     = "10.30.0.0/16"
}

variable "az_count" {
  type        = number
  description = "Number of AZs to use."
  default     = 3
}

variable "nat_gateway_count" {
  type        = number
  description = "Number of NAT gateways."
  default     = 2
}

variable "subnet_bits" {
  type        = number
  description = "Subnet bits used for CIDR carving."
  default     = 4
}

variable "enable_sts_endpoint" {
  type        = bool
  description = "Enable STS VPC endpoint."
  default     = true
}

variable "ecr_repositories" {
  type        = list(string)
  description = "ECR repositories to create."
  default     = []
}

variable "ecr_scan_on_push" {
  type        = bool
  description = "Enable ECR scan on push."
  default     = true
}

variable "ecr_lifecycle_keep_last" {
  type        = number
  description = "Images to keep per ECR repo."
  default     = 50
}

variable "eks_cluster_name" {
  type        = string
  description = "Optional EKS cluster name override."
  default     = null
}

variable "kubernetes_version" {
  type        = string
  description = "Optional Kubernetes version override."
  default     = null
}

variable "endpoint_private_access" {
  type        = bool
  description = "Enable private access to the EKS endpoint."
  default     = true
}

variable "endpoint_public_access" {
  type        = bool
  description = "Enable public access to the EKS endpoint."
  default     = false
}

variable "public_access_cidrs" {
  type        = list(string)
  description = "Allowed CIDRs for public EKS endpoint."
  default     = ["0.0.0.0/0"]
}

variable "node_instance_types" {
  type        = list(string)
  description = "Node instance types."
  default     = ["m5.large"]
}

variable "node_min_size" {
  type        = number
  description = "Minimum node group size."
  default     = 3
}

variable "node_max_size" {
  type        = number
  description = "Maximum node group size."
  default     = 10
}

variable "node_desired_size" {
  type        = number
  description = "Desired node group size."
  default     = 3
}

variable "node_disk_size" {
  type        = number
  description = "Node disk size (GiB)."
  default     = 50
}

variable "node_capacity_type" {
  type        = string
  description = "Node capacity type."
  default     = "ON_DEMAND"
}

variable "enable_irsa" {
  type        = bool
  description = "Enable IRSA."
  default     = true
}

variable "oidc_thumbprint" {
  type        = string
  description = "OIDC provider CA thumbprint."
  default     = "9e99a48a9960b14926bb7f3b02e22da0c0f8f9a1"
}
