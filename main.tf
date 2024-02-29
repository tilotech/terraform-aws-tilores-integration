resource "aws_api_gateway_rest_api" "integration" {
  name = format("%s-integration", local.prefix)
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_deployment" "default" {
  rest_api_id = aws_api_gateway_rest_api.integration.id

  triggers = {
    resourceChange = sha1(jsonencode([
      var.snowflake_iam_user_arn,
      var.snowflake_external_id
    ]))
    mainFileChange      = filesha1("${path.module}/main.tf")
    snowflakeFileChange = filesha1("${path.module}/snowflake_api.tf")
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    // TODO: add all resources of the same type
    aws_api_gateway_rest_api_policy.default,
    aws_api_gateway_integration_response.snowflake_sub_path,
    aws_api_gateway_integration_response.snowflake_sub_path_422,
    aws_api_gateway_integration_response.snowflake_sub_path_500,
  ]
}

resource "aws_api_gateway_stage" "default" {
  deployment_id      = aws_api_gateway_deployment.default.id
  rest_api_id        = aws_api_gateway_rest_api.integration.id
  stage_name         = "default"
  cache_cluster_size = "0.5" // This is added only for it not to show in the plan
}

locals {
  api_policy_statements = [
    for statement in [
      local.snowflake_api_policy_statement
    ] : statement if statement != null
  ]
}

resource "aws_api_gateway_rest_api_policy" "default" {
  count       = length(local.api_policy_statements) == 0 ? 0 : 1
  rest_api_id = aws_api_gateway_rest_api.integration.id

  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = local.api_policy_statements
  })

  depends_on = [
    time_sleep.wait_for_role
  ]
}

resource "time_sleep" "wait_for_role" {
  triggers = {
    roleChange = sha1(jsonencode(local.api_policy_statements))
  }
  create_duration = "10s"

  depends_on = [
    aws_iam_role.snowflake_api_access[0],
    aws_iam_role.snowflake_api_access_external[0]
  ]
}

// TODO: Add any new mutation lambdas as a condition in count
module "lambda_scavenger" {
  count   = var.snowflake ? 1 : 0
  source  = "terraform-aws-modules/lambda/aws"
  version = "7.2.1"

  function_name = format("%s-integration-scavenger", local.prefix)
  handler       = "scavenger"
  runtime       = "provided.al2"
  timeout       = 900
  memory_size   = 1024
  architectures = ["arm64"]

  create_package = false

  s3_existing_package = {
    bucket     = data.aws_s3_object.scavenger_artifact.bucket
    key        = data.aws_s3_object.scavenger_artifact.key
    version_id = data.aws_s3_object.scavenger_artifact.version_id
  }

  environment_variables = {
    DEAD_LETTER_QUEUE_URL = var.core_scavenger_dead_letter_queue_id
  }

  allowed_triggers = {
    snowflake_ingest = {
      principal  = format("logs.%s.amazonaws.com", data.aws_region.current.id)
      source_arn = format("%s:*", module.lambda_snowflake_ingest[0].lambda_cloudwatch_log_group_arn)
    }
  }

  create_current_version_allowed_triggers = false

  attach_policy_statements = true
  policy_statements = {
    s3 = {
      effect = "Allow"
      actions = [
        "s3:DeleteObject"
      ]
      resources = [
        format("%s/*", var.core_entity_bucket_arn),
        format("%s/*", var.core_execution_plan_bucket_arn)
      ]
    },
    sqs = {
      effect    = "Allow"
      actions   = ["sqs:SendMessage"]
      resources = [var.core_scavenger_dead_letter_queue_arn]
    }
    cloudwatch = {
      effect = "Allow"
      actions = [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      resources = [
        "arn:aws:logs:${data.aws_region.current.id}:*:log-group:/aws/lambda/${local.prefix}-integration-scavenger"
      ]
    }
  }
}

resource "aws_cloudwatch_log_subscription_filter" "scavenger_snowflake_ingest" {
  count           = var.snowflake ? 1 : 0
  destination_arn = module.lambda_scavenger[0].lambda_function_arn
  filter_pattern  = "\"REMOVE-GARBAGE\""
  log_group_name  = module.lambda_snowflake_ingest[0].lambda_cloudwatch_log_group_name
  name            = format("%s-%s", local.prefix, "scavenger-snowflake-ingest")
}
