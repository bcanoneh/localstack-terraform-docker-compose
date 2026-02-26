# output "s3_bucket_name" {
#   description = "Nombre del bucket S3 creado"
#   value       = aws_s3_bucket.bucket.bucket
# }

# output "sqs_queue_url" {
#   description = "URL de la cola SQS creada"
#   value       = aws_sqs_queue.queue.id
# }

# output "sqs_queue_arn" {
#   description = "ARN de la cola SQS creada"
#   value       = aws_sqs_queue.queue.arn
# }


output "bucket_name" {
  value = aws_s3_bucket.csv_bucket.bucket
}

output "lambda_name" {
  value = aws_lambda_function.csv_processor.function_name
}

# output "cron_rule" {
#   value = aws_cloudwatch_event_rule.cron_rule.name
# }



output "notification_tray_sqs_url" {
  value = aws_sqs_queue.notification_tray_sqs.id
}
