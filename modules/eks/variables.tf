variable "cluster_name" {
  type        = string
  description = "EKS cluster name."
}

variable "kubernetes_version" {
  type        = string
  description = "Optional Kubernetes version."
  default     = null
}

variable "subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for the EKS cluster and node group."
}

variable "endpoint_private_access" {
  type        = bool
  description = "Enable private endpoint access."
  default     = true
}

variable "endpoint_public_access" {
  type        = bool
  description = "Enable public endpoint access."
  default     = false

  validation {
    condition     = var.endpoint_private_access || var.endpoint_public_access
    error_message = "At least one of endpoint_private_access or endpoint_public_access must be true."
  }
}

variable "public_access_cidrs" {
  type        = list(string)
  description = "Allowed CIDRs for public endpoint access."
  default     = ["0.0.0.0/0"]
}

variable "node_instance_types" {
  type        = list(string)
  description = "Instance types for managed node group."
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

  validation {
    condition     = var.node_min_size <= var.node_desired_size && var.node_desired_size <= var.node_max_size
    error_message = "node_min_size <= node_desired_size <= node_max_size must be satisfied."
  }
}

variable "node_disk_size" {
  type        = number
  description = "Root volume size for nodes (GiB)."
  default     = 20
}

variable "node_capacity_type" {
  type        = string
  description = "Capacity type for nodes (ON_DEMAND or SPOT)."
  default     = "ON_DEMAND"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.node_capacity_type)
    error_message = "node_capacity_type must be ON_DEMAND or SPOT."
  }
}

variable "enable_irsa" {
  type        = bool
  description = "Enable IAM Roles for Service Accounts (IRSA)."
  default     = true
}

variable "oidc_thumbprint" {
  type        = string
  description = "OIDC provider CA thumbprint."
  default     = "9e99a48a9960b14926bb7f3b02e22da0c0f8f9a1"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to EKS resources."
  default     = {}
}
