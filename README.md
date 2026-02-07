# jadsClaw

A secure and isolated Docker environment for running **OpenClaw** on Linux Mint 22,
following the **Principle of Least Privilege**.

The project separates development and production environments with full hardening
to protect API keys, credentials and host machine data.
The image is built from the official source and published to Docker Hub
as `iapalandi/openclaw`. Watchtower monitors for updates automatically.

## Quick start

### 1. Get the image

```bash
# Option A — pull from Docker Hub
docker pull iapalandi/openclaw:latest

# Option B — local build
./scripts/build-push.sh --no-push
```

### 2. Set up environment variables

```bash
# Development
cp dev/.env.example dev/.env
nano dev/.env

# Production
cp prod/.env.example prod/.env
chmod 600 prod/.env
nano prod/.env
```

### 3. Start

**Development:**

```bash
./scripts/start.sh dev
```

**Production:**

```bash
./scripts/start.sh prod
```

**Production with auto-update (Watchtower):**

```bash
./scripts/start.sh prod --with-watchtower
```

Access the gateway at **http://127.0.0.1:18789**

## Useful commands

| Action                  | Command                                     |
|-------------------------|---------------------------------------------|
| Start dev               | `./scripts/start.sh dev`                    |
| Start prod              | `./scripts/start.sh prod`                   |
| Start with Watchtower   | `./scripts/start.sh prod --with-watchtower` |
| Stop                    | `./scripts/stop.sh dev` / `stop.sh prod`    |
| Status                  | `./scripts/status.sh dev` / `status.sh prod`|
| Live logs               | `./scripts/logs.sh dev -f`                  |
| Build + push Docker Hub | `./scripts/build-push.sh`                   |
| Backup (production)     | `./scripts/backup.sh`                       |

## Ports

| Service      | Port  | Address                  |
|--------------|-------|--------------------------|
| Gateway (UI) | 18789 | http://127.0.0.1:18789   |
| Bridge       | 18790 | 127.0.0.1:18790          |

Both bound to `127.0.0.1` — local access only.

## Documentation

| # | Document | Description |
|---|----------|-------------|
| 1 | [Overview](doc/01-visao-geral.md) | Architecture, principles and project structure |
| 2 | [Installation](doc/02-instalacao.md) | Prerequisites, initial setup and first start |
| 3 | [Configuration](doc/03-configuracao.md) | Environment variables, API keys and compose files |
| 4 | [Security](doc/04-seguranca.md) | Hardening, protection layers and checklist |
| 5 | [Scripts](doc/05-scripts.md) | Detailed usage of each operational script |
| 6 | [Container access](doc/06-acesso-container.md) | Web interface, terminal, REST API and troubleshooting |
| 7 | [Best practices](doc/07-recomendacoes.md) | Recommendations, backups and incident response |
| 8 | [Watchtower](doc/08-watchtower.md) | Automatic container updates via Watchtower |
| 9 | [Docker Hub](doc/09-docker-hub.md) | Building and publishing the image to Docker Hub |
