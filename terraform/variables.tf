variable "aws_region" {
  description = "Región AWS para LocalStack"
  type        = string
  default     = "us-east-1"
}

variable "s3_bucket_name" {
  description = "Nombre del bucket S3"
  type        = string
  default     = "my-local-bucket"
}

variable "sqs_queue_name" {
  description = "Nombre de la cola SQS"
  type        = string
  default     = "my-local-queue"
}

variable "localstack_endpoint" {
  description = "Endpoint de LocalStack"
  type        = string
  default     = "http://localstack:4566" # Cambiar a http://localhost:4566 si ejecutas en host
}
