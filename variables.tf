variable "resource_prefix" {
  type        = string
  description = "The text every created resource will be prefixed with."
}

variable "core_config_layer_arn" {
  type        = string
  description = "The configuration lambda layer ARN."
}

variable "core_entity_bucket_arn" {
  type        = string
  description = "The ARN of the bucket holding the entities in core"
}

variable "core_execution_plan_bucket_arn" {
  type        = string
  description = "The ARN of the bucket holding the execution plans in core"
}

variable "core_scavenger_dead_letter_queue_arn" {
  type        = string
  description = "The ARN of the scavenger dead letter queue in core"
}

variable "core_scavenger_dead_letter_queue_id" {
  type        = string
  description = "The ID of the scavenger dead letter queue in core"
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

variable "scavenger_version" {
  description = "The version of scavenger, e.g. v0-1-0 , v0 or latest"
  type        = string
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

variable "snowflake_ingest_concurrency" {
  type = number
  description = "Defines the maximum concurrent ingestion, -1 for unlimited"
  default = -1
}

locals {
  prefix           = format("%s-tilores", var.resource_prefix)
  artifacts_bucket = format("tilotech-artifacts-%s", data.aws_region.current.id)
}
