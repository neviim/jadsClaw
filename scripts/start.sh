#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# start.sh — Inicializa o OpenClawD e valida todos os pre-requisitos
# Uso: ./scripts/start.sh [dev|prod] [--with-watchtower]
# =============================================================================

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV="${1:-prod}"
WITH_WATCHTOWER=false

# Processar argumentos
shift 2>/dev/null || true
while [[ $# -gt 0 ]]; do
    case $1 in
        --with-watchtower)
            WITH_WATCHTOWER=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

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
echo "  OpenClawD — Inicializacao (${ENV})"
echo "============================================"
echo ""

# ---- 1. Verificar Docker ----
log_info "Verificando pre-requisitos..."

if ! command -v docker &>/dev/null; then
    log_fail "Docker nao esta instalado."
    exit 1
fi
log_ok "Docker instalado: $(docker --version | head -1)"

if ! docker info &>/dev/null; then
    log_fail "Docker daemon nao esta rodando ou sem permissao. Tente: sudo systemctl start docker"
    exit 1
fi
log_ok "Docker daemon ativo."

if ! command -v docker-compose &>/dev/null && ! docker compose version &>/dev/null 2>&1; then
    log_fail "Docker Compose nao encontrado."
    exit 1
fi
log_ok "Docker Compose disponivel."

# ---- 2. Verificar estrutura de arquivos ----
log_info "Verificando estrutura do projeto..."

if [ "$ENV" = "dev" ]; then
    ENV_DIR="${PROJECT_ROOT}/dev"
    COMPOSE_CMD="docker compose --project-directory ${ENV_DIR} -f ${PROJECT_ROOT}/base/docker-compose.yml -f ${ENV_DIR}/docker-compose.override.yml"
elif [ "$ENV" = "prod" ]; then
    ENV_DIR="${PROJECT_ROOT}/prod"
    COMPOSE_CMD="docker compose --project-directory ${ENV_DIR} -f ${PROJECT_ROOT}/base/docker-compose.yml -f ${ENV_DIR}/docker-compose.prod.yml"
else
    log_fail "Ambiente invalido: '${ENV}'. Use 'dev' ou 'prod'."
    exit 1
fi

# Ler porta do .env (ou usar default)
PORTA=$(grep -s '^OPENCLAW_PORT=' "${ENV_DIR}/.env" 2>/dev/null | cut -d'=' -f2)
PORTA="${PORTA:-18789}"

# Adicionar watchtower se solicitado
if [ "$WITH_WATCHTOWER" = true ]; then
    WATCHTOWER_FILE="${PROJECT_ROOT}/docker-compose.watchtower.yml"
    if [ ! -f "$WATCHTOWER_FILE" ]; then
        log_fail "Arquivo docker-compose.watchtower.yml nao encontrado."
        ERRORS=$((ERRORS + 1))
    else
        COMPOSE_CMD="${COMPOSE_CMD} -f ${WATCHTOWER_FILE}"
        log_ok "Watchtower habilitado."
    fi
fi

# Verificar arquivo base
if [ ! -f "${PROJECT_ROOT}/base/docker-compose.yml" ]; then
    log_fail "Arquivo base/docker-compose.yml nao encontrado."
    ERRORS=$((ERRORS + 1))
else
    log_ok "base/docker-compose.yml encontrado."
fi

# Verificar compose do ambiente
COMPOSE_FILE="${ENV_DIR}/docker-compose.override.yml"
[ "$ENV" = "prod" ] && COMPOSE_FILE="${ENV_DIR}/docker-compose.prod.yml"

if [ ! -f "$COMPOSE_FILE" ]; then
    log_fail "Arquivo compose do ambiente ${ENV} nao encontrado: ${COMPOSE_FILE}"
    ERRORS=$((ERRORS + 1))
else
    log_ok "Compose do ambiente ${ENV} encontrado."
fi

# Verificar .env
if [ ! -f "${ENV_DIR}/.env" ]; then
    log_fail "Arquivo .env nao encontrado em ${ENV_DIR}/. Copie o .env.example e preencha suas chaves."
    ERRORS=$((ERRORS + 1))
else
    log_ok "Arquivo .env encontrado."

    # Verificar permissoes do .env em producao
    if [ "$ENV" = "prod" ]; then
        PERMS=$(stat -c "%a" "${ENV_DIR}/.env" 2>/dev/null || echo "???")
        if [ "$PERMS" != "600" ]; then
            log_warn ".env de producao com permissoes ${PERMS}. Corrigindo para 600..."
            chmod 600 "${ENV_DIR}/.env"
            log_ok "Permissoes corrigidas para 600."
        else
            log_ok "Permissoes do .env corretas (600)."
        fi
    fi

    # Verificar se chaves minimas estao definidas
    if grep -q "sua_chave\|SEU_TOKEN\|CHANGE_ME\|seu_token" "${ENV_DIR}/.env" 2>/dev/null; then
        log_warn "O .env contem valores placeholder. Substitua pelas suas chaves reais."
    fi
fi

# Verificar diretorios de dados
for DIR in "${ENV_DIR}/data" "${ENV_DIR}/config"; do
    if [ ! -d "$DIR" ]; then
        log_warn "Diretorio ${DIR} nao existe. Criando..."
        mkdir -p "$DIR"
        log_ok "Diretorio criado: ${DIR}"
    else
        log_ok "Diretorio existe: ${DIR}"
    fi
done

# ---- 3. Verificar portas disponiveis ----
for CHECK_PORT in ${PORTA}; do
    if ss -tlnp 2>/dev/null | grep -q ":${CHECK_PORT} " || netstat -tlnp 2>/dev/null | grep -q ":${CHECK_PORT} "; then
        log_warn "Porta ${CHECK_PORT} ja esta em uso. O container pode falhar ao iniciar."
    fi
done

# ---- 4. Abortar se houve erros criticos ----
if [ "$ERRORS" -gt 0 ]; then
    echo ""
    log_fail "Encontrados ${ERRORS} erro(s) critico(s). Corrija antes de continuar."
    exit 1
fi

# ---- 5. Subir os containers ----
echo ""
log_info "Iniciando OpenClawD em modo ${ENV}..."
echo ""

cd "${ENV_DIR}"
${COMPOSE_CMD} up -d

echo ""
log_info "Aguardando container ficar pronto (max 30s)..."

TRIES=0
MAX_TRIES=15
while [ $TRIES -lt $MAX_TRIES ]; do
    STATUS=$(docker inspect --format='{{.State.Status}}' openclaw_core 2>/dev/null || echo "not_found")
    if [ "$STATUS" = "running" ]; then
        log_ok "Container openclaw_core esta rodando."
        break
    fi
    TRIES=$((TRIES + 1))
    sleep 2
done

if [ "$STATUS" != "running" ]; then
    log_fail "Container nao iniciou em 30 segundos. Verifique os logs: ./scripts/logs.sh ${ENV}"
    exit 1
fi

# ---- 6. Validacoes pos-inicializacao ----
echo ""
log_info "Executando validacoes de seguranca..."

# Verificar se nao esta rodando como root
CONTAINER_USER=$(docker exec openclaw_core whoami 2>/dev/null || echo "desconhecido")
if [ "$CONTAINER_USER" = "root" ] && [ "$ENV" = "prod" ]; then
    log_warn "Container esta rodando como ROOT em producao!"
else
    log_ok "Usuario do container: ${CONTAINER_USER}"
fi

# Verificar conectividade
if command -v curl &>/dev/null; then
    HTTP_CODE=$(curl -sf -o /dev/null -w "%{http_code}" "http://127.0.0.1:${PORTA}/" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ]; then
        log_ok "Gateway respondendo (HTTP ${HTTP_CODE})."
    else
        log_warn "Gateway retornou HTTP ${HTTP_CODE}. O servico pode ainda estar inicializando."
    fi
fi

# Verificar watchtower se habilitado
if [ "$WITH_WATCHTOWER" = true ]; then
    WT_STATUS=$(docker inspect --format='{{.State.Status}}' openclaw_watchtower 2>/dev/null || echo "not_found")
    if [ "$WT_STATUS" = "running" ]; then
        log_ok "Watchtower esta rodando."
    else
        log_warn "Watchtower nao iniciou (status: ${WT_STATUS})."
    fi
fi

# ---- 7. Resumo ----
echo ""
echo "============================================"
echo -e "  ${GREEN}OpenClawD iniciado com sucesso!${NC}"
echo "============================================"
echo ""
echo "  Ambiente:  ${ENV}"
echo "  Gateway:   http://127.0.0.1:${PORTA}"
echo "  Container: openclaw_core"
if [ "$WITH_WATCHTOWER" = true ]; then
echo "  Watchtower: ativo (atualizacoes diarias as 4h)"
fi
echo ""
echo "  Comandos uteis:"
echo "    ./scripts/status.sh ${ENV}    — Verificar status"
echo "    ./scripts/logs.sh ${ENV}      — Ver logs"
echo "    ./scripts/stop.sh ${ENV}      — Parar tudo"
echo ""
