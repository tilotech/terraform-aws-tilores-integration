# Plans the module as Tilores SaaS uses it (Snowflake, and the webhook on an SQS
# entity stream), with the AWS and time providers mocked, so the test needs no
# AWS access. Run with `terraform init && terraform test` (Terraform 1.11 or
# newer, for override_during).

mock_provider "aws" {
  # The provider checks policy JSON even when it is mocked.
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}
mock_provider "time" {}

variables {
  resource_prefix                      = "test"
  core_config_layer_arn                = "arn:aws:lambda:eu-central-1:123456789012:layer:test-tilores-rule-config:1"
  core_entity_bucket_arn               = "arn:aws:s3:::test-tilores-entity"
  core_execution_plan_bucket_arn       = "arn:aws:s3:::test-tilores-execution-plan"
  core_scavenger_dead_letter_queue_arn = "arn:aws:sqs:eu-central-1:123456789012:test-tilores-scavenger-dead-letter-queue"
  core_scavenger_dead_letter_queue_id  = "https://sqs.eu-central-1.amazonaws.com/123456789012/test-tilores-scavenger-dead-letter-queue"
  core_environment_variables           = { RULE_CONFIG = "/opt/rule-config.json" }
  core_policy_arn                      = "arn:aws:iam::123456789012:policy/test-tilores-lambda-core"

  snowflake = true

  webhook                   = true
  webhook_entity_stream_arn = "arn:aws:sqs:eu-central-1:123456789012:test-tilores-entity-stream"
  webhook_entity_stream_url = "https://example.com/webhook"
}

run "integration_plans" {
  command = plan

  # Values that AWS only knows after an apply, set during the plan so that the
  # API policy and the routes can be checked.
  override_data {
    target = data.aws_caller_identity.current
    values = {
      account_id = "123456789012"
    }
  }
  override_data {
    target = data.aws_region.current
    values = {
      region = "eu-central-1"
    }
  }
  override_resource {
    target          = aws_api_gateway_rest_api.integration
    override_during = plan
    values = {
      id               = "api123"
      root_resource_id = "root123"
      execution_arn    = "arn:aws:execute-api:eu-central-1:123456789012:api123"
    }
  }
  override_resource {
    target          = aws_api_gateway_resource.snowflake
    override_during = plan
    values = {
      id   = "snowflake123"
      path = "/snowflake"
    }
  }
  override_resource {
    target          = module.lambda_snowflake_ingest[0].aws_lambda_function.this[0]
    override_during = plan
    values = {
      invoke_arn = "arn:aws:apigateway:eu-central-1:lambda:path/2015-03-31/functions/arn:aws:lambda:eu-central-1:123456789012:function:test-tilores-snowflake-ingest/invocations"
    }
  }
  override_resource {
    target          = module.lambda_snowflake_query[0].aws_lambda_function.this[0]
    override_during = plan
    values = {
      invoke_arn = "arn:aws:apigateway:eu-central-1:lambda:path/2015-03-31/functions/arn:aws:lambda:eu-central-1:123456789012:function:test-tilores-snowflake-query/invocations"
    }
  }

  assert {
    condition = (
      length(aws_api_gateway_method.snowflake_sub_path_post) == 6
      && alltrue([for m in aws_api_gateway_method.snowflake_sub_path_post : m.authorization == "AWS_IAM"])
    )
    error_message = "Every method of the Snowflake API must require IAM authorization."
  }

  assert {
    condition = (
      endswith(aws_api_gateway_integration.snowflake_sub_path["ingest"].uri, ":function:test-tilores-snowflake-ingest/invocations")
      && alltrue([
        for path, integration in aws_api_gateway_integration.snowflake_sub_path :
        endswith(integration.uri, ":function:test-tilores-snowflake-query/invocations") if path != "ingest"
      ])
    )
    error_message = "The ingest path must call the ingest function, and every other Snowflake path the query function."
  }

  assert {
    condition = jsondecode(aws_api_gateway_rest_api_policy.default[0].policy).Statement == [
      {
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:sts::123456789012:assumed-role/test-tilores-snowflake-api-access-external/snowflake" }
        Action    = "execute-api:Invoke"
        Resource  = "arn:aws:execute-api:eu-central-1:123456789012:api123/default/POST/snowflake/*"
      }
    ]
    error_message = "The API policy may only let the Snowflake session of the instance's role call POST on the Snowflake paths of the default stage."
  }

  assert {
    condition = alltrue([
      for s in data.aws_iam_policy_document.lambda_webhook_entity_stream.statement :
      s.resources == toset(["arn:aws:sqs:eu-central-1:123456789012:test-tilores-entity-stream"])
      if anytrue([for a in s.actions : startswith(a, "sqs:")])
    ])
    error_message = "The webhook function may only use the entity stream it reads from."
  }
}
