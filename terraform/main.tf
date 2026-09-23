# terraform {
#   required_providers {
#     aws = {
#       source  = "hashicorp/aws"
#       version = "~> 5.0"
#     }
#   }
# }

# provider "aws" {
#   region                      = var.aws_region
#   access_key                  = "test"
#   secret_key                  = "test"
#   skip_credentials_validation = true
#   skip_requesting_account_id  = true
#   s3_use_path_style           = true

#   endpoints {
#     s3       = var.localstack_endpoint
#     sqs      = var.localstack_endpoint
#     sns      = var.localstack_endpoint
#     dynamodb = var.localstack_endpoint
#   }
# }

# resource "aws_s3_bucket" "bucket" {
#   bucket = var.s3_bucket_name
# }

# resource "aws_sqs_queue" "queue" {
#   name = var.sqs_queue_name
# }


terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "local" {}
}

provider "aws" {
  region                      = var.aws_region
  access_key                  = "test"
  secret_key                  = "test"
  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    s3         = var.localstack_endpoint
    lambda     = var.localstack_endpoint
    iam        = var.localstack_endpoint
    events     = var.localstack_endpoint
    sts        = var.localstack_endpoint
    dynamodb   = var.localstack_endpoint
    cloudwatch = var.localstack_endpoint
    sqs        = var.localstack_endpoint
    sns        = var.localstack_endpoint
  }
}

# ------------------------------------------
# S3 Bucket
# ------------------------------------------

resource "aws_s3_bucket" "csv_bucket" {
  bucket = var.bucket_name
}

# Carpetas
resource "aws_s3_object" "retroactive_parent_folder" {
  bucket  = aws_s3_bucket.csv_bucket.bucket
  key     = "retroactive-payments-by-branches/"
  content = ""

  depends_on = [aws_s3_bucket.csv_bucket]
}
resource "aws_s3_object" "pending_folder" {
  bucket  = aws_s3_bucket.csv_bucket.bucket
  key     = "retroactive-payments-by-branches/pending/"
  content = ""

  depends_on = [aws_s3_bucket.csv_bucket]
}

resource "aws_s3_object" "processed_folder" {
  bucket  = aws_s3_bucket.csv_bucket.bucket
  key     = "retroactive-payments-by-branches/processed/"
  content = ""
}

# ------------------------------------------
# IAM Role + Policies
# ------------------------------------------

resource "aws_iam_role" "lambda_role" {
  name = "${var.lambda_function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.lambda_function_name}-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"],
        Resource = [
          "${aws_s3_bucket.csv_bucket.arn}",
          "${aws_s3_bucket.csv_bucket.arn}/*",
        ]
      },
      {
        Effect   = "Allow",
        Action   = ["events:PutEvents"],
        Resource = "*"
      }
    ]
  })
}


# ==========================================================
# EVENT BUS PERSONALIZADO
# ==========================================================

resource "aws_cloudwatch_event_bus" "custom_bus" {
  name = var.bus_name
}

# ==========================================================
# COLA SQS PARA MONITOREAR EVENTOS
# ==========================================================

resource "aws_sqs_queue" "event_monitor" {
  name = var.sqs_queue_name
}

# ==========================================================
# REGLA QUE ESCUCHA TODOS LOS EVENTOS DEL BUS PERSONALIZADO
# ==========================================================

resource "aws_cloudwatch_event_rule" "monitor_rule" {
  name           = var.bus_rule
  description    = "Captura todos los eventos del custom bus"
  event_bus_name = aws_cloudwatch_event_bus.custom_bus.name

  event_pattern = jsonencode({
    "detail-type" = [
      "Merchant.CommercePaymentConfirm",
      "Merchant.LinkPaymentConfirm",
      "Merchant.PaymentDispersion",
      "Dispersion.ExternalDispersionMade",
      "Merchant.UpdatePaymentMerchantBranch",
    ]
  })
}

# ==========================================================
# TARGET: ENVÍA LOS EVENTOS A SQS
# ==========================================================

resource "aws_cloudwatch_event_target" "monitor_target" {
  rule           = aws_cloudwatch_event_rule.monitor_rule.name
  event_bus_name = aws_cloudwatch_event_bus.custom_bus.name
  target_id      = "event-monitor-target"
  arn            = aws_sqs_queue.event_monitor.arn

  depends_on = [aws_sqs_queue.event_monitor, aws_cloudwatch_event_rule.monitor_rule]
}

# ==========================================================
# PERMISOS: EVENTBRIDGE -> SQS (REQUIRED)
# ==========================================================

