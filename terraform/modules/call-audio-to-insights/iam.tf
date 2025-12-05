resource "aws_iam_role" "lambda_ingest" {
  name               = "${var.project}-lambda-ingest"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role" "lambda_post" {
  name               = "${var.project}-lambda-post"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

data "aws_iam_policy_document" "common" {
  statement {
    actions   = ["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"]
    resources = ["*"]
  }
  statement {
    actions   = ["kms:Decrypt","kms:Encrypt","kms:GenerateDataKey","kms:DescribeKey"]
    resources = [aws_kms_key.s3.arn]
  }
  statement {
    actions   = ["s3:GetObject","s3:PutObject","s3:ListBucket"]
    resources = [
      "arn:aws:s3:::${local.recordings_bucket_name}",
      "arn:aws:s3:::${local.recordings_bucket_name}/*",
      "arn:aws:s3:::${local.outputs_bucket_name}",
      "arn:aws:s3:::${local.outputs_bucket_name}/*"
    ]
  }
}

resource "aws_iam_policy" "common" {
  name   = "${var.project}-lambda-common"
  policy = data.aws_iam_policy_document.common.json
}

resource "aws_iam_role_policy_attachment" "ingest_common" {
  role       = aws_iam_role.lambda_ingest.name
  policy_arn = aws_iam_policy.common.arn
}
resource "aws_iam_role_policy_attachment" "post_common" {
  role       = aws_iam_role.lambda_post.name
  policy_arn = aws_iam_policy.common.arn
}

# Ingest: Transcribe
data "aws_iam_policy_document" "ingest_extra" {
  statement {
    actions   = ["transcribe:StartTranscriptionJob","transcribe:GetTranscriptionJob","transcribe:ListTranscriptionJobs"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "ingest_extra" {
  name   = "${var.project}-ingest-extra"
  policy = data.aws_iam_policy_document.ingest_extra.json
}

resource "aws_iam_role_policy_attachment" "ingest_extra" {
  role       = aws_iam_role.lambda_ingest.name
  policy_arn = aws_iam_policy.ingest_extra.arn
}

# Post: Comprehend, Bedrock, Polly
data "aws_iam_policy_document" "post_extra" {
  statement {
    actions   = ["comprehend:DetectSentiment","comprehend:DetectEntities","comprehend:DetectKeyPhrases"]
    resources = ["*"]
  }
  statement {
    actions   = ["bedrock:InvokeModel","bedrock:InvokeModelWithResponseStream"]
    resources = ["*"]
  }
  statement {
    actions   = ["polly:SynthesizeSpeech"]
    resources = ["*"]
  }
  statement {
    actions   = ["aws-marketplace:ViewSubscriptions", "aws-marketplace:Subscribe"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "post_extra" {
  name   = "${var.project}-post-extra"
  policy = data.aws_iam_policy_document.post_extra.json
}

resource "aws_iam_role_policy_attachment" "post_extra" {
  role       = aws_iam_role.lambda_post.name
  policy_arn = aws_iam_policy.post_extra.arn
}

# Step Function IAM Role and Policy
data "aws_iam_policy_document" "step_function_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "step_function_role" {
  name               = "${var.project}-step-function-role"
  assume_role_policy = data.aws_iam_policy_document.step_function_assume_role.json
}

data "aws_iam_policy_document" "step_function_policy" {
  statement {
    effect = "Allow"
    actions = [
      "lambda:InvokeFunction",
      "lambda:InvokeAsync"
    ]
    resources = [
      aws_lambda_function.ingest.arn,
      aws_lambda_function.post.arn
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject"
    ]
    resources = [
      "arn:aws:s3:::${local.recordings_bucket_name}/*"
    ]
  }
}

resource "aws_iam_role_policy" "step_function_role_policy" {
  name   = "${var.project}-step-function-policy"
  role   = aws_iam_role.step_function_role.id
  policy = data.aws_iam_policy_document.step_function_policy.json
}
