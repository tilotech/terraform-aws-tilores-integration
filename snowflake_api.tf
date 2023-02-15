locals {
  snowflake_api_policy_statement = !var.snowflake ? null : {
    Effect    = "Allow"
    Principal = {
      AWS = "arn:aws:sts::${data.aws_caller_identity.current.account_id}:assumed-role/${local.use_snowflake_internal_role ? aws_iam_role.snowflake_api_access[0].name : aws_iam_role.snowflake_api_access_external[0].name}/snowflake"
    },
    Action   = "execute-api:Invoke",
    Resource = format("%s/default/POST%s/*",
      aws_api_gateway_rest_api.integration.execution_arn,
      aws_api_gateway_resource.snowflake[0].path
    )
  }

  snowflake_sub_paths = !var.snowflake ? {} : {
    ingest : module.lambda_snowflake_ingest[0].lambda_function_invoke_arn
    entity-by-id : module.lambda_snowflake_query[0].lambda_function_invoke_arn
    entity-by-record-id : module.lambda_snowflake_query[0].lambda_function_invoke_arn
    entity-id-by-record-id : module.lambda_snowflake_query[0].lambda_function_invoke_arn
    match : module.lambda_snowflake_query[0].lambda_function_invoke_arn
  }
}

resource "aws_api_gateway_resource" "snowflake" {
  count = var.snowflake ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.integration.id
  parent_id   = aws_api_gateway_rest_api.integration.root_resource_id
  path_part   = "snowflake"
}

resource "aws_api_gateway_resource" "snowflake_sub_path" {
  for_each = local.snowflake_sub_paths

  rest_api_id = aws_api_gateway_rest_api.integration.id
  parent_id   = aws_api_gateway_resource.snowflake[0].id
  path_part   = each.key
}

resource "aws_api_gateway_method" "snowflake_sub_path_post" {
  for_each = local.snowflake_sub_paths

  authorization = "AWS_IAM"
  http_method   = "POST"
  resource_id   = aws_api_gateway_resource.snowflake_sub_path[each.key].id
  rest_api_id   = aws_api_gateway_rest_api.integration.id
}

resource "aws_api_gateway_method_response" "snowflake_sub_path_post" {
  for_each = local.snowflake_sub_paths

  http_method     = "POST"
  resource_id     = aws_api_gateway_resource.snowflake_sub_path[each.key].id
  rest_api_id     = aws_api_gateway_rest_api.integration.id
  status_code     = "200"
  response_models = {
    "application/json" : "Empty"
  }

  depends_on = [
    aws_api_gateway_method.snowflake_sub_path_post
  ]
}

resource "aws_api_gateway_integration" "snowflake_sub_path" {
  for_each = local.snowflake_sub_paths

  http_method             = aws_api_gateway_method.snowflake_sub_path_post[each.key].http_method
  resource_id             = aws_api_gateway_resource.snowflake_sub_path[each.key].id
  rest_api_id             = aws_api_gateway_rest_api.integration.id
  type                    = "AWS"
  integration_http_method = "POST"
  uri                     = each.value

  request_templates = {
    "application/json" = <<EOF
{
  "parameters" : $input.json('$'),
  "action" : "$context.resourcePath"
}
EOF
  }
}

resource "aws_api_gateway_integration_response" "snowflake_sub_path" {
  for_each = local.snowflake_sub_paths

  http_method = aws_api_gateway_method.snowflake_sub_path_post[each.key].http_method
  resource_id = aws_api_gateway_resource.snowflake_sub_path[each.key].id
  rest_api_id = aws_api_gateway_rest_api.integration.id
  status_code = "200"

  depends_on = [
    aws_api_gateway_integration.snowflake_sub_path,
    aws_api_gateway_method_response.snowflake_sub_path_post,
  ]
}

resource "aws_api_gateway_method_response" "snowflake_sub_path_post_500" {
  for_each = local.snowflake_sub_paths

  http_method     = "POST"
  resource_id     = aws_api_gateway_resource.snowflake_sub_path[each.key].id
  rest_api_id     = aws_api_gateway_rest_api.integration.id
  status_code     = "500"
  response_models = {
    "application/json" : "Error"
  }

  depends_on = [
    aws_api_gateway_method.snowflake_sub_path_post
  ]
}

resource "aws_api_gateway_integration_response" "snowflake_sub_path_500" {
  for_each = local.snowflake_sub_paths

  http_method       = aws_api_gateway_method.snowflake_sub_path_post[each.key].http_method
  resource_id       = aws_api_gateway_resource.snowflake_sub_path[each.key].id
  rest_api_id       = aws_api_gateway_rest_api.integration.id
  selection_pattern = "internal error"
  status_code       = "500"

  depends_on = [
    aws_api_gateway_integration.snowflake_sub_path,
    aws_api_gateway_method_response.snowflake_sub_path_post_500,
  ]
}

resource "aws_api_gateway_method_response" "snowflake_sub_path_post_422" {
  for_each = local.snowflake_sub_paths

  http_method     = "POST"
  resource_id     = aws_api_gateway_resource.snowflake_sub_path[each.key].id
  rest_api_id     = aws_api_gateway_rest_api.integration.id
  status_code     = "422"
  response_models = {
    "application/json" : "Error"
  }

  depends_on = [
    aws_api_gateway_method.snowflake_sub_path_post
  ]
}

resource "aws_api_gateway_integration_response" "snowflake_sub_path_422" {
  for_each = local.snowflake_sub_paths

  http_method       = aws_api_gateway_method.snowflake_sub_path_post[each.key].http_method
  resource_id       = aws_api_gateway_resource.snowflake_sub_path[each.key].id
  rest_api_id       = aws_api_gateway_rest_api.integration.id
  selection_pattern = "^(?!internal error$).+$"
  status_code       = "422"

  depends_on = [
    aws_api_gateway_integration.snowflake_sub_path,
    aws_api_gateway_method_response.snowflake_sub_path_post_422,
  ]
}