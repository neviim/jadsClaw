# =============================================================================
# OpenClaw — Dockerfile (build from source)
# Baseado no Dockerfile oficial: github.com/openclaw/openclaw
#
# Build:
#   docker build -t iapalandi/openclaw:latest -f build/Dockerfile .
#
# O build clona o repositorio oficial e compila dentro do container.
# =============================================================================

FROM node:22-bookworm AS builder

# Instalar Bun (necessario para build scripts)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

# Habilitar corepack para pnpm
RUN corepack enable

WORKDIR /build

# Clonar o repositorio oficial do OpenClaw
ARG OPENCLAW_VERSION=main
RUN git clone --depth 1 --branch "${OPENCLAW_VERSION}" \
    https://github.com/openclaw/openclaw.git .

# Instalar dependencias
RUN pnpm install --frozen-lockfile

# Build do backend
RUN OPENCLAW_A2UI_SKIP_MISSING=1 pnpm build

# Build da UI (forcar pnpm para compatibilidade ARM/Synology)
ENV OPENCLAW_PREFER_PNPM=1
RUN pnpm ui:build

# ---- Runtime stage ----
FROM node:22-bookworm-slim AS runtime

# Instalar apenas o necessario para runtime
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copiar artefatos do build
# dist/ inclui backend (index.js) + UI (control-ui/) gerada pelo vite
COPY --from=builder /build/dist ./dist
COPY --from=builder /build/node_modules ./node_modules
COPY --from=builder /build/package.json ./package.json
# Templates necessarios para heartbeat e workspace em runtime
COPY --from=builder /build/docs ./docs

ENV NODE_ENV=production

# Criar diretorio de dados do OpenClaw para o user node
RUN mkdir -p /home/node/.openclaw && \
    chown -R node:node /home/node/.openclaw /app

# Labels para identificacao e watchtower
LABEL maintainer="iapalandi"
LABEL com.centurylinklabs.watchtower.enable="true"

# Seguranca: rodar como usuario nao-root
USER node

# Portas: 18789 (Gateway/UI) e 18790 (Bridge)
EXPOSE 18789 18790

# Healthcheck via porta do gateway
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD curl -sf http://localhost:18789/ || exit 1

# Iniciar gateway com bind em todas as interfaces (necessario dentro do container)
CMD ["node", "dist/index.js", "gateway", "--allow-unconfigured", "--bind", "lan"]
