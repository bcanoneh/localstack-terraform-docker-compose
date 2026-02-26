
# s3_bucket_name     = "my-local-bucket"
sqs_queue_name       = "my-local-queue"
aws_region           = "us-east-1"
localstack_endpoint  = "http://localstack:4566"
bucket_name          = "eagle-populate-loads"
bucket_folder        = "pending"
lambda_function_name = "eagle-serverless-lambda"

lambda_env = {
  ZIGI_EVENT_BUS_TOPIC_ARN = "eagle-event-bus"
  BUCKET_NAME              = "eagle-populate-loads"
  BUCKET_FOLDER            = "pending"
  SOME_SECRET              = "12345"
}
bus_name                              = "eagle-event-bus"
bus_rule                              = "monitor-all-events"
dynamodb_table_name                   = "merchant-idempotency"
sqs_queue_notification_tray_name      = "notification_tray"
dynamodb_table_name_notification_tray = "notification-tray-idempotency"


sqs_queue_notification_name      = "notification"
dynamodb_table_name_notification = "notification-idempotency"
