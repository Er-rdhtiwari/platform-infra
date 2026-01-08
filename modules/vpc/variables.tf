variable "name" {
  type        = string
  description = "Name prefix for VPC resources."
}

variable "cidr" {
  type        = string
  description = "VPC CIDR block."
}

variable "az_count" {
  type        = number
  description = "Number of availability zones (2 or 3)."
  default     = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3."
  }
}

variable "subnet_bits" {
  type        = number
  description = "Additional subnet bits used to carve subnets."
  default     = 4
}

variable "nat_gateway_count" {
  type        = number
  description = "Number of NAT gateways to deploy."
  default     = 1

  validation {
    condition     = var.nat_gateway_count >= 1 && var.nat_gateway_count <= var.az_count
    error_message = "nat_gateway_count must be between 1 and az_count."
  }
}

variable "region" {
  type        = string
  description = "AWS region for VPC endpoints."
}

variable "enable_sts_endpoint" {
  type        = bool
  description = "Enable the STS interface endpoint."
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources."
  default     = {}
}
