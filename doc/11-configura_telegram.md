# Configuracao do Canal Telegram no OpenClaw

## Pre-requisitos

- Container OpenClaw rodando (`openclaw_core`)
- Bot criado no Telegram via [@BotFather](https://t.me/BotFather)
- Token do bot (formato: `123456789:AAxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`)
- Seu Telegram User ID (numero inteiro, ex: `107808508`)

### Como obter o User ID

Envie uma mensagem ao seu bot e execute:

```bash
curl https://api.telegram.org/bot<SEU_TOKEN>/getUpdates
```

O campo `from.id` na resposta e o seu User ID.

---

## Passo 1 — Corrigir o Dockerfile

O Dockerfile original nao copiava o diretorio `extensions/` para o runtime stage.
Sem este diretorio, o plugin discovery do OpenClaw nao encontra os channel plugins
(Telegram, Discord, WhatsApp, etc.), pois eles sao carregados em runtime via `jiti`.

Adicionar ao `build/Dockerfile`, na secao de COPY do runtime stage:

```dockerfile
# Channel plugins (telegram, discord, whatsapp, etc.)
# Carregados em runtime via jiti (TS transpiler) pelo plugin discovery system
COPY --from=builder /build/extensions ./extensions
```

Depois de alterar, rebuildar a imagem:

```bash
./scripts/build-push.sh --no-push
```

E recriar o container:

```bash
docker compose --project-directory dev \
  -f base/docker-compose.yml \
  -f dev/docker-compose.override.yml \
  up -d --force-recreate
```

## Passo 2 — Variavel de ambiente do Bot Token

No ficheiro `dev/.env`, a variavel deve ser `TELEGRAM_BOT_TOKEN` (nao `TELEGRAM_TOKEN`):

```env
TELEGRAM_BOT_TOKEN=123456789:AAxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

## Passo 3 — Configuracao do OpenClaw (`openclaw.json`)

O ficheiro de configuracao fica em `dev/data/openclaw.json` (montado no container como
`/home/node/.openclaw/openclaw.json`).

Configuracao minima para Telegram com allowlist:

```json
{
  "channels": {
    "telegram": {
      "enabled": true,
      "dmPolicy": "allowlist",
      "allowFrom": [107808508],
      "groupPolicy": "allowlist",
      "streamMode": "partial",
      "actions": {
        "sendMessage": true
      }
    }
  },
  "plugins": {
    "slots": {
      "memory": "none"
    },
    "entries": {
      "telegram": {
        "enabled": true
      }
    }
  }
}
```

### Campos importantes

| Campo | Descricao |
|-------|-----------|
| `channels.telegram.enabled` | Ativa o canal Telegram |
| `channels.telegram.dmPolicy` | `"allowlist"` = so responde a IDs listados; `"pairing"` = aprovacao manual |
| `channels.telegram.allowFrom` | Array de User IDs autorizados a enviar DMs |
| `channels.telegram.groupPolicy` | Politica para grupos (`"allowlist"`, `"open"`) |
| `channels.telegram.streamMode` | `"partial"` = respostas em streaming |
| `plugins.slots.memory` | `"none"` desabilita o plugin memory-core (evita erro de validacao) |
| `plugins.entries.telegram.enabled` | Habilita o plugin Telegram no sistema de plugins |

## Passo 4 — Reiniciar o container

```bash
docker compose --project-directory dev \
  -f base/docker-compose.yml \
  -f dev/docker-compose.override.yml \
  restart
```

## Passo 5 — Verificar os logs

```bash
docker logs openclaw_core --since 30s 2>&1 | grep -i telegram
```

## Passo 6 — Diagnostico

```bash
docker exec openclaw_core node dist/index.js doctor
```

---

## Resolucao de problemas

### `plugin not found: memory-core`

Adicionar ao `openclaw.json`:

```json
"plugins": { "slots": { "memory": "none" } }
```

### `plugin not found: telegram`

O diretorio `extensions/` nao foi copiado para a imagem Docker.
Corrigir o Dockerfile (Passo 1) e rebuildar.

### `password_missing`

Inserir a senha do gateway (`OPENCLAW_GATEWAY_PASSWORD`) nas Settings da Control UI
no navegador.

### `pairing required`

Listar e aprovar dispositivos:

```bash
docker exec openclaw_core node dist/index.js devices list
docker exec openclaw_core node dist/index.js devices approve <requestId>
```

---

## Resumo de comandos

```bash
# 1. Corrigir env var no dev/.env
#    Renomear TELEGRAM_TOKEN para TELEGRAM_BOT_TOKEN

# 2. Rebuildar a imagem (apos corrigir Dockerfile com extensions/)
./scripts/build-push.sh --no-push

# 3. Recriar o container com a nova imagem
docker compose --project-directory dev \
  -f base/docker-compose.yml \
  -f dev/docker-compose.override.yml \
  up -d --force-recreate

# 4. Verificar logs do Telegram
docker logs openclaw_core --since 30s 2>&1 | grep -i telegram

# 5. Rodar diagnostico
docker exec openclaw_core node dist/index.js doctor

# 6. Listar dispositivos pendentes (se necessario)
docker exec openclaw_core node dist/index.js devices list

# 7. Aprovar dispositivo (se necessario)
docker exec openclaw_core node dist/index.js devices approve <requestId>

# 8. Reiniciar container (apos mudancas no openclaw.json ou .env)
docker compose --project-directory dev \
  -f base/docker-compose.yml \
  -f dev/docker-compose.override.yml \
  restart
```
