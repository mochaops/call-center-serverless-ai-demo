resource "aws_lambda_function" "ingest" {
  function_name = "${var.project}-ingest"
  role          = aws_iam_role.lambda_ingest.arn
  handler       = "handler_ingest.lambda_handler"
  runtime       = "python3.12"
  filename      = data.archive_file.ingest_zip.output_path
  source_code_hash = data.archive_file.ingest_zip.output_base64sha256
  timeout       = 60
  environment {
    variables = {
      RECORDINGS_BUCKET   = local.recordings_bucket_name
      OUTPUTS_BUCKET      = local.outputs_bucket_name
      REGION              = var.region
      TRANSCRIBE_LANGCODE = var.transcribe_language_code
    }
  }
}

resource "aws_lambda_function" "post" {
  function_name = "${var.project}-post"
  role          = aws_iam_role.lambda_post.arn
  handler       = "handler_post.lambda_handler"
  runtime       = "python3.12"
  filename      = data.archive_file.post_zip.output_path
  source_code_hash = data.archive_file.post_zip.output_base64sha256
  timeout       = 180
  environment {
    variables = {
      OUTPUTS_BUCKET  = local.outputs_bucket_name
      BEDROCK_MODELID = var.bedrock_model_id
      REGION          = var.region
      POLLY_VOICE_ID  = var.polly_voice_id
    }
  }
}

# Empaquetado del código
data "archive_file" "ingest_zip" {
  type        = "zip"
  source_file = "${path.module}/lambdas/handler_ingest.py"
  output_path = "${path.module}/build/ingest.zip"
}

data "archive_file" "post_zip" {
  type        = "zip"
  source_file = "${path.module}/lambdas/handler_post.py"
  output_path = "${path.module}/build/post.zip"
}
