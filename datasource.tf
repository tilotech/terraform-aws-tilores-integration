locals {
  snowflake_ingest_artifact_key      = format("tilotech/tilores-core/%s/integration-snowflake-ingest.zip", var.core_version)
  snowflake_query_artifact_key       = format("tilotech/tilores-core/%s/integration-snowflake-query.zip", var.core_version)
  webhook_entity_stream_artifact_key = format("tilotech/tilores-core/%s/integration-webhook-entity-stream.zip", var.core_version)
  scavenger_artifact_key             = format("tilotech/func-scavenger/%s/scavenger.zip", var.scavenger_version)
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_s3_object" "snowflake_ingest_artifact" {
  count = var.snowflake ? 1 : 0

  bucket = local.artifacts_bucket
  key    = local.snowflake_ingest_artifact_key
}

data "aws_s3_object" "snowflake_query_artifact" {
  count = var.snowflake ? 1 : 0

  bucket = local.artifacts_bucket
  key    = local.snowflake_query_artifact_key
}

data "aws_s3_object" "scavenger_artifact" {
  bucket = local.artifacts_bucket
  key    = local.scavenger_artifact_key
}

data "aws_s3_object" "webhook_entity_stream_artifact" {
  count = var.webhook ? 1 : 0

  bucket = local.artifacts_bucket
  key    = local.webhook_entity_stream_artifact_key
}