resource "aws_sqs_queue_policy" "monitor_queue_policy" {
  queue_url = aws_sqs_queue.event_monitor.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = { Service = "events.amazonaws.com" },
        Action    = "sqs:SendMessage",
        Resource  = aws_sqs_queue.event_monitor.arn,
        Condition = {
          ArnEquals = {
            "aws:SourceArn" : aws_cloudwatch_event_rule.monitor_rule.arn
          }
        }
      }
    ]
  })
}

# ==========================================================
# ACTUALIZAR IAM DE LA LAMBDA PARA PERMITIR PutEvents
# ==========================================================

resource "aws_iam_role_policy" "lambda_put_events_to_custom_bus" {
  name = "${var.lambda_function_name}-put-events-custom-bus"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["events:PutEvents"],
        Resource = aws_cloudwatch_event_bus.custom_bus.arn
      }
    ]
  })
}


# ------------------------------------------
# Lambda Function
# ------------------------------------------

resource "aws_lambda_function" "csv_processor" {
  function_name = var.lambda_function_name
  role          = aws_iam_role.lambda_role.arn
  handler       = "handler.handler"
  runtime       = "nodejs22.x"
  timeout       = 60

  filename         = "${path.module}/lambda/handler.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda/handler.zip")

  environment {
    variables = merge(
      {
        ZIGI_EVENT_BUS_TOPIC_ARN = aws_cloudwatch_event_bus.custom_bus.name
      },
      var.lambda_env
    )
  }
}

# ------------------------------------------
# EventBridge Rule (CRON JOB)
# ------------------------------------------

# resource "aws_cloudwatch_event_rule" "cron_rule" {
#   name                = "${var.lambda_function_name}-cron"
#   description         = "Ejecuta la lambda todos los días"
#   schedule_expression = var.cron_expression
# }

# resource "aws_cloudwatch_event_target" "lambda_target" {
#   rule      = aws_cloudwatch_event_rule.cron_rule.name
#   target_id = "lambda-csv-processor"
#   arn       = aws_lambda_function.csv_processor.arn
# }

# Permiso EventBridge → Lambda
# resource "aws_lambda_permission" "allow_eventbridge" {
#   statement_id  = "AllowExecutionFromEventBridge"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.csv_processor.function_name
#   principal     = "events.amazonaws.com"
#   source_arn    = aws_cloudwatch_event_rule.cron_rule.arn
# }


# Permisos S3 -> Lambda

resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.csv_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.csv_bucket.arn
}


# Notification S3 -> Lambda
resource "aws_s3_bucket_notification" "csv_upload_trigger" {
  bucket = aws_s3_bucket.csv_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.csv_processor.arn
    events              = ["s3:ObjectCreated:*"]

    filter_prefix = "retroactive-payments-by-branches/pending/"
    filter_suffix = ".csv"
  }

  depends_on = [
    aws_lambda_permission.allow_s3_invoke
  ]
}

# Dynamodb create table

resource "aws_dynamodb_table" "owners" {
  name           = var.dynamodb_table_name
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5

  hash_key  = "messageId"
  range_key = "messageCrc"

  attribute {
    name = "messageId"
    type = "S"
  }

  attribute {
    name = "messageCrc"
    type = "S"
  }
}


# Add target and rule to new event notification-tray


# Add SQS to nofiticaion-tray

resource "aws_sqs_queue" "notification_tray_sqs" {
  name = var.sqs_queue_notification_tray_name
}

resource "aws_cloudwatch_event_rule" "notification_tray_rule" {
  name           = var.bus_rule_notification_tray
  description    = "Captura los eventos de la cola de notification tray"
  event_bus_name = aws_cloudwatch_event_bus.custom_bus.name

  event_pattern = jsonencode({
    "detail-type" = [
      "NotificationTrayEvent.NotificationTrayEventMade",
    ]
  })
}

resource "aws_cloudwatch_event_target" "notification_tray_target" {
  rule           = aws_cloudwatch_event_rule.notification_tray_rule.name
  event_bus_name = aws_cloudwatch_event_bus.custom_bus.name
  target_id      = "notification-tray-target"
  arn            = aws_sqs_queue.notification_tray_sqs.arn

  depends_on = [aws_sqs_queue.notification_tray_sqs, aws_cloudwatch_event_rule.notification_tray_rule]
}


resource "aws_sqs_queue_policy" "notification_tray_queue_policy" {
  queue_url = aws_sqs_queue.notification_tray_sqs.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = { Service = "events.amazonaws.com" },
        Action    = "sqs:SendMessage",
        Resource  = aws_sqs_queue.notification_tray_sqs.arn,
        Condition = {
          ArnEquals = {
            "aws:SourceArn" : aws_cloudwatch_event_rule.notification_tray_rule.arn
          }
        }
      }
    ]
  })
}


