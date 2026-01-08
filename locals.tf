variable "aws_region" {
  type        = string
  description = "AWS region for all resources."
}

variable "environment" {
  type        = string
  description = "Deployment environment name (dev|stage|prod)."

  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment)
    error_message = "environment must be one of: dev, stage, prod."
  }
}

variable "project_name" {
  type        = string
  description = "Project or platform name used for resource naming."
  default     = "platform"
}

variable "tags" {
  type        = map(string)
  description = "Additional tags to apply to all resources."
  default     = {}
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC."
}

variable "az_count" {
  type        = number
  description = "Number of availability zones to use (2 or 3)."
  default     = 2
}

variable "nat_gateway_count" {
  type        = number
  description = "Number of NAT gateways to create (1 or az_count)."
  default     = 1
}

variable "subnet_bits" {
  type        = number
  description = "Additional subnet bits used to carve subnets from the VPC CIDR."
  default     = 4
}

variable "enable_sts_endpoint" {
  type        = bool
  description = "Enable VPC interface endpoint for STS (disable if unsupported in region)."
  default     = true
}

variable "ecr_repositories" {
  type        = list(string)
  description = "List of ECR repositories to create."
  default     = []
}

variable "ecr_scan_on_push" {
  type        = bool
  description = "Enable ECR image scanning on push."
  default     = true
}

variable "ecr_lifecycle_keep_last" {
  type        = number
  description = "Number of images to keep in each ECR repository."
  default     = 30
}

variable "eks_cluster_name" {
  type        = string
  description = "Optional EKS cluster name override."
  default     = null
}

variable "kubernetes_version" {
  type        = string
  description = "Optional Kubernetes version for the EKS cluster."
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
  description = "Allowed CIDRs for public EKS endpoint access."
  default     = ["0.0.0.0/0"]
}

variable "node_instance_types" {
  type        = list(string)
  description = "EC2 instance types for the managed node group."
  default     = ["t3.2xlarge"]
}

variable "node_min_size" {
  type        = number
  description = "Minimum node group size."
  default     = 1
}

variable "node_max_size" {
  type        = number
  description = "Maximum node group size."
  default     = 3
}

variable "node_desired_size" {
  type        = number
  description = "Desired node group size."
  default     = 2
}

variable "node_disk_size" {
  type        = number
  description = "Node root volume size in GiB."
  default     = 20
}

variable "node_capacity_type" {
  type        = string
  description = "Node group capacity type (ON_DEMAND or SPOT)."
  default     = "ON_DEMAND"
}

variable "enable_irsa" {
  type        = bool
  description = "Enable IAM Roles for Service Accounts (IRSA)."
  default     = true
}

variable "oidc_thumbprint" {
  type        = string
  description = "OIDC root CA thumbprint for the EKS OIDC provider."
  default     = "9e99a48a9960b14926bb7f3b02e22da0c0f8f9a1"
}

locals {
  name_prefix  = "${var.project_name}-${var.environment}"
  cluster_name = var.eks_cluster_name != null && var.eks_cluster_name != "" ? var.eks_cluster_name : "${local.name_prefix}-eks"

  common_tags = merge({
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }, var.tags)
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

module "vpc" {
  source = "./modules/vpc"

  name                = local.name_prefix
  cidr                = var.vpc_cidr
  az_count            = var.az_count
  subnet_bits         = var.subnet_bits
  nat_gateway_count   = var.nat_gateway_count
  region              = var.aws_region
  enable_sts_endpoint = var.enable_sts_endpoint
  tags                = local.common_tags
}

module "ecr" {
  source = "./modules/ecr"

  repositories        = var.ecr_repositories
  scan_on_push        = var.ecr_scan_on_push
  lifecycle_keep_last = var.ecr_lifecycle_keep_last
  tags                = local.common_tags
}

module "eks" {
  source = "./modules/eks"

  cluster_name            = local.cluster_name
  kubernetes_version      = var.kubernetes_version
  subnet_ids              = module.vpc.private_subnet_ids
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
  tags                    = local.common_tags
}
