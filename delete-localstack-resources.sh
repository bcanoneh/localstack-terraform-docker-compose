#!/bin/bash

set -e

echo "🧹 Eliminando recursos de LocalStack..."

# Variables comunes
ENDPOINT="http://localhost:4566"
REGION="us-east-1"
PROFILE="localstack"

# Eliminar subscripciones SNS → SQS
TOPIC_ARN=$(aws sns list-topics \
  --endpoint-url "$ENDPOINT" \
  --region "$REGION" \
  --profile "$PROFILE" \
  --query 'Topics[?contains(TopicArn, `:pos`)].TopicArn' \
  --output text)

if [ -n "$TOPIC_ARN" ]; then
  SUBSCRIPTION_ARN=$(aws sns list-subscriptions-by-topic \
    --topic-arn "$TOPIC_ARN" \
    --endpoint-url "$ENDPOINT" \
    --region "$REGION" \
    --profile "$PROFILE" \
    --query 'Subscriptions[0].SubscriptionArn' \
    --output text)

  if [ "$SUBSCRIPTION_ARN" != "PendingConfirmation" ]; then
    aws sns unsubscribe \
      --subscription-arn "$SUBSCRIPTION_ARN" \
      --endpoint-url "$ENDPOINT" \
      --region "$REGION" \
      --profile "$PROFILE"
    echo "✅ Subscripción SNS eliminada."
  fi
fi

# Eliminar SNS Topic
if [ -n "$TOPIC_ARN" ]; then
  aws sns delete-topic \
    --topic-arn "$TOPIC_ARN" \
    --endpoint-url "$ENDPOINT" \
    --region "$REGION" \
    --profile "$PROFILE"
  echo "✅ Topic SNS eliminado."
fi

# Eliminar SQS Queue
QUEUE_URL=$(aws sqs get-queue-url \
  --queue-name pos \
  --endpoint-url "$ENDPOINT" \
  --region "$REGION" \
  --profile "$PROFILE" \
  --query 'QueueUrl' \
  --output text 2>/dev/null || true)

if [ -n "$QUEUE_URL" ]; then
  aws sqs delete-queue \
    --queue-url "$QUEUE_URL" \
    --endpoint-url "$ENDPOINT" \
    --region "$REGION" \
    --profile "$PROFILE"
  echo "✅ Queue SQS eliminada."
fi

# Eliminar tabla DynamoDB
aws dynamodb delete-table \
  --table-name pos-idempotency \
  --endpoint-url "$ENDPOINT" \
  --region "$REGION" \
  --profile "$PROFILE" && echo "✅ Tabla DynamoDB eliminada."

# Vaciar y eliminar bucket S3
BUCKET="pos-affiliation"

if aws s3api head-bucket --bucket "$BUCKET" \
  --endpoint-url "$ENDPOINT" \
  --region "$REGION" \
  --profile "$PROFILE" 2>/dev/null; then

  # Vaciar el bucket
  aws s3 rm "s3://$BUCKET" --recursive \
    --endpoint-url "$ENDPOINT" \
    --region "$REGION" \
    --profile "$PROFILE"

  # Eliminar el bucket
  aws s3api delete-bucket \
    --bucket "$BUCKET" \
    --endpoint-url "$ENDPOINT" \
    --region "$REGION" \
    --profile "$PROFILE"

  echo "✅ Bucket S3 eliminado."
else
  echo "ℹ️ Bucket S3 no existe, omitiendo."
fi

echo "✅ Todos los recursos han sido eliminados."
