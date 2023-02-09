resource "aws_api_gateway_rest_api" "integration" {
  name = format("%s-integration", local.prefix)
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_deployment" "default" {
  rest_api_id = aws_api_gateway_rest_api.integration.id

  triggers = {
    // TODO: Add any file that might affect the API
    main      = filesha1("${path.module}/main.tf"),
    snowflake = filesha1("${path.module}/snowflake_api.tf")
  }

  lifecycle {
    create_before_destroy = true
  }
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
    ] : statement if statement!=null
  ]
}

resource "aws_api_gateway_rest_api_policy" "default" {
  count       = length(local.api_policy_statements) == 0 ? 0 : 1
  rest_api_id = aws_api_gateway_rest_api.integration.id

  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = local.api_policy_statements
  })
}
