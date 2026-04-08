variable "project" {
  description = "Project name used for resource naming"
  type        = string
  default     = "myapp"
}

variable "github_org" {
  description = "GitHub organization or user that owns the repository"
  type        = string
  default     = "<GITHUB_ORG>"
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "<GITHUB_REPO>"
}

variable "environments" {
  description = "Map of environment names to their configuration"
  type = map(object({
    sub_filter = string
  }))
  default = {
    dev = {
      sub_filter = "ref:refs/heads/main"
    }
    staging = {
      sub_filter = "ref:refs/tags/rc-*"
    }
    prod = {
      sub_filter = "ref:refs/tags/v*"
    }
  }
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    Project   = "myapp"
    ManagedBy = "terraform"
  }
}
