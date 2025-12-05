output "recordings_bucket" { value = local.recordings_bucket_name }
output "outputs_bucket"    { value = local.outputs_bucket_name }
output "ingest_lambda_arn" { value = aws_lambda_function.ingest.arn }
output "post_lambda_arn"   { value = aws_lambda_function.post.arn }
# output "aws_connect_instance" { value = aws_connect_instance.this.id }