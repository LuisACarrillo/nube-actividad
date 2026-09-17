# nube-actividad

Sistema de logs: batches de ~1 KB a S3, Lambda los convierte a CSV.

Corre todo desde **WSL**, con AWS CLI ya configurado.

```bash
chmod +x start_logging.sh scripts/*.sh

./scripts/split-log.sh
./scripts/create-s3-bucket.sh
./scripts/package-lambda.sh
./start_logging.sh 30
```

Ver CSV de salida:

```bash
aws s3 ls s3://logging-$(aws sts get-caller-identity --query Account --output text)/output/
```

Al terminar, borra Lambda, bucket y archivos locales (`batches/`, `build/`):

```bash
./scripts/teardown.sh
```

