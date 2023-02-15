locals {
  snowflake_ingest_artifact_key = format("tilotech/tilores-core/%s/integration-snowflake-ingest.zip", var.core_version)
  snowflake_query_artifact_key  = format("tilotech/tilores-core/%s/integration-snowflake-query.zip", var.core_version)
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