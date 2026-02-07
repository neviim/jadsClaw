#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# status.sh — Verifica o status completo do OpenClawD
# Uso: ./scripts/status.sh [dev|prod]
# =============================================================================

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV="${1:-prod}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_ok()   { echo -e "${GREEN}[OK]${NC}    $1"; }
log_fail() { echo -e "${RED}[FALHA]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[AVISO]${NC} $1"; }
log_info() { echo -e "${CYAN}[INFO]${NC}  $1"; }

if [ "$ENV" != "dev" ] && [ "$ENV" != "prod" ]; then
    log_fail "Ambiente invalido: '${ENV}'. Use 'dev' ou 'prod'."
    exit 1
fi

PORTA="18789"

echo ""
echo "============================================"
echo "  OpenClawD — Status (${ENV})"
echo "============================================"
echo ""

# ---- 1. Docker daemon ----
log_info "Docker daemon..."
if docker info &>/dev/null; then
    log_ok "Docker daemon ativo."
else
    log_fail "Docker daemon inativo."
    exit 1
fi

# ---- 2. Status do container ----
log_info "Container openclaw_core..."

STATUS=$(docker inspect --format='{{.State.Status}}' openclaw_core 2>/dev/null || echo "not_found")

case "$STATUS" in
    running)
        log_ok "Status: rodando"
        ;;
    exited)
        EXIT_CODE=$(docker inspect --format='{{.State.ExitCode}}' openclaw_core 2>/dev/null || echo "?")
        log_fail "Status: parado (exit code: ${EXIT_CODE})"
        ;;
    not_found)
        log_fail "Container nao encontrado. Execute: ./scripts/start.sh ${ENV}"
        exit 0
        ;;
    *)
        log_warn "Status: ${STATUS}"
        ;;
esac

# ---- 3. Informacoes do container ----
if [ "$STATUS" = "running" ]; then
    echo ""
    log_info "Detalhes do container:"

    # Uptime
    STARTED=$(docker inspect --format='{{.State.StartedAt}}' openclaw_core 2>/dev/null | cut -d'.' -f1)
    echo "         Iniciado em: ${STARTED}"

    # Usuario
    CONTAINER_USER=$(docker exec openclaw_core whoami 2>/dev/null || echo "desconhecido")
    echo "         Usuario:     ${CONTAINER_USER}"
    if [ "$CONTAINER_USER" = "root" ] && [ "$ENV" = "prod" ]; then
        log_warn "Rodando como ROOT em producao!"
    fi

    # Memoria
    MEM_USAGE=$(docker stats --no-stream --format "{{.MemUsage}}" openclaw_core 2>/dev/null || echo "N/A")
    echo "         Memoria:     ${MEM_USAGE}"

    # CPU
    CPU_USAGE=$(docker stats --no-stream --format "{{.CPUPerc}}" openclaw_core 2>/dev/null || echo "N/A")
    echo "         CPU:         ${CPU_USAGE}"

    # ---- 4. Healthcheck ----
    echo ""
    log_info "Healthcheck..."
    HEALTH=$(docker inspect --format='{{.State.Health.Status}}' openclaw_core 2>/dev/null || echo "sem_healthcheck")
    case "$HEALTH" in
        healthy)   log_ok "Healthcheck: saudavel" ;;
        unhealthy) log_fail "Healthcheck: nao saudavel" ;;
        starting)  log_warn "Healthcheck: inicializando..." ;;
        *)         log_info "Healthcheck: ${HEALTH}" ;;
    esac

    # HTTP check
    if command -v curl &>/dev/null; then
        HTTP_CODE=$(curl -sf -o /dev/null -w "%{http_code}" "http://127.0.0.1:${PORTA}/" 2>/dev/null || echo "000")
        echo "         HTTP Gateway: ${HTTP_CODE}"
    fi

    # ---- 5. Verificacoes de seguranca ----
    echo ""
    log_info "Verificacoes de seguranca..."

    # Read-only filesystem
    RO_TEST=$(docker exec openclaw_core sh -c "touch /test_ro 2>&1" 2>/dev/null || echo "read-only")
    if echo "$RO_TEST" | grep -qi "read-only\|permission denied\|cannot touch"; then
        log_ok "Filesystem: somente leitura"
    else
        docker exec openclaw_core rm -f /test_ro 2>/dev/null || true
        if [ "$ENV" = "prod" ]; then
            log_warn "Filesystem: gravavel (esperado somente-leitura em producao)"
        else
            log_ok "Filesystem: gravavel (aceitavel em dev)"
        fi
    fi

    # Capabilities
    CAP_EFF=$(docker exec openclaw_core sh -c "cat /proc/1/status 2>/dev/null | grep CapEff" 2>/dev/null || echo "N/A")
    echo "         ${CAP_EFF}"

    # Network
    NETWORK=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.NetworkID}}{{end}}' openclaw_core 2>/dev/null || echo "N/A")
    echo "         Rede: ${NETWORK:0:12}..."

    # Portas
    PORTS=$(docker inspect --format='{{range $p, $conf := .NetworkSettings.Ports}}{{$p}} -> {{(index $conf 0).HostIp}}:{{(index $conf 0).HostPort}} {{end}}' openclaw_core 2>/dev/null || echo "N/A")
    echo "         Portas: ${PORTS}"
fi

# ---- 6. Watchtower ----
echo ""
log_info "Watchtower..."
WT_STATUS=$(docker inspect --format='{{.State.Status}}' openclaw_watchtower 2>/dev/null || echo "not_found")
case "$WT_STATUS" in
    running)
        log_ok "Watchtower: rodando"
        WT_STARTED=$(docker inspect --format='{{.State.StartedAt}}' openclaw_watchtower 2>/dev/null | cut -d'.' -f1)
        echo "         Iniciado em: ${WT_STARTED}"
        ;;
    not_found)
        log_info "Watchtower: nao ativo (inicie com --with-watchtower)"
        ;;
    *)
        log_warn "Watchtower: ${WT_STATUS}"
        ;;
esac

# ---- 7. Espaco em disco ----
echo ""
log_info "Espaco em disco (volumes):"
DATA_DIR="${PROJECT_ROOT}/${ENV}/data"
if [ -d "$DATA_DIR" ]; then
    DATA_SIZE=$(du -sh "$DATA_DIR" 2>/dev/null | cut -f1)
    echo "         data/:   ${DATA_SIZE}"
else
    echo "         data/:   (nao existe)"
fi

echo ""
echo "============================================"
echo "  Verificacao concluida."
echo "============================================"
echo ""
