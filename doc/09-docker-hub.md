# Docker Hub — Publicacao da Imagem

## Visao geral

A imagem `iapalandi/openclaw` e buildada a partir do source oficial do
OpenClaw (github.com/openclaw/openclaw) e publicada no Docker Hub para
distribuicao e auto-update via Watchtower.

## Pre-requisitos

### 1. Conta no Docker Hub

Crie uma conta em https://hub.docker.com se ainda nao tiver.

### 2. Login no Docker CLI

```bash
docker login
# Informe seu usuario (iapalandi) e senha/token
```

### 3. Criar o repositorio (primeira vez)

O repositorio `iapalandi/openclaw` sera criado automaticamente no primeiro
`docker push`. Opcionalmente, crie manualmente em hub.docker.com para
adicionar descricao.

## Build e push

### Usando o script (recomendado)

```bash
# Build e push da versao latest
./scripts/build-push.sh

# Apenas build local (sem push)
./scripts/build-push.sh --no-push

# Build de uma tag/branch especifica do OpenClaw
./scripts/build-push.sh --version v1.2.3
```

### Manualmente

```bash
# Build
docker build \
  -t iapalandi/openclaw:latest \
  -f build/Dockerfile \
  .

# Push
docker push iapalandi/openclaw:latest
```

## Dockerfile

O `build/Dockerfile` usa multi-stage build:

### Stage 1: Builder

- **Base:** `node:22-bookworm`
- Instala Bun e habilita pnpm via corepack
- Clona o repositorio oficial do OpenClaw
- Instala dependencias e faz build (backend + UI)

### Stage 2: Runtime

- **Base:** `node:22-bookworm-slim` (imagem menor)
- Copia apenas os artefatos de build necessarios
- Instala curl para healthcheck
- Roda como usuario `node` (uid 1000, non-root)
- Expoe portas 18789 (Gateway/UI) e 18790 (Bridge)
- Inclui healthcheck integrado

## Tags

| Tag        | Descricao                                      |
|------------|-------------------------------------------------|
| `latest`   | Versao mais recente (branch main do OpenClaw)  |
| `v1.2.3`   | Versao especifica (tag do OpenClaw)            |

## Fluxo de atualizacao

```
1. Nova versao do OpenClaw no GitHub
          │
          ▼
2. ./scripts/build-push.sh
   (build local + push para Docker Hub)
          │
          ▼
3. Watchtower detecta nova imagem (diario, 4h)
          │
          ▼
4. Watchtower atualiza o container automaticamente
```

### Passo a passo manual

```bash
# 1. Build e push da nova versao
./scripts/build-push.sh

# 2. Se o Watchtower esta ativo, ele atualiza sozinho
# 3. Para forcar a atualizacao agora:
docker exec openclaw_watchtower /watchtower --run-once

# 4. Ou fazer manualmente:
./scripts/stop.sh prod
docker pull iapalandi/openclaw:latest
./scripts/start.sh prod
```

## Seguranca da imagem

A imagem publicada inclui:

- **Non-root:** Roda como usuario `node` (uid 1000)
- **Healthcheck:** Verifica porta 18789 a cada 30s
- **Labels:** Maintainer e Watchtower enable
- **Slim runtime:** Imagem de runtime minima (bookworm-slim)
- **Multi-stage:** Ferramentas de build nao estao na imagem final

## Troubleshooting

### Erro de autenticacao no push

```bash
# Verificar login
docker info | grep Username

# Refazer login
docker login
```

### Build falha

```bash
# Verificar se o Dockerfile existe
ls -la build/Dockerfile

# Build com output detalhado
docker build --progress=plain \
  -t iapalandi/openclaw:latest \
  -f build/Dockerfile .
```

### Imagem muito grande

A imagem usa multi-stage build para reduzir o tamanho. O stage de builder
(com Bun, pnpm, source completo) nao entra na imagem final.

```bash
# Verificar tamanho
docker images iapalandi/openclaw
```
