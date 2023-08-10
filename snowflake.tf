locals {
  use_snowflake_internal_role = var.snowflake_iam_user_arn != "" && var.snowflake_external_id != ""
}

resource "aws_iam_role" "snowflake_api_access" {
  count              = var.snowflake && local.use_snowflake_internal_role ? 1 : 0
  name               = format("%s-snowflake-api-access", local.prefix)
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          AWS = var.snowflake_iam_user_arn
        }
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.snowflake_external_id
          }
        }
      },
    ]
  })
}

// Root user is always disabled, and cannot have a principal arn "never"
resource "aws_iam_role" "snowflake_api_access_external" {
  count              = !var.snowflake ? 0 : (local.use_snowflake_internal_role ? 0 : 1)
  name               = format("%s-snowflake-api-access-external", local.prefix)
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Condition = {
          StringEquals = {
            "aws:PrincipalArn" = "never"
          }
        }
      },
    ]
  })

  lifecycle {
    ignore_changes = [assume_role_policy]
  }
}

module "lambda_snowflake_ingest" {
  count   = var.snowflake ? 1 : 0
  source  = "terraform-aws-modules/lambda/aws"
  version = "= 4.11"

  function_name = format("%s-snowflake-ingest", local.prefix)
  handler       = "ingest"
  runtime       = "provided.al2"
  timeout       = 900
  memory_size   = 1024
  architectures = ["arm64"]

  create_package = false

  reserved_concurrent_executions = var.snowflake_ingest_concurrency

  s3_existing_package = {
    bucket     = data.aws_s3_object.snowflake_ingest_artifact[0].bucket
    key        = data.aws_s3_object.snowflake_ingest_artifact[0].key
    version_id = data.aws_s3_object.snowflake_ingest_artifact[0].version_id
  }

  layers = [
    var.core_config_layer_arn,
  ]

  environment_variables = var.core_environment_variables

  attach_policies = true
  policies        = [
    var.core_policy_arn
  ]
  number_of_policies = 1

  allowed_triggers = {
    APIGateway = {
      service    = "apigateway"
      source_arn = format("%s/%s/POST%s/*",
        aws_api_gateway_rest_api.integration.execution_arn,
        aws_api_gateway_stage.default.stage_name,
        aws_api_gateway_resource.snowflake[0].path
      )
    }
  }
  create_current_version_allowed_triggers = false
}

module "lambda_snowflake_query" {
  count   = var.snowflake ? 1 : 0
  source  = "terraform-aws-modules/lambda/aws"
  version = "= 4.11"

  function_name = format("%s-snowflake-query", local.prefix)
  handler       = "query"
  runtime       = "provided.al2"
  timeout       = 30
  memory_size   = 1024
  architectures = ["arm64"]

  create_package = false

  s3_existing_package = {
    bucket     = data.aws_s3_object.snowflake_query_artifact[0].bucket
    key        = data.aws_s3_object.snowflake_query_artifact[0].key
    version_id = data.aws_s3_object.snowflake_query_artifact[0].version_id
  }

  layers = [
    var.core_config_layer_arn,
  ]

  environment_variables = var.core_environment_variables

  attach_policies = true
  policies        = [
    var.core_policy_arn
  ]
  number_of_policies = 1

  allowed_triggers = {
    APIGateway = {
      service    = "apigateway"
      source_arn = format("%s/%s/POST%s/*",
        aws_api_gateway_rest_api.integration.execution_arn,
        aws_api_gateway_stage.default.stage_name,
        aws_api_gateway_resource.snowflake[0].path
      )
    }
  }
  create_current_version_allowed_triggers = false
}
