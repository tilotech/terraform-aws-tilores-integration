variable "resource_prefix" {
  type        = string
  description = "The text every created resource will be prefixed with."
}

variable "core_config_layer_arn" {
  type        = string
  description = "The configuration lambda layer ARN."
}

variable "core_environment_variables" {
  type        = map(string)
  description = "The core lambda environment variables"
}

variable "core_policy_arn" {
  type        = string
  description = "The policy ARN granting access to core resources"
}

variable "core_version" {
  type        = string
  description = "The version of tilores core, e.g. v0-1-0 , v0 or latest"
  default     = "v0"
}

variable "snowflake" {
  type        = bool
  description = "Defines whether to create snowflake integration resources"
  default     = false
}

variable "snowflake_iam_user_arn" {
  type        = string
  description = "The IAM user ARN provided by snowflake (API_AWS_IAM_USER_ARN from snowflakes describe integration)"
  default     = ""
}

variable "snowflake_external_id" {
  type        = string
  description = "The external ID provided by snowflake (API_AWS_EXTERNAL_ID from snowflakes describe integration)"
  default     = ""
}

locals {
  prefix           = format("%s-tilores", var.resource_prefix)
  artifacts_bucket = format("tilotech-artifacts-%s", data.aws_region.current.id)
}
