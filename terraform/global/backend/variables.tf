variable "project" {
  description = "Project name used for resource naming"
  type        = string
  default     = "myapp"
}

variable "region" {
  description = "AWS region for the state bucket and lock table"
  type        = string
  default     = "ap-southeast-1"
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    Project   = "myapp"
    ManagedBy = "terraform"
  }
}
