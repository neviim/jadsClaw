#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# start.sh — Inicializa o OpenClawD e valida todos os pré-requisitos
# Uso: ./scripts/start.sh [dev|prod]
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

ERRORS=0

echo ""
echo "============================================"
echo "  OpenClawD — Inicialização (${ENV})"
echo "============================================"
echo ""

# ---- 1. Verificar Docker ----
log_info "Verificando pré-requisitos..."

if ! command -v docker &>/dev/null; then
    log_fail "Docker não está instalado."
    exit 1
fi
log_ok "Docker instalado: $(docker --version | head -1)"

if ! docker info &>/dev/null; then
    log_fail "Docker daemon não está rodando ou sem permissão. Tente: sudo systemctl start docker"
    exit 1
fi
log_ok "Docker daemon ativo."

if ! command -v docker-compose &>/dev/null && ! docker compose version &>/dev/null 2>&1; then
    log_fail "Docker Compose não encontrado."
    exit 1
fi
log_ok "Docker Compose disponível."

# ---- 2. Verificar estrutura de arquivos ----
log_info "Verificando estrutura do projeto..."

if [ "$ENV" = "dev" ]; then
    ENV_DIR="${PROJECT_ROOT}/dev"
    COMPOSE_CMD="docker compose -f ${PROJECT_ROOT}/base/docker-compose.yml -f ${ENV_DIR}/docker-compose.override.yml"
    PORTA="8080"
elif [ "$ENV" = "prod" ]; then
    ENV_DIR="${PROJECT_ROOT}/prod"
    COMPOSE_CMD="docker compose -f ${PROJECT_ROOT}/base/docker-compose.yml -f ${ENV_DIR}/docker-compose.prod.yml"
    PORTA="8000"
else
    log_fail "Ambiente inválido: '${ENV}'. Use 'dev' ou 'prod'."
    exit 1
fi

# Verificar arquivo base
if [ ! -f "${PROJECT_ROOT}/base/docker-compose.yml" ]; then
    log_fail "Arquivo base/docker-compose.yml não encontrado."
    ERRORS=$((ERRORS + 1))
else
    log_ok "base/docker-compose.yml encontrado."
fi

# Verificar compose do ambiente
COMPOSE_FILE="${ENV_DIR}/docker-compose.override.yml"
[ "$ENV" = "prod" ] && COMPOSE_FILE="${ENV_DIR}/docker-compose.prod.yml"

if [ ! -f "$COMPOSE_FILE" ]; then
    log_fail "Arquivo compose do ambiente ${ENV} não encontrado: ${COMPOSE_FILE}"
    ERRORS=$((ERRORS + 1))
else
    log_ok "Compose do ambiente ${ENV} encontrado."
fi

# Verificar .env
if [ ! -f "${ENV_DIR}/.env" ]; then
    log_fail "Arquivo .env não encontrado em ${ENV_DIR}/. Copie o .env.example e preencha suas chaves."
    ERRORS=$((ERRORS + 1))
else
    log_ok "Arquivo .env encontrado."

    # Verificar permissões do .env em produção
    if [ "$ENV" = "prod" ]; then
        PERMS=$(stat -c "%a" "${ENV_DIR}/.env" 2>/dev/null || echo "???")
        if [ "$PERMS" != "600" ]; then
            log_warn ".env de produção com permissões ${PERMS}. Corrigindo para 600..."
            chmod 600 "${ENV_DIR}/.env"
            log_ok "Permissões corrigidas para 600."
        else
            log_ok "Permissões do .env corretas (600)."
        fi
    fi

    # Verificar se chaves mínimas estão definidas
    if grep -q "sua_chave\|SEU_TOKEN\|CHANGE_ME" "${ENV_DIR}/.env" 2>/dev/null; then
        log_warn "O .env contém valores placeholder. Substitua pelas suas chaves reais."
    fi
fi

# Verificar diretórios de dados
for DIR in "${ENV_DIR}/data" "${ENV_DIR}/config"; do
    if [ ! -d "$DIR" ]; then
        log_warn "Diretório ${DIR} não existe. Criando..."
        mkdir -p "$DIR"
        log_ok "Diretório criado: ${DIR}"
    else
        log_ok "Diretório existe: ${DIR}"
    fi
done

# ---- 3. Verificar porta disponível ----
if ss -tlnp 2>/dev/null | grep -q ":${PORTA} " || netstat -tlnp 2>/dev/null | grep -q ":${PORTA} "; then
    log_warn "Porta ${PORTA} já está em uso. O container pode falhar ao iniciar."
fi

# ---- 4. Abortar se houve erros críticos ----
if [ "$ERRORS" -gt 0 ]; then
    echo ""
    log_fail "Encontrados ${ERRORS} erro(s) crítico(s). Corrija antes de continuar."
    exit 1
fi

# ---- 5. Subir os containers ----
echo ""
log_info "Iniciando OpenClawD em modo ${ENV}..."
echo ""

cd "${ENV_DIR}"
${COMPOSE_CMD} up -d

echo ""
log_info "Aguardando container ficar pronto (máx 30s)..."

TRIES=0
MAX_TRIES=15
while [ $TRIES -lt $MAX_TRIES ]; do
    STATUS=$(docker inspect --format='{{.State.Status}}' openclaw_core 2>/dev/null || echo "not_found")
    if [ "$STATUS" = "running" ]; then
        log_ok "Container openclaw_core está rodando."
        break
    fi
    TRIES=$((TRIES + 1))
    sleep 2
done

if [ "$STATUS" != "running" ]; then
    log_fail "Container não iniciou em 30 segundos. Verifique os logs: ./scripts/logs.sh ${ENV}"
    exit 1
fi

# ---- 6. Validações pós-inicialização ----
echo ""
log_info "Executando validações de segurança..."

# Verificar se não está rodando como root
CONTAINER_USER=$(docker exec openclaw_core whoami 2>/dev/null || echo "desconhecido")
if [ "$CONTAINER_USER" = "root" ] && [ "$ENV" = "prod" ]; then
    log_warn "Container está rodando como ROOT em produção!"
else
    log_ok "Usuário do container: ${CONTAINER_USER}"
fi

# Verificar conectividade
if command -v curl &>/dev/null; then
    HTTP_CODE=$(curl -sf -o /dev/null -w "%{http_code}" "http://127.0.0.1:${PORTA}/health" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ]; then
        log_ok "Healthcheck respondendo (HTTP ${HTTP_CODE})."
    else
        log_warn "Healthcheck retornou HTTP ${HTTP_CODE}. O serviço pode ainda estar inicializando."
    fi
fi

# ---- 7. Resumo ----
echo ""
echo "============================================"
echo -e "  ${GREEN}OpenClawD iniciado com sucesso!${NC}"
echo "============================================"
echo ""
echo "  Ambiente:  ${ENV}"
echo "  Acesso:    http://127.0.0.1:${PORTA}"
echo "  Container: openclaw_core"
echo ""
echo "  Comandos úteis:"
echo "    ./scripts/status.sh ${ENV}    — Verificar status"
echo "    ./scripts/logs.sh ${ENV}      — Ver logs"
echo "    ./scripts/stop.sh ${ENV}      — Parar tudo"
echo ""
