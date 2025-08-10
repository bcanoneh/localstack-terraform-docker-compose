output "s3_bucket_name" {
  description = "Nombre del bucket S3 creado"
  value       = aws_s3_bucket.bucket.bucket
}

output "sqs_queue_url" {
  description = "URL de la cola SQS creada"
  value       = aws_sqs_queue.queue.id
}

output "sqs_queue_arn" {
  description = "ARN de la cola SQS creada"
  value       = aws_sqs_queue.queue.arn
}
