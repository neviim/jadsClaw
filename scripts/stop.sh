#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# stop.sh — Para todos os containers do OpenClawD
# Uso: ./scripts/stop.sh [dev|prod] [--remove]
# =============================================================================

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV="${1:-prod}"
REMOVE="${2:-}"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

log_ok()   { echo -e "${GREEN}[OK]${NC}    $1"; }
log_info() { echo -e "${CYAN}[INFO]${NC}  $1"; }

echo ""
echo "============================================"
echo "  OpenClawD — Parada (${ENV})"
echo "============================================"
echo ""

if [ "$ENV" = "dev" ]; then
    ENV_DIR="${PROJECT_ROOT}/dev"
    COMPOSE_CMD="docker compose -f ${PROJECT_ROOT}/base/docker-compose.yml -f ${ENV_DIR}/docker-compose.override.yml"
elif [ "$ENV" = "prod" ]; then
    ENV_DIR="${PROJECT_ROOT}/prod"
    COMPOSE_CMD="docker compose -f ${PROJECT_ROOT}/base/docker-compose.yml -f ${ENV_DIR}/docker-compose.prod.yml"
else
    echo -e "${RED}[FALHA]${NC} Ambiente inválido: '${ENV}'. Use 'dev' ou 'prod'."
    exit 1
fi

cd "${ENV_DIR}"

if [ "$REMOVE" = "--remove" ]; then
    log_info "Parando e removendo containers, redes e volumes anônimos..."
    ${COMPOSE_CMD} down -v
    log_ok "Containers removidos e volumes anônimos limpos."
else
    log_info "Parando containers..."
    ${COMPOSE_CMD} down
    log_ok "Containers parados."
fi

# Verificar se realmente parou
STATUS=$(docker inspect --format='{{.State.Status}}' openclaw_core 2>/dev/null || echo "removed")
if [ "$STATUS" = "removed" ] || [ "$STATUS" = "exited" ]; then
    log_ok "Container openclaw_core não está mais rodando."
else
    echo -e "${RED}[AVISO]${NC} Container ainda existe com status: ${STATUS}"
fi

echo ""
echo "============================================"
echo -e "  ${GREEN}OpenClawD parado.${NC}"
echo "============================================"
echo ""
echo "  Para reiniciar: ./scripts/start.sh ${ENV}"
echo ""
