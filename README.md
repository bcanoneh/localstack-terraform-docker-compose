# Simulacion local de infraestructura ZIGI

Este repositorio levanta una representacion local de varios servicios AWS usados por ZIGI. La ejecucion se hace con [LocalStack](https://localstack.cloud/) dentro de Docker y Terraform como herramienta de aprovisionamiento.

La infraestructura es exclusivamente local: no crea recursos en una cuenta AWS real. Las credenciales utilizadas por Terraform y LocalStack son de prueba.

## Que incluye

La configuracion actual modela, entre otros, estos componentes:

- S3 para cargas CSV y adjuntos temporales.
- Lambda para procesar los archivos y automatizar afiliaciones POS.
- EventBridge con un bus personalizado y reglas para eventos de pagos, dispersion y notificaciones.
- SQS para monitoreo de eventos, notificaciones, notification tray y dispersion externa.
- SNS para notificaciones.
- DynamoDB para tablas de idempotencia.
- IAM para los roles y permisos de las Lambdas.
- CloudWatch, CloudWatch Logs, IAM, KMS, SES y otros servicios habilitados en LocalStack.

Los nombres y eventos concretos se encuentran en `terraform/terraform.tfvars` y `terraform/main.tf`. Esta configuracion simula las integraciones de ZIGI; no reemplaza los servicios administrados ni las politicas de seguridad de AWS.

## Requisitos

Instala antes de comenzar:

- Docker Desktop con Docker Compose.
- Git.
- Python 3, si vas a usar el entorno virtual para ejecutar AWS CLI Local.

En macOS, verifica la instalacion con:

```bash
docker --version
docker compose version
python3 --version
```

Docker debe estar iniciado y tener permisos para montar el socket `/var/run/docker.sock`, ya que LocalStack lo usa para ejecutar Lambdas.

## Clonar y preparar el entorno

```bash
git clone <URL_DEL_REPOSITORIO>
cd docker-localstack
```

El archivo `.env` contiene `LOCALSTACK_AUTH_TOKEN` y esta excluido del control de versiones. Cada desarrollador debe crear su propia copia a partir de las credenciales autorizadas para su entorno:

```dotenv
LOCALSTACK_AUTH_TOKEN=<token_de_LocalStack>
```

No publiques este token ni lo incluyas en commits. Si solo necesitas una simulacion sin funciones que requieran autenticacion, consulta la configuracion de la licencia de LocalStack de tu equipo.

Los siguientes archivos tambien forman parte del contexto de construccion y deben estar disponibles:

- `docker/corp-ca.crt`: certificado CA corporativo usado por ambas imagenes.
- `terraform/lambda/handler.zip`: paquete de la Lambda con el handler `handler.handler`.

### Usar `awslocal` dentro de un virtualenv

No es necesario instalar AWS CLI globalmente en la maquina. El repositorio incluye `awscli-local` en `requirements.txt`, que proporciona el comando `awslocal` y configura automaticamente el endpoint de LocalStack.

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
awslocal --version
```

Con el entorno virtual activado, usa `awslocal` en lugar de `aws`:

```bash
awslocal s3 ls
awslocal sqs list-queues
awslocal dynamodb list-tables
awslocal lambda list-functions
```

Si necesitas seleccionar la region, puedes definirla en el entorno virtual mediante variables de entorno:

```bash
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
```

El endpoint utilizado por `awslocal` es `http://localhost:4566`. Ejecuta `deactivate` al terminar para salir del entorno virtual.

## Arranque recomendado

Desde la raiz del proyecto ejecuta:

```bash
docker compose up --build
```

El flujo es el siguiente:

1. Se construyen las imagenes de LocalStack y Terraform, incluyendo el certificado corporativo.
2. LocalStack expone el endpoint principal en `http://localhost:4566`.
3. Compose espera el healthcheck de LocalStack.
4. El contenedor Terraform monta `./terraform` en `/workspace`, ejecuta `terraform init` y aplica `terraform.tfvars` automaticamente.
5. Terraform crea los buckets, colas, topics, tablas, reglas, targets, roles y Lambdas definidos en `terraform/main.tf`.

Para ejecutar en segundo plano:

```bash
docker compose up --build -d
docker compose ps
docker compose logs -f localstack
docker compose logs -f terraform
```

La primera construccion puede tardar porque descarga las imagenes base y el provider de AWS de Terraform.

## Verificar el entorno

LocalStack debe responder en el puerto `4566`:

```bash
curl http://localhost:4566/_localstack/health
```

Ejemplos de consultas desde el host usando `awslocal`:

```bash
awslocal s3 ls

awslocal sqs list-queues

awslocal dynamodb list-tables

awslocal lambda list-functions
```

Los scripts auxiliares existentes (`commands.sh`, `init-localstack.sh` y `delete-localstack-resources.sh`) invocan `aws` directamente y esperan un perfil llamado `localstack`. Para mantener el uso aislado en el entorno virtual, instala tambien el cliente AWS dentro de `.venv` y configura ese perfil:

```bash
python -m pip install awscli
aws configure set aws_access_key_id test --profile localstack
aws configure set aws_secret_access_key test --profile localstack
aws configure set region us-east-1 --profile localstack
aws configure set output json --profile localstack
```

Estas credenciales solo se envian al endpoint local de LocalStack. Para las consultas manuales, sigue usando `awslocal`; la instalacion de `awscli` anterior solo permite ejecutar los scripts actuales sin instalar `aws` globalmente.

## Probar el flujo S3 -> Lambda

La Lambda principal escucha objetos CSV bajo el prefijo `retroactive-payments-by-branches/pending/`. Para probar el disparador:

```bash
printf 'id,amount\nlocal-1,100\n' > /tmp/zigi-example.csv

awslocal s3 cp /tmp/zigi-example.csv \
  s3://eagle-populate-loads/retroactive-payments-by-branches/pending/zigi-example.csv
```

La aplicacion consumidora configurada en `lambda_env` usa `host.docker.internal:5200` como `ALB_HOST`. Si la Lambda necesita comunicarse con un servicio que corre en el host, ese servicio debe estar escuchando en el puerto esperado y aceptar conexiones desde Docker.

## Publicar y leer eventos

El bus personalizado se llama `eagle-event-bus`. Algunas reglas escuchan estos `detail-type`:

- `Merchant.CommercePaymentConfirm`
- `Merchant.LinkPaymentConfirm`
- `Merchant.PaymentDispersion`
- `Dispersion.ExternalDispersionMade`
- `Merchant.UpdatePaymentMerchantBranch`
- `NotificationEvent.NotificationEventMade`
- `NotificationTrayEvent.NotificationTrayEventMade`

Para inspeccionar una cola creada por Terraform:

```bash
awslocal sqs get-queue-url --queue-name notification_tray

awslocal sqs receive-message \
  --queue-url http://localhost:4566/000000000000/notification_tray
```

El formato exacto del evento y los filtros SNS/EventBridge deben respetar las reglas declaradas en `terraform/main.tf`.

## Scripts auxiliares

### `commands.sh`

Contiene ejemplos interactivos de AWS CLI para S3, SQS, SNS y DynamoDB. Es material de referencia y no forma parte del arranque automatico.

### `init-localstack.sh`

Crea manualmente una tabla DynamoDB, la cola y topic `pos`, su suscripcion SNS -> SQS y el bucket `pos-affiliation`. Usalo solo para el escenario legacy o para pruebas aisladas; el aprovisionamiento principal se realiza con Terraform.

```bash
chmod +x init-localstack.sh delete-localstack-resources.sh
./init-localstack.sh
```

### `delete-localstack-resources.sh`

Elimina los recursos del escenario manual `pos` y `pos-affiliation`. No es equivalente a `terraform destroy` y no elimina necesariamente todos los recursos creados por Terraform.

```bash
./delete-localstack-resources.sh
```

## Detener o reiniciar

Detener los contenedores manteniendo el estado persistido:

```bash
docker compose down
```

El volumen `./localstack:/var/lib/localstack` conserva datos de LocalStack en el workspace. Para borrar tambien ese estado local y comenzar de cero:

```bash
docker compose down
rm -rf localstack/*
```

Usa esta ultima opcion con cuidado: elimina los datos locales persistidos. El estado de Terraform esta en `terraform/terraform.tfstate` y se excluye del control de versiones.

## Estructura del proyecto

```text
.
├── docker-compose.yml                 # Orquestacion de LocalStack y Terraform
├── .env                                # Token local, no versionado
├── docker/
│   ├── Dockerfile.localstack           # LocalStack + CA corporativa
│   ├── Dockerfile.terraform            # Terraform + CA corporativa
│   └── corp-ca.crt                     # CA requerida para construir las imagenes
├── terraform/
│   ├── main.tf                         # Recursos AWS simulados
│   ├── variables.tf                    # Variables y valores por defecto
│   ├── terraform.tfvars                # Nombres y configuracion del escenario ZIGI
│   ├── outputs.tf                      # Salidas de Terraform
│   └── lambda/handler.zip              # Paquete desplegado en las Lambdas
├── init-localstack.sh                  # Bootstrap manual del escenario legacy
├── delete-localstack-resources.sh      # Limpieza del escenario legacy
├── commands.sh                         # Ejemplos de AWS CLI
└── file.txt                            # Archivo de ejemplo para S3
```

## Problemas frecuentes

- **Falla la construccion con `corp-ca.crt`:** confirma que `docker/corp-ca.crt` existe y que Docker puede leerlo.
- **Terraform no encuentra `handler.zip`:** confirma que `terraform/lambda/handler.zip` existe y contiene `handler.handler`.
- **El contenedor Terraform no conecta con LocalStack:** espera el healthcheck y revisa `docker compose logs localstack`.
- **AWS CLI no encuentra el perfil:** crea `localstack` con los comandos de configuracion anteriores o elimina `--profile localstack` de tus comandos manuales.
- **Una Lambda no alcanza el backend local:** usa `host.docker.internal` desde el contenedor y verifica que el backend escuche en una interfaz accesible, no solo en `127.0.0.1`.
- **Los cambios de Terraform no se aplican:** revisa los logs del servicio `terraform`; el contenedor aplica automaticamente al iniciar, por lo que normalmente basta con `docker compose up --build`.

## Alcance y seguridad

Este proyecto es un entorno de desarrollo y pruebas. No uses sus credenciales, certificados, endpoints, datos de ejemplo ni politicas como configuracion de produccion. Revisa especialmente `.env`, `terraform.tfvars`, logs de LocalStack y el contenido de `lambda_env` antes de compartirlos.