# Add dynamo table to idempotency

resource "aws_dynamodb_table" "notification_tray_idempotency" {
  name           = var.dynamodb_table_name_notification_tray
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5

  hash_key  = "messageId"
  range_key = "messageCrc"

  attribute {
    name = "messageId"
    type = "S"
  }

  attribute {
    name = "messageCrc"
    type = "S"
  }
}


# Notification

resource "aws_sqs_queue" "notification_sqs" {
  name = var.sqs_queue_notification_name
}

resource "aws_cloudwatch_event_rule" "notification_rule" {
  name           = var.bus_rule_notification
  description    = "Captura los eventos de la cola de notification"
  event_bus_name = aws_cloudwatch_event_bus.custom_bus.name

  event_pattern = jsonencode({
    "detail-type" = [
      "NotificationEvent.NotificationEventMade",
    ]
  })
}

resource "aws_cloudwatch_event_target" "notification_target" {
  rule           = aws_cloudwatch_event_rule.notification_rule.name
  event_bus_name = aws_cloudwatch_event_bus.custom_bus.name
  target_id      = "notification-target"
  arn            = aws_sqs_queue.notification_sqs.arn

  depends_on = [aws_sqs_queue.notification_sqs, aws_cloudwatch_event_rule.notification_rule]
}


resource "aws_sqs_queue_policy" "notification_queue_policy" {
  queue_url = aws_sqs_queue.notification_sqs.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = { Service = "events.amazonaws.com" },
        Action    = "sqs:SendMessage",
        Resource  = aws_sqs_queue.notification_sqs.arn,
        Condition = {
          ArnEquals = {
            "aws:SourceArn" : aws_cloudwatch_event_rule.notification_rule.arn
          }
        }
      }
    ]
  })
}


# Add dynamo table to idempotency

resource "aws_dynamodb_table" "notification_idempotency" {
  name           = var.dynamodb_table_name_notification
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5

  hash_key  = "messageId"
  range_key = "messageCrc"

  attribute {
    name = "messageId"
    type = "S"
  }

  attribute {
    name = "messageCrc"
    type = "S"
  }
}
# Notification

# SNS Topic
resource "aws_sns_topic" "notification" {
  name = "notification"
}

# SQS Queues
resource "aws_sqs_queue" "notification" {
  name = "notification"
}

# SNS -> SQS Subscription: notification-tray
resource "aws_sns_topic_subscription" "notification_tray_subscription" {
  topic_arn = aws_sns_topic.notification.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.notification_tray_sqs.arn

  filter_policy = jsonencode({
    type = ["NotificationTrayEvent.NotificationTrayEventMade"]
  })
}

resource "aws_sns_topic_subscription" "notification_subscription" {
  topic_arn = aws_sns_topic.notification.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.notification_sqs.arn

  filter_policy = jsonencode({
    type = ["NotificationEvent.NotificationEventMade"]
  })
}

# SQS Policy for notification-tray to allow SNS to send messages
resource "aws_sqs_queue_policy" "notification_tray_sns_policy" {
  queue_url = aws_sqs_queue.notification_tray_sqs.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = { Service = "sns.amazonaws.com" },
        Action    = "sqs:SendMessage",
        Resource  = aws_sqs_queue.notification_tray_sqs.arn,
        Condition = {
          ArnEquals = {
            "aws:SourceArn" : aws_sns_topic.notification.arn
          }
        }
      }
    ]
  })
}

# SQS Policy for dispatch_notification to allow SNS to send messages
resource "aws_sqs_queue_policy" "notification_sns_policy" {
  queue_url = aws_sqs_queue.notification_sqs.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = { Service = "sns.amazonaws.com" },
        Action    = "sqs:SendMessage",
        Resource  = aws_sqs_queue.notification_sqs.arn,
        Condition = {
          ArnEquals = {
            "aws:SourceArn" : aws_sns_topic.notification.arn
          }
        }
      }
    ]
  })
}


# Bucket to notification
resource "aws_s3_bucket" "temp_notification_attachment_bucket" {
  bucket = var.temp-notification-attachment
}


resource "aws_s3_object" "temp_notification_attachment_bucket_folders" {
  for_each = toset([
    "td-movement-reports/",
    "affiliation-pos/"
  ])
  bucket  = aws_s3_bucket.temp_notification_attachment_bucket.bucket
  key     = each.value
  content = ""

  depends_on = [aws_s3_bucket.temp_notification_attachment_bucket]
}


