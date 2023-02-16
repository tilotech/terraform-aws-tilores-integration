output "api_url" {
  value       = var.snowflake ? aws_api_gateway_stage.default.invoke_url : ""
  description = "The integration API URL"
}

output "snowflake_api_access_role_arn" {
  value       = var.snowflake ? ( local.use_snowflake_internal_role ? aws_iam_role.snowflake_api_access[0].arn : aws_iam_role.snowflake_api_access_external[0].arn ) : ""
  description = "The Snowflake integration assumable role ARN granting API access"
}