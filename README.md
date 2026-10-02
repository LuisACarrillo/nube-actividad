# nube-actividad

Batches de ~1 KB a S3. Una Step Function parsea el batch, clasifica cada linea y la guarda en DynamoDB.

- Sospechosa (`Invalid user` o `POSSIBLE BREAK-IN ATTEMPT`) → tabla `SecurityAlerts`
- Normal → tabla `Logs`

Corre todo desde **WSL**, con AWS CLI ya configurado.

```bash
chmod +x start_logging.sh scripts/*.sh

./scripts/split-log.sh
./scripts/create-s3-bucket.sh
./scripts/package-lambda.sh
./start_logging.sh 60
```

`60` son los segundos entre cada upload.

En la consola: DynamoDB → Explore items → Query `pk = LabSZ` en `Logs` y en `SecurityAlerts`.
Repite la query: deben aparecer mas items.

## Lambdas de consulta

- `get_alerts` escanea `SecurityAlerts` y devuelve `alerts`, cada uno con `id`, `timestamp`, `host`, `log` y `severity`. Sigue las paginas de DynamoDB para incluir todas las alertas.
- `get_logs` consulta `LogsByArrival` con `gsi_pk = LOG`, `Limit = N` y `ScanIndexForward = false`. Invocala con un evento como `{"N": 10}`; devuelve los resultados en `logs`, del mas reciente al mas antiguo.

Al terminar:

```bash
./scripts/teardown.sh
```
