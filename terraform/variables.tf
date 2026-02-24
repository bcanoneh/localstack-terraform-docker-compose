variable "aws_region" {
  description = "Región AWS para LocalStack"
  type        = string
  default     = "us-east-1"
}

# variable "s3_bucket_name" {
#   description = "Nombre del bucket S3"
#   type        = string
#   default     = "my-local-bucket"
# }

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

variable "bucket_name" {
  type        = string
  description = "Nombre del bucket S3"
}

variable "lambda_function_name" {
  type        = string
  description = "Nombre de la lambda"
}

variable "cron_expression" {
  type        = string
  description = "Expresión CRON para EventBridge"
  default     = "cron(0 6 * * ? *)"
}

variable "bucket_folder" {
  type        = string
  description = "Carpeta dentro del bucket"
}

variable "lambda_env" {
  type        = map(string)
  description = "Variables de entorno para la Lambda"
  default     = {}
}

variable "bus_name" {
  type        = string
  description = "Event bus name"
}


variable "bus_rule" {
  type        = string
  description = "Bus rule"
}


variable "dynamodb_table_name" {
  type        = string
  description = "Name table to dynamodb"
}
