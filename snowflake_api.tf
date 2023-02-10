resource "aws_api_gateway_resource" "snowflake" {
  count = var.snowflake ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.integration.id
  parent_id   = aws_api_gateway_rest_api.integration.root_resource_id
  path_part   = "snowflake"
}

resource "aws_api_gateway_resource" "snowflake_ingest" {
  count = var.snowflake ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.integration.id
  parent_id   = aws_api_gateway_resource.snowflake[0].id
  path_part   = "ingest"
}

resource "aws_api_gateway_method" "snowflake_ingest_post" {
  count = var.snowflake ? 1 : 0

  authorization = "AWS_IAM"
  http_method   = "POST"
  resource_id   = aws_api_gateway_resource.snowflake_ingest[0].id
  rest_api_id   = aws_api_gateway_rest_api.integration.id
}

resource "aws_api_gateway_method_response" "snowflake_ingest_post" {
  count = var.snowflake ? 1 : 0

  http_method     = "POST"
  resource_id     = aws_api_gateway_resource.snowflake_ingest[0].id
  rest_api_id     = aws_api_gateway_rest_api.integration.id
  status_code     = "200"
  response_models = {
    "application/json" : "Empty"
  }

  depends_on = [
    aws_api_gateway_method.snowflake_ingest_post
  ]
}

resource "aws_api_gateway_integration" "snowflake_ingest" {
  count = var.snowflake ? 1 : 0

  http_method             = aws_api_gateway_method.snowflake_ingest_post[0].http_method
  resource_id             = aws_api_gateway_resource.snowflake_ingest[0].id
  rest_api_id             = aws_api_gateway_rest_api.integration.id
  type                    = "AWS"
  integration_http_method = "POST"
  uri                     = module.lambda_snowflake_ingest[0].lambda_function_invoke_arn

  request_templates = {
    "application/json" = <<EOF
{
  "parameters" : $input.json('$'),
  "action" : "$context.resourcePath"
}
EOF
  }
}

// TODO: add response mapping
resource "aws_api_gateway_integration_response" "snowflake_ingest" {
  count = var.snowflake ? 1 : 0

  http_method = aws_api_gateway_method.snowflake_ingest_post[0].http_method
  resource_id = aws_api_gateway_resource.snowflake_ingest[0].id
  rest_api_id = aws_api_gateway_rest_api.integration.id
  status_code = "200"

  depends_on = [
    aws_api_gateway_integration.snowflake_ingest[0],
    aws_api_gateway_method_response.snowflake_ingest_post[0],
  ]
}