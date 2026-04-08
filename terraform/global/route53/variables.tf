variable "domain_name" {
  description = "Domain name for the public hosted zone"
  type        = string
  default     = "<DOMAIN>"
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    Project   = "myapp"
    ManagedBy = "terraform"
  }
}
