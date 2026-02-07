# Scripts Operacionais

Todos os scripts estao em `scripts/` e aceitam o ambiente como primeiro
argumento: `dev` ou `prod` (padrao: `prod`).

## start.sh — Iniciar e validar

Inicia o OpenClaw com validacao completa de pre-requisitos.

```bash
# Iniciar em producao (padrao)
./scripts/start.sh prod

# Iniciar em desenvolvimento
./scripts/start.sh dev

# Iniciar com Watchtower (auto-update)
./scripts/start.sh prod --with-watchtower
./scripts/start.sh dev --with-watchtower
```

### O que o script valida antes de iniciar

1. Docker instalado e daemon rodando
2. Docker Compose disponivel
3. Arquivo `docker-compose.yml` base existe
4. Arquivo compose do ambiente existe
5. Arquivo compose do watchtower existe (se `--with-watchtower`)
6. Arquivo `.env` existe e nao contem placeholders
7. Permissoes do `.env` (corrige para 600 em producao)
8. Diretorios `data/` e `config/` existem (cria se necessario)
9. Portas 18789 e 18790 nao estao em uso

### O que o script valida apos iniciar

1. Container esta rodando (aguarda ate 30 segundos)
2. Usuario do container (alerta se root em producao)
3. Gateway HTTP responde
4. Watchtower esta rodando (se habilitado)

## stop.sh — Parar containers

Para todos os containers do ambiente. Se o Watchtower estiver rodando,
ele e parado automaticamente.

```bash
# Parar producao
./scripts/stop.sh prod

# Parar desenvolvimento
./scripts/stop.sh dev

# Parar e remover volumes anonimos
./scripts/stop.sh prod --remove
```

**Nota:** O flag `--remove` remove apenas volumes anonimos do Docker, nao
apaga os dados persistentes em `data/`.

## status.sh — Verificar status

Exibe informacoes completas sobre o container e validacoes de seguranca.

```bash
# Status de producao
./scripts/status.sh prod

# Status de desenvolvimento
./scripts/status.sh dev
```

### Informacoes exibidas

- Status do Docker daemon
- Estado do container (rodando, parado, nao encontrado)
- Tempo de atividade (uptime)
- Usuario do container
- Uso de memoria e CPU
- Resultado do healthcheck
- Verificacao de filesystem (somente leitura)
- Capabilities ativas
- Portas mapeadas
- Status do Watchtower
- Espaco em disco dos volumes

## logs.sh — Visualizar logs

Exibe logs do container com opcoes de filtragem.

```bash
# Ver ultimas 100 linhas (padrao)
./scripts/logs.sh prod

# Acompanhar logs em tempo real
./scripts/logs.sh prod --follow
./scripts/logs.sh prod -f

# Ver ultimas 500 linhas
./scripts/logs.sh prod --tail 500

# Ver logs da ultima hora
./scripts/logs.sh prod --since "1h"

# Ver logs desde data especifica
./scripts/logs.sh prod --since "2025-01-15"

# Combinar opcoes
./scripts/logs.sh dev -f --tail 50
```

**Para sair do modo follow:** pressione `Ctrl+C`.

## build-push.sh — Build e push da imagem

Builda a imagem OpenClaw a partir do source oficial e faz push para o
Docker Hub (conta `iapalandi`).

```bash
# Build e push (padrao)
./scripts/build-push.sh

# Apenas build local (sem push)
./scripts/build-push.sh --no-push

# Build de uma versao/tag especifica
./scripts/build-push.sh --version v1.2.3
```

### O que o script faz

1. Verifica se o Docker esta instalado
2. Verifica se o `build/Dockerfile` existe
3. Faz `docker build` com multi-stage (builder + runtime)
4. Aplica tags `iapalandi/openclaw:latest` e `iapalandi/openclaw:<versao>`
5. Faz `docker push` para o Docker Hub (se nao `--no-push`)

Veja [doc/09-docker-hub.md](09-docker-hub.md) para mais detalhes.

## backup.sh — Backup dos dados

Cria backup compactado dos dados de producao.

```bash
# Backup para ~/openclaw_backups/ (padrao)
./scripts/backup.sh

# Backup para diretorio especifico
./scripts/backup.sh /mnt/backup/openclaw
```

### Comportamento

- Cria arquivo `.tar.gz` com timestamp no nome
- Copia `data/` e `config/` de producao
- Mantem automaticamente os 5 backups mais recentes (remove antigos)
- Exibe tamanho do arquivo gerado

### Restauracao de backup

```bash
# Listar backups disponiveis
ls -lh ~/openclaw_backups/

# Restaurar (extrair para a pasta de producao)
tar -xzf ~/openclaw_backups/backup_20250115_143022.tar.gz -C ~/Developer/jadsClaw/prod/
```

## Resumo de comandos rapidos

| Acao                         | Comando                                       |
|------------------------------|-----------------------------------------------|
| Iniciar producao             | `./scripts/start.sh prod`                     |
| Iniciar dev                  | `./scripts/start.sh dev`                      |
| Iniciar com Watchtower       | `./scripts/start.sh prod --with-watchtower`   |
| Parar producao               | `./scripts/stop.sh prod`                      |
| Parar dev                    | `./scripts/stop.sh dev`                       |
| Status producao              | `./scripts/status.sh prod`                    |
| Logs em tempo real           | `./scripts/logs.sh prod -f`                   |
| Build local                  | `./scripts/build-push.sh --no-push`           |
| Build + push Docker Hub      | `./scripts/build-push.sh`                     |
| Backup                       | `./scripts/backup.sh`                         |
