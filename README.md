# nube-actividad
 
Batches de ~1 KB a S3. Una Step Function parsea el batch, clasifica cada linea y la guarda en DynamoDB.
Las consultas se hacen por un HTTP API de API Gateway.
 
- Sospechosa (`Invalid user` o `POSSIBLE BREAK-IN ATTEMPT`) → tabla `SecurityAlerts`
- Normal → tabla `Logs`
Corre todo desde **WSL**, con AWS CLI ya configurado.
 
```bash
chmod +x start_logging.sh scripts/*.sh
 
./scripts/split-log.sh
./scripts/create-s3-bucket.sh
./scripts/package-lambda.sh
./scripts/create-api.sh
./start_logging.sh 60
```
 
`60` son los segundos entre cada upload (minimo 30 para la demo).
 
En la consola: DynamoDB → Explore items → Query `pk = LabSZ` en `Logs` y en `SecurityAlerts`.
Repite la query: deben aparecer mas items.
 
## Lambdas de consulta
 
- `get_alerts` escanea `SecurityAlerts` y devuelve `alerts`, cada uno con `id`, `timestamp`, `host`, `log` y `severity`. Sigue las paginas de DynamoDB para incluir todas las alertas.
- `get_logs` consulta `LogsByArrival` con `gsi_pk = LOG`, `Limit = N` y `ScanIndexForward = false`. Devuelve los resultados en `logs`, del mas reciente al mas antiguo.
## API Gateway (HTTP API)
 
`./scripts/create-api.sh` crea el API `LogsApi` con dos rutas, cada una a su Lambda:
 
| Metodo | Ruta | Lambda |
|---|---|---|
| GET | `/alerts` | `get_alerts` |
| GET | `/logs?top=N` | `get_logs` |
 
Al terminar imprime las URLs y las guarda en `api-url.txt`. Tienen esta forma:
 
```
https://<api-id>.execute-api.us-east-1.amazonaws.com/alerts
https://<api-id>.execute-api.us-east-1.amazonaws.com/logs?top=10
```
 
Para probar:
 
```bash
URL=$(cat api-url.txt)
curl -s "$URL/alerts" | python3 -m json.tool | head -40
curl -s "$URL/logs?top=5" | python3 -m json.tool
```
 
## Limpieza
 
```bash
./scripts/teardown.sh
```
 
Borra el bucket, las tablas, la Step Function, las Lambdas y el HTTP API.
 