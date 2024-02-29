locals {
  webhook_entity_stream_use_sqs     = var.webhook && var.webhook_entity_stream_parallelization_sqs != 0
  webhook_entity_stream_use_kinesis = var.webhook && var.webhook_entity_stream_parallelization_sqs == 0

  all_entity_stream_event_source_mapping = {
    sqs = local.webhook_entity_stream_use_sqs ? {
      event_source_arn = var.webhook_entity_stream_arn
      batch_size       = 10
      scaling_config = {
        maximum_concurrency = var.webhook_entity_stream_parallelization_sqs
      }
      function_response_types = ["ReportBatchItemFailures"]
    } : null
    kinesis = local.webhook_entity_stream_use_kinesis ? {
      event_source_arn        = var.webhook_entity_stream_arn
      starting_position       = "TRIM_HORIZON"
      batch_size              = 10
      parallelization_factor  = 10
      function_response_types = ["ReportBatchItemFailures"]
    } : null
  }
  entity_stream_event_source_mapping = {
    for source, config in local.all_entity_stream_event_source_mapping :
    source => config if config != null
  }
}

module "lambda_webhook_entity_stream" {
  count   = var.webhook ? 1 : 0
  source  = "terraform-aws-modules/lambda/aws"
  version = "7.2.1"

  function_name = format("%s-webhook-entity-stream", local.prefix)
  handler       = "entitystream"
  runtime       = "provided.al2"
  timeout       = 60
  memory_size   = 1024
  architectures = ["arm64"]

  create_package = false

  s3_existing_package = {
    bucket     = data.aws_s3_object.webhook_entity_stream_artifact[0].bucket
    key        = data.aws_s3_object.webhook_entity_stream_artifact[0].key
    version_id = data.aws_s3_object.webhook_entity_stream_artifact[0].version_id
  }

  environment_variables = {
    WEBHOOK_URL = var.webhook_entity_stream_url
  }

  attach_policies = true
  policies = [
    aws_iam_policy.lambda_webhook_entity_stream[0].arn
  ]
  number_of_policies = 1

  event_source_mapping = local.entity_stream_event_source_mapping

  create_current_version_allowed_triggers = false
}

resource "aws_iam_policy" "lambda_webhook_entity_stream" {
  count  = var.webhook ? 1 : 0
  name   = format("%s-%s-%s", local.prefix, "lambda", "webhook-entity-stream")
  policy = data.aws_iam_policy_document.lambda_webhook_entity_stream.json
}

data "aws_iam_policy_document" "lambda_webhook_entity_stream" {
  statement {
    effect = "Allow"
    actions = [
      "kinesis:GetShardIterator",
      "kinesis:DescribeStream",
      "kinesis:GetRecords",
      "kinesis:PutRecords",
      "sqs:SendMessage",
      "sqs:GetQueueUrl",
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes"
    ]
    resources = [var.webhook_entity_stream_arn]
  }
  statement {
    effect = "Allow"
    actions = [
      "kinesis:ListStreams"
    ]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:${data.aws_region.current.id}:*:log-group:/aws/lambda/${local.prefix}-*"]
  }
}
