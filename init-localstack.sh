#!/bin/bash

set -e

echo "⏳ Esperando que LocalStack esté listo..."

# Esperar a que LocalStack esté completamente listo
# until curl -s http://localhost:4566/_localstack/health | grep '"initScripts": "running"' > /dev/null; do
#   sleep 2
# done

echo "✅ LocalStack está listo. Creando recursos..."

# Crear tabla DynamoDB
aws dynamodb create-table \
  --table-name pos-idempotency \
  --attribute-definitions \
    AttributeName=messageId,AttributeType=S \
    AttributeName=messageCrc,AttributeType=S \
  --key-schema \
    AttributeName=messageId,KeyType=HASH \
    AttributeName=messageCrc,KeyType=RANGE \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --endpoint-url http://localhost:4566 \
  --region us-east-1 \
  --profile localstack || echo "⚠️ Tabla DynamoDB ya existe."

# Crear cola SQS
QUEUE_URL=$(aws sqs create-queue \
  --queue-name pos \
  --endpoint-url http://localhost:4566 \
  --region us-east-1 \
  --profile localstack \
  --query 'QueueUrl' \
  --output text)

echo "✅ SQS Queue URL: $QUEUE_URL"

# Crear SNS Topic
TOPIC_ARN=$(aws sns create-topic \
  --name pos \
  --endpoint-url http://localhost:4566 \
  --region us-east-1 \
  --profile localstack \
  --query 'TopicArn' \
  --output text)

echo "✅ SNS Topic ARN: $TOPIC_ARN"

# Obtener ARN de la cola
QUEUE_ARN=$(aws sqs get-queue-attributes \
  --queue-url "$QUEUE_URL" \
  --attribute-names QueueArn \
  --endpoint-url http://localhost:4566 \
  --region us-east-1 \
  --profile localstack \
  --query 'Attributes.QueueArn' \
  --output text)

echo "✅ SQS Queue ARN: $QUEUE_ARN"

# Establecer política para permitir a SNS enviar mensajes a SQS
# aws sqs set-queue-attributes \
#   --queue-url "$QUEUE_URL" \
#   --attributes "{\"Policy\":\"{
#     \\\"Version\\\":\\\"2012-10-17\\\",
#     \\\"Statement\\\":[
#       {
#         \\\"Effect\\\":\\\"Allow\\\",
#         \\\"Principal\\\":{\\\"Service\\\":\\\"sns.amazonaws.com\\\"},
#         \\\"Action\\\":\\\"sqs:SendMessage\\\",
#         \\\"Resource\\\":\\\"$QUEUE_ARN\\\",
#         \\\"Condition\\\":{
#           \\\"ArnEquals\\\":{\\\"aws:SourceArn\\\":\\\"$TOPIC_ARN\\\"}
#         }
#       }
#     ]
#   }\"}" \
#   --endpoint-url http://localhost:4566 \
#   --region us-east-1 \
#   --profile localstack

# Suscribir la cola al topic SNS
aws sns subscribe \
  --topic-arn "$TOPIC_ARN" \
  --protocol sqs \
  --notification-endpoint "$QUEUE_ARN" \
  --endpoint-url http://localhost:4566 \
  --region us-east-1 \
  --profile localstack

echo "✅ Subscripción SNS → SQS creada con éxito."

# Crear bucket S3
aws s3api create-bucket \
  --bucket pos-affiliation \
  --endpoint-url http://localhost:4566 \
  --region us-east-1 \
  --profile localstack || echo "Ya existe bucket"

echo "✅ Bucket S3 pos-affiliation creado con éxito."
