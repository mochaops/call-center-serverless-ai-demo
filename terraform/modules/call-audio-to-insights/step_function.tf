resource "aws_sfn_state_machine" "this" {
  name     = "${var.project}-state-machine"
  role_arn = aws_iam_role.step_function_role.arn

  definition = <<EOF
{
  "Comment": "State Machine for Audio to Insights",
  "StartAt": "IngestAudio",
  "States": {
    "IngestAudio": {
      "Type": "Task",
      "Resource": "${aws_lambda_function.ingest.arn}",
      "Next": "PostProcess"
    },
    "PostProcess": {
      "Type": "Task",
      "Resource": "${aws_lambda_function.post.arn}",
      "End": true
    }
  }
}
EOF
}

# EventBridge rule for S3 ObjectCreated events
resource "aws_cloudwatch_event_rule" "s3_object_created" {
  name        = "${var.project}-s3-object-created"
  description = "Trigger Step Function when new audio file is uploaded to S3"

  event_pattern = jsonencode({
    "source" : ["aws.s3"],
    "detail-type" : ["Object Created"],
    "detail" : {
      "bucket" : {
        "name" : [local.recordings_bucket_name]
      },
      "object" : {
        "key" : [{
          "prefix" : var.recordings_prefix
        }]
      }
    }
  })
}

# EventBridge target - Start Step Function execution
resource "aws_cloudwatch_event_target" "s3_to_step_function" {
  rule      = aws_cloudwatch_event_rule.s3_object_created.name
  target_id = "step-function"
  arn       = aws_sfn_state_machine.this.arn
  role_arn  = aws_iam_role.eventbridge_to_sfn.arn
}

# IAM role for EventBridge to start Step Function
resource "aws_iam_role" "eventbridge_to_sfn" {
  name = "${var.project}-eventbridge-to-sfn"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "events.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "eventbridge_to_sfn" {
  name = "${var.project}-eventbridge-to-sfn-policy"
  role = aws_iam_role.eventbridge_to_sfn.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "states:StartExecution"
      ]
      Resource = aws_sfn_state_machine.this.arn
    }]
  })
}