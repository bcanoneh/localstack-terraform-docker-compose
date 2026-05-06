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

variable "lambda_automation_affiliation_pos_name" {
  type        = string
  description = "Name of affiliation pos lambda"
  default     = "automation_affiliation_pos"
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

# Notification eventbridge variables
variable "sqs_queue_notification_name" {
  type        = string
  description = "Name to sqs notification tray"
}

variable "bus_rule_notification" {
  type        = string
  description = "Bus rule"
  default     = "notification_rule"
}


variable "dynamodb_table_name_notification" {
  type        = string
  description = "Name table notification idempotency"
}

# Notification eventbridge variables
variable "sqs_queue_notification_tray_name" {
  type        = string
  description = "Name to sqs notification tray"
}


variable "bus_rule_notification_tray" {
  type        = string
  description = "Bus rule"
  default     = "notification_tray_rule"
}


variable "dynamodb_table_name_notification_tray" {
  type        = string
  description = "Name table notification tray idempotency"
}

variable "temp-notification-attachment" {
  type        = string
  description = "Name of bucket to temp-notification-attachment"
  default     = "temp-notification-attachment"
}


# Dispatch-Notification
# Notification eventbridge variables
variable "sqs_queue_dispatch_notification_name" {
  type        = string
  description = "Name to sqs dispatch notification"
}


variable "bus_rule_dispatch_notification" {
  type        = string
  description = "Bus rule"
  default     = "dispatch_notification_rule"
}


variable "dynamodb_table_name_dispatch_notification" {
  type        = string
  description = "Name table dispatch notification idempotency"
}
# Dispatch-Notification End
