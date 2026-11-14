variable "database_password" {
  type        = string
  description = "Synthetic fixture only"
  default     = "synthetic_terraform_db_password_001"
}

variable "api_key" {
  type        = string
  description = "Synthetic fixture only"
  default     = "synthetic_terraform_api_key_001"
}

variable "registry_password" {
  type        = string
  description = "Synthetic fixture only"
  default     = "synthetic_terraform_registry_password_001"
}

variable "deployment_token" {
  type        = string
  description = "Synthetic fixture only"
  default     = "synthetic_deployment_token_001"
}

variable "infrastructure_api_secret" {
  type        = string
  description = "Synthetic fixture only"
  default     = "synthetic_infrastructure_secret_001"
}

variable "aws_access_key_id" {
  type    = string
  default = "AKIAFIXTURE000000006"
}
