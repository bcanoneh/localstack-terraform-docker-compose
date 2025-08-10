# Create bucket
aws --endpoint-url=http://localhost:4566 s3api create-bucket \
  --bucket pos-affiliation \
  --region us-east-1 \
  --profile localstack



# List buckets
aws --endpoint-url=http://localhost:4566 s3 ls --profile localstack


# Subir archivos

aws --endpoint-url=http://localhost:4566 s3 cp file.txt s3://mi-bucket-pruebas/file.txt --profile localstack

# Listar archivos


aws --endpoint-url=http://localhost:4566 s3 ls s3://mi-bucket-pruebas/ --profile localstack


# Ver el contenido
aws --endpoint-url=http://localhost:4566 s3 cp s3://mi-bucket-pruebas/file.txt - --profile localstack


# Crear SQS y SNS

aws --endpoint-url=http://localhost:4566 sqs create-queue \
  --queue-name pos \
  --profile localstack

## "QueueUrl": "http://sqs.us-east-1.localstack:4566/000000000000/pos"


aws --endpoint-url=http://localhost:4566 sns create-topic \
  --name pos \
  --profile localstack

## "TopicArn": "arn:aws:sns:us-east-1:000000000000:pos"


# Suscribir el evento la cola.
aws --endpoint-url=http://localhost:4566 sqs get-queue-url \
  --queue-name pos \
  --profile localstack

## "QueueUrl": "http://sqs.us-east-1.localstack:4566/000000000000/pos"

# obtener el arn

aws --endpoint-url=http://localhost:4566 sqs get-queue-attributes \
  --queue-url http://localhost:4566/000000000000/pos \
  --attribute-name QueueArn \
  --profile localstack

## {
    ## "Attributes": {
    ##    "QueueArn": "arn:aws:sqs:us-east-1:000000000000:pos"
  ##  }
##}
##

# Suscribir Finalmente, suscribe la cola al topic
aws --endpoint-url=http://localhost:4566 sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:000000000000:pos \
  --protocol sqs \
  --notification-endpoint arn:aws:sqs:us-east-1:000000000000:pos \
  --profile localstack

## {
    ##"SubscriptionArn": "arn:aws:sns:us-east-1:000000000000:pos:72572eca-e024-4f2d-ae8e-08f67fce9755"
##}

# Publish message

aws --endpoint-url=http://localhost:4566 sns publish \
  --topic-arn arn:aws:sns:us-east-1:000000000000:pos \
  --message "Hola desde SNS" \
  --profile localstack

## {
 #   "MessageId": "0c64d692-74e8-457b-9156-c579b48f4401"
#}

# Read message

aws --endpoint-url=http://localhost:4566 sqs receive-message \
  --queue-url http://localhost:4566/000000000000/pos \
  --profile localstack



# create dynamodb

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
  --profile localstack


# Esperar a que la tabla esté activa
aws dynamodb wait table-exists \
  --table-name pos-idempotency \
  --endpoint-url http://localhost:4566 \
  --region us-east-1 \
  --profile localstack