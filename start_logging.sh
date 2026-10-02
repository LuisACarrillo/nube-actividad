# Uso: ./start_logging.sh 30
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scripts/send-logs.sh" "$@"
