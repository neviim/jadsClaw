#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# build-push.sh — Build e push da imagem OpenClaw para Docker Hub
# Uso: ./scripts/build-push.sh [--no-push] [--version TAG]
# =============================================================================

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_ok()   { echo -e "${GREEN}[OK]${NC}    $1"; }
log_fail() { echo -e "${RED}[FALHA]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[AVISO]${NC} $1"; }
log_info() { echo -e "${CYAN}[INFO]${NC}  $1"; }

IMAGE_NAME="iapalandi/openclaw"
IMAGE_TAG="latest"
DO_PUSH=true
OPENCLAW_VERSION="main"

# Processar argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        --no-push)
            DO_PUSH=false
            shift
            ;;
        --version)
            OPENCLAW_VERSION="$2"
            IMAGE_TAG="$2"
            shift 2
            ;;
        *)
            echo "Uso: $0 [--no-push] [--version TAG]"
            exit 1
            ;;
    esac
done

echo ""
echo "============================================"
echo "  OpenClaw — Build & Push"
echo "============================================"
echo ""
echo "  Imagem:  ${IMAGE_NAME}:${IMAGE_TAG}"
echo "  Versao:  ${OPENCLAW_VERSION}"
echo "  Push:    ${DO_PUSH}"
echo ""

# ---- 1. Verificar Docker ----
if ! command -v docker &>/dev/null; then
    log_fail "Docker nao esta instalado."
    exit 1
fi
log_ok "Docker instalado."

# ---- 2. Verificar Dockerfile ----
DOCKERFILE="${PROJECT_ROOT}/build/Dockerfile"
if [ ! -f "$DOCKERFILE" ]; then
    log_fail "Dockerfile nao encontrado: ${DOCKERFILE}"
    exit 1
fi
log_ok "Dockerfile encontrado."

# ---- 3. Build da imagem ----
log_info "Iniciando build da imagem (pode levar alguns minutos)..."
echo ""

docker build \
    --build-arg "OPENCLAW_VERSION=${OPENCLAW_VERSION}" \
    -t "${IMAGE_NAME}:${IMAGE_TAG}" \
    -t "${IMAGE_NAME}:latest" \
    -f "$DOCKERFILE" \
    "${PROJECT_ROOT}"

echo ""
log_ok "Build concluido: ${IMAGE_NAME}:${IMAGE_TAG}"

# Mostrar tamanho da imagem
IMAGE_SIZE=$(docker images --format "{{.Size}}" "${IMAGE_NAME}:${IMAGE_TAG}" 2>/dev/null || echo "N/A")
log_info "Tamanho da imagem: ${IMAGE_SIZE}"

# ---- 4. Push para Docker Hub ----
if [ "$DO_PUSH" = true ]; then
    # Verificar autenticacao
    if ! docker info 2>/dev/null | grep -q "Username"; then
        log_warn "Voce pode nao estar autenticado no Docker Hub."
        log_info "Execute: docker login"
    fi

    log_info "Enviando imagem para Docker Hub..."
    docker push "${IMAGE_NAME}:${IMAGE_TAG}"

    if [ "$IMAGE_TAG" != "latest" ]; then
        docker push "${IMAGE_NAME}:latest"
    fi

    log_ok "Push concluido: ${IMAGE_NAME}:${IMAGE_TAG}"
else
    log_info "Push ignorado (--no-push)."
fi

echo ""
echo "============================================"
echo -e "  ${GREEN}Build & Push concluido!${NC}"
echo "============================================"
echo ""
echo "  Para usar a imagem localmente:"
echo "    ./scripts/start.sh dev"
echo ""
echo "  Para verificar no Docker Hub:"
echo "    https://hub.docker.com/r/${IMAGE_NAME}"
echo ""
