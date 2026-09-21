# nube-actividad

Sistema de logs: batches de ~1 KB a S3, Lambda los guarda en DynamoDB.

Corre todo desde **WSL**, con AWS CLI ya configurado.

```bash
chmod +x start_logging.sh scripts/*.sh

./scripts/split-log.sh
./scripts/create-s3-bucket.sh
./scripts/package-lambda.sh
./start_logging.sh 60
```

`60` son los segundos entre cada upload.

En la consola de AWS: DynamoDB → Explore items → tabla `logging-logs` → Query `pk = LabSZ`.
Cada vez que repitas la query deben aparecer mas items.

Al terminar:

```bash
./scripts/teardown.sh
```
