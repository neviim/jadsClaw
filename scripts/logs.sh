#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# logs.sh — Visualiza logs do OpenClawD
# Uso: ./scripts/logs.sh [dev|prod] [opções]
#
# Opções:
#   --follow, -f     Acompanhar logs em tempo real
#   --tail N         Mostrar últimas N linhas (padrão: 100)
#   --since TEMPO    Mostrar logs desde TEMPO (ex: "1h", "30m", "2024-01-01")
# =============================================================================

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV="${1:-prod}"
shift 2>/dev/null || true

# Valores padrão
FOLLOW=""
TAIL="100"
SINCE=""

# Processar argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        --follow|-f)
            FOLLOW="--follow"
            shift
            ;;
        --tail)
            TAIL="$2"
            shift 2
            ;;
        --since)
            SINCE="--since $2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

if [ "$ENV" = "dev" ]; then
    ENV_DIR="${PROJECT_ROOT}/dev"
    COMPOSE_CMD="docker compose --project-directory ${ENV_DIR} -f ${PROJECT_ROOT}/base/docker-compose.yml -f ${ENV_DIR}/docker-compose.override.yml"
elif [ "$ENV" = "prod" ]; then
    ENV_DIR="${PROJECT_ROOT}/prod"
    COMPOSE_CMD="docker compose --project-directory ${ENV_DIR} -f ${PROJECT_ROOT}/base/docker-compose.yml -f ${ENV_DIR}/docker-compose.prod.yml"
else
    echo "Ambiente inválido: '${ENV}'. Use 'dev' ou 'prod'."
    exit 1
fi

echo ""
echo "--- Logs do OpenClawD (${ENV}) | tail=${TAIL} ---"
echo "--- Ctrl+C para sair ---"
echo ""

cd "${ENV_DIR}"
${COMPOSE_CMD} logs --tail="${TAIL}" ${FOLLOW} ${SINCE} openclawd