resource "aws_iam_role" "lambda_automation_affiliation" {
  name = "${var.lambda_automation_affiliation_pos_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}
resource "aws_lambda_function" "affiliation_lambda" {
  function_name = var.lambda_automation_affiliation_pos_name
  role          = aws_iam_role.lambda_automation_affiliation.arn
  handler       = "handler.handler"
  runtime       = "nodejs22.x"
  timeout       = 60

  filename         = "${path.module}/lambda/handler.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda/handler.zip")

  environment {
    variables = merge(
      {
        ZIGI_EVENT_BUS_TOPIC_ARN = aws_cloudwatch_event_bus.custom_bus.name,

      },
      var.lambda_env
    )
  }
}


# Dispatch-Notification Add target and rule to new event dispatch-notification
# Add SQS to dispatch-notification
resource "aws_sqs_queue" "dispatch_notification_sqs" {
  name = var.sqs_queue_dispatch_notification_name
}

resource "aws_cloudwatch_event_rule" "dispatch_notification_rule" {
  name           = var.bus_rule_dispatch_notification
  description    = "Captura los eventos de la cola de dispatch notification tray"
  event_bus_name = aws_cloudwatch_event_bus.custom_bus.name

  event_pattern = jsonencode({
    "detail-type" = [
      "DispatchNotification.DispatchNotificationMade",
    ]
  })
}

resource "aws_cloudwatch_event_target" "dispatch_notification_target" {
  rule           = aws_cloudwatch_event_rule.dispatch_notification_rule.name
  event_bus_name = aws_cloudwatch_event_bus.custom_bus.name
  target_id      = "dispatch-notification-target"
  arn            = aws_sqs_queue.dispatch_notification_sqs.arn

  depends_on = [aws_sqs_queue.dispatch_notification_sqs, aws_cloudwatch_event_rule.dispatch_notification_rule]
}


resource "aws_sqs_queue_policy" "dispatch_notification_queue_policy" {
  queue_url = aws_sqs_queue.dispatch_notification_sqs.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = { Service = "events.amazonaws.com" },
        Action    = "sqs:SendMessage",
        Resource  = aws_sqs_queue.dispatch_notification_sqs.arn,
        Condition = {
          ArnEquals = {
            "aws:SourceArn" : aws_cloudwatch_event_rule.dispatch_notification_rule.arn
          }
        }
      }
    ]
  })
}


# Add dynamo table to idempotency

resource "aws_dynamodb_table" "dispatch_notification_idempotency" {
  name           = var.dynamodb_table_name_dispatch_notification
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5

  hash_key  = "messageId"
  range_key = "messageCrc"

  attribute {
    name = "messageId"
    type = "S"
  }

  attribute {
    name = "messageCrc"
    type = "S"
  }
}

# Dispatch-Notification End


# Lambda to query-commands-for-backoffice
resource "aws_lambda_function" "query_commands_for_backoffice_lambda" {
  function_name = var.lambda_query_commands_for_backoffice_name
  role          = aws_iam_role.lambda_query_commands_for_backoffice_iam.arn
  handler       = "handler.handler"
  runtime       = "nodejs22.x"
  timeout       = 60

  filename         = "${path.module}/lambda/query-commands/handler.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda/query-commands/handler.zip")

  environment {
    variables = merge(
      {
        ZIGI_EVENT_BUS_TOPIC_ARN = aws_cloudwatch_event_bus.custom_bus.name,

      },
      var.lambda_query_commands_backoffice_env
    )
  }
}

resource "aws_iam_role" "lambda_query_commands_for_backoffice_iam" {
  name = "${var.lambda_query_commands_for_backoffice_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}
# Lambda to query-commands-for-backoffice



# Add dynamo table to idempotency

resource "aws_dynamodb_table" "transaction_idempotency" {
  name           = var.dynamodb_table_name_transaction_idempotency
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5

  hash_key  = "messageId"
  range_key = "messageCrc"

  attribute {
    name = "messageId"
    type = "S"
  }

  attribute {
    name = "messageCrc"
    type = "S"
  }
}


# External dispersion table dynamodb and sqs queue
resource "aws_dynamodb_table" "external_dispersion" {
  name           = var.dynamodb_table_name_external_dispersion
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5

  hash_key  = "messageId"
  range_key = "messageCrc"

  attribute {
    name = "messageId"
    type = "S"
  }

  attribute {
    name = "messageCrc"
    type = "S"
  }
}


resource "aws_sqs_queue" "external_dispersion_sqs" {
  name = var.sqs_queue_external_dispersion_name
}
# External dispersion table dynamodb and sqs queue
