variable "repositories" {
  type        = list(string)
  description = "List of ECR repositories to create."
}

variable "scan_on_push" {
  type        = bool
  description = "Enable scan on push."
  default     = true
}

variable "lifecycle_keep_last" {
  type        = number
  description = "Number of images to keep per repository."
  default     = 30
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to repositories."
  default     = {}
}
