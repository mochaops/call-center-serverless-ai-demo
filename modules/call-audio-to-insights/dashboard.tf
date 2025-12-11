
resource "aws_cloudwatch_dashboard" "this" {
  dashboard_name = "${var.project}-call--${random_id.suffix.hex}"
  dashboard_body = jsonencode({
    "widgets" : [
      {
        "type" : "metric",
        "height" : 5,
        "width" : 10,
        "y" : 0,
        "x" : 0,
        "properties" : {
          "metrics" : [
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.post.function_name, { "id" : "invokes", "label" : "Total Requests" }],
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.post.function_name, { "id" : "duration", "label" : "Average Response Time", "stat" : "Average" }],
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.post.function_name, { "id" : "invoke_errors", "visible" : false }],
            ["AWS/Lambda", "Url4xxCount", "FunctionName", aws_lambda_function.post.function_name, { "id" : "errors_400", "visible" : false }],
            ["AWS/Lambda", "Url5xxCount", "FunctionName", aws_lambda_function.post.function_name, { "id" : "errors_500", "visible" : false }],
            [{ "label" : "Total Errors", "color" : "#d62728", "expression" : "invoke_errors + errors_400 + errors_500", "id" : "total_errors" }],
            [{ "label" : "Sucess Rate (%)", "color" : "#2ca02c", "expression" : "100 - ((total_errors/invokes) * 100)", "id" : "sucess_rate" }]
          ],
          "title" : "Post Ingestion Lambda",
          "region" : var.region,
          "stat" : "Sum",
          "view" : "singleValue",
          "setPeriodToTimeRange" : true
        }
      },
      {
        "height" : 5,
        "width" : 7,
        "y" : 0,
        "x" : 10,
        "type" : "metric",
        "properties" : {
          "view" : "timeSeries",
          "stacked" : true,
          "metrics" : [
            ["AWS/DynamoDB", "ConsumedWriteCapacityUnits", "TableName", aws_dynamodb_table.this.name, { "label" : "Written Objects", "color" : "#ff7f0e" }],
            ["AWS/DynamoDB", "ConsumedReadCapacityUnits", "TableName", aws_dynamodb_table.this.name, { "label" : "Read Objects", "color" : "#2ca02c" }]
          ],
          "title" : "DynamoDB Read / Write Capacity",
          "region" : var.region,
          "setPeriodToTimeRange" : true
        }
      },
      {
        "height" : 5,
        "width" : 6,
        "y" : 0,
        "x" : 17,
        "type" : "metric",
        "properties" : {
          "metrics" : [
            ["AWS/DynamoDB", "ConsumedWriteCapacityUnits", "TableName", aws_dynamodb_table.this.name, { "color" : "#ff7f0e", "label" : "Written Objects" }],
            ["AWS/DynamoDB", "ConsumedReadCapacityUnits", "TableName", aws_dynamodb_table.this.name, { "color" : "#2ca02c", "label" : "Read Objects" }]
          ],
          "view" : "pie",
          "region" : var.region,
          "stat" : "SampleCount",
          "setPeriodToTimeRange" : true,
          "title" : "DynamoDB Read/Write Comparison (%)"
        }
      },
      {
        "x" : 0,
        "y" : 5,
        "width" : 23,
        "height" : 6,
        "type" : "metric",
        "properties" : {
          "metrics" : [
            ["${var.project}-${random_id.suffix.hex}", "positiveSentiment", "service", "call-insights"],
            ["${var.project}-${random_id.suffix.hex}", "negativeSentiment", "service", "call-insights"],
            ["${var.project}-${random_id.suffix.hex}", "mixedSentiment", "service", "call-insights"]
          ],
          "region" : var.region,
          "view" : "gauge",
          "stat" : "Sum",
          "setPeriodToTimeRange" : true,
          "sparkline" : false,
          "trend" : false,
          "stacked" : true,
          "title" : "Call Insights",
          "yAxis" : {
            "left" : {
              "min" : 1,
              "max" : 200
            }
          }
        }
      }
    ]
  })
}
