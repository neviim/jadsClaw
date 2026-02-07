#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# backup.sh — Cria backup dos dados de produção do OpenClawD
# Uso: ./scripts/backup.sh [destino]
# Destino padrão: ~/openclaw_backups/
# =============================================================================

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BACKUP_BASE="${1:-$HOME/openclaw_backups}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="${BACKUP_BASE}/backup_${TIMESTAMP}"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

log_ok()   { echo -e "${GREEN}[OK]${NC}    $1"; }
log_fail() { echo -e "${RED}[FALHA]${NC} $1"; }
log_info() { echo -e "${CYAN}[INFO]${NC}  $1"; }

echo ""
echo "============================================"
echo "  OpenClawD — Backup"
echo "============================================"
echo ""

# Verificar se existem dados para backup
PROD_DATA="${PROJECT_ROOT}/prod/data"
PROD_CONFIG="${PROJECT_ROOT}/prod/config"

if [ ! -d "$PROD_DATA" ] && [ ! -d "$PROD_CONFIG" ]; then
    log_fail "Nenhum diretório de dados encontrado para backup."
    exit 1
fi

# Criar diretório de backup
mkdir -p "$BACKUP_DIR"
log_info "Diretório de backup: ${BACKUP_DIR}"

# Copiar dados
if [ -d "$PROD_DATA" ]; then
    cp -a "$PROD_DATA" "${BACKUP_DIR}/data"
    log_ok "Dados copiados: data/"
fi

if [ -d "$PROD_CONFIG" ]; then
    cp -a "$PROD_CONFIG" "${BACKUP_DIR}/config"
    log_ok "Configurações copiadas: config/"
fi

# Criar arquivo compactado
ARCHIVE="${BACKUP_BASE}/backup_${TIMESTAMP}.tar.gz"
tar -czf "$ARCHIVE" -C "$BACKUP_BASE" "backup_${TIMESTAMP}"
rm -rf "$BACKUP_DIR"
log_ok "Arquivo compactado: ${ARCHIVE}"

# Informar tamanho
SIZE=$(du -sh "$ARCHIVE" | cut -f1)
log_info "Tamanho do backup: ${SIZE}"

# Limpar backups antigos (manter últimos 5)
BACKUP_COUNT=$(ls -1 "${BACKUP_BASE}"/backup_*.tar.gz 2>/dev/null | wc -l)
if [ "$BACKUP_COUNT" -gt 5 ]; then
    REMOVE_COUNT=$((BACKUP_COUNT - 5))
    ls -1t "${BACKUP_BASE}"/backup_*.tar.gz | tail -n "$REMOVE_COUNT" | xargs rm -f
    log_info "Removidos ${REMOVE_COUNT} backup(s) antigo(s). Mantendo os 5 mais recentes."
fi

echo ""
echo "============================================"
echo -e "  ${GREEN}Backup concluído!${NC}"
echo "============================================"
echo "  Arquivo: ${ARCHIVE}"
echo "  Para restaurar: tar -xzf ${ARCHIVE} -C ${PROJECT_ROOT}/prod/"
echo ""
