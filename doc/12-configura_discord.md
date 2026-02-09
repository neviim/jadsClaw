# Configuracao do Canal Discord no OpenClaw

## Pre-requisitos

- Container OpenClaw rodando (`openclaw_core`)
- Bot criado no [Discord Developer Portal](https://discord.com/developers/applications)
- Token do bot
- Guild ID (Server ID) do servidor Discord
- Privileged Gateway Intents habilitados no portal

### Criar o Bot no Discord Developer Portal

1. Acede a [discord.com/developers/applications](https://discord.com/developers/applications)
2. Clica em **New Application** e da um nome (ex: `<nome_do_bot>`)
3. Vai em **Bot** e clica **Reset Token** para obter o token
4. Em **Privileged Gateway Intents**, habilita:
   - **Message Content Intent** (obrigatorio para ler mensagens)
   - **Server Members Intent** (recomendado para allowlists)

### Convidar o Bot para o Servidor

1. Vai em **OAuth2 > URL Generator**
2. Seleciona os scopes: `bot`, `applications.commands`
3. Seleciona as permissoes:
   - View Channels
   - Send Messages
   - Read Message History
   - Embed Links
   - Attach Files
   - Add Reactions
4. Copia a URL gerada e abre no navegador para adicionar o bot ao servidor

### Obter o Guild ID

1. No Discord, vai em **Settings > Advanced > Developer Mode** e ativa
2. Clica com o botao direito no servidor e seleciona **Copy Server ID**

---

## Passo 1 — Variaveis de ambiente

No ficheiro `dev/.env`, adicionar as seguintes variaveis:

```env
# --- DISCORD ---
DISCORD_ENABLED=true
DISCORD_BOT_TOKEN=<token_do_bot_discord>
DISCORD_GUILD_ID=<guild_id_do_servidor>
```

**Importante:** A variavel do token deve ser `DISCORD_BOT_TOKEN` (nao `DISCORD_TOKEN`).

## Passo 2 — Configuracao do OpenClaw (`openclaw.json`)

O ficheiro de configuracao fica em `dev/data/openclaw.json` (montado no container como
`/home/node/.openclaw/openclaw.json`).

Adicionar a secao `discord` dentro de `channels` e o plugin em `plugins.entries`.
O valor de `DISCORD_GUILD_ID` pode ser consultado no `dev/.env`:

```json
{
  "channels": {
    "discord": {
      "enabled": true,
      "dm": {
        "enabled": true,
        "policy": "pairing"
      },
      "groupPolicy": "allowlist",
      "guilds": {
        "<guild_id_do_servidor>": {
          "slug": "<nome_do_servidor>",
          "requireMention": true,
          "channels": {}
        }
      },
      "actions": {
        "reactions": true,
        "messages": true,
        "threads": true,
        "pins": true
      }
    }
  },
  "plugins": {
    "entries": {
      "discord": {
        "enabled": true
      }
    }
  }
}
```

### Campos importantes

| Campo | Descricao |
|-------|-----------|
| `channels.discord.enabled` | Ativa o canal Discord |
| `channels.discord.dm.enabled` | Permite DMs com o bot |
| `channels.discord.dm.policy` | `"pairing"` = aprovacao manual; `"allowlist"` = so IDs listados; `"open"` = qualquer um |
| `channels.discord.dm.allowFrom` | Array de User IDs autorizados (usado com policy `"allowlist"`) |
| `channels.discord.groupPolicy` | Politica para servidores (`"allowlist"`, `"open"`, `"disabled"`) |
| `channels.discord.guilds` | Configuracao por servidor, indexado pelo Guild ID |
| `guilds.<id>.slug` | Nome amigavel para o servidor |
| `guilds.<id>.requireMention` | `true` = bot so responde quando mencionado com `@<nome_do_bot>` |
| `guilds.<id>.channels` | Configuracao por canal especifico (vazio = todos os canais) |
| `actions.reactions` | Permite o bot reagir a mensagens |
| `actions.messages` | Permite o bot enviar mensagens |
| `actions.threads` | Permite o bot criar/responder em threads |
| `actions.pins` | Permite o bot fixar mensagens |
| `plugins.entries.discord.enabled` | Habilita o plugin Discord no sistema de plugins |

### Opcoes adicionais de DM Policy

**Allowlist (restringir a utilizadores especificos):**

```json
"dm": {
  "enabled": true,
  "policy": "allowlist",
  "allowFrom": ["<discord_user_id>"]
}
```

**Open (qualquer utilizador pode enviar DMs):**

```json
"dm": {
  "enabled": true,
  "policy": "open",
  "allowFrom": ["*"]
}
```

### Configuracao avancada de canais no servidor

Para restringir o bot a canais especificos ou definir comportamentos por canal:

```json
"guilds": {
  "<guild_id_do_servidor>": {
    "slug": "<nome_do_servidor>",
    "requireMention": true,
    "channels": {
      "<nome_do_canal>": {
        "allow": true,
        "requireMention": false,
        "skills": ["search", "docs"],
        "systemPrompt": "Respostas curtas."
      }
    }
  }
}
```

## Passo 3 — Recriar o container

Como as variaveis de ambiente mudam, e necessario recriar o container (nao basta `restart`):

```bash
docker compose --project-directory dev \
  -f base/docker-compose.yml \
  -f dev/docker-compose.override.yml \
  up -d --force-recreate
```

**Nota:** `docker compose restart` nao recarrega variaveis do `.env`.
Usar sempre `up -d --force-recreate` quando alterar o `.env`.

## Passo 4 — Verificar os logs

```bash
docker exec openclaw_core cat /tmp/openclaw/openclaw-$(date +%Y-%m-%d).log | grep discord
```

Deve aparecer:

```
[discord] [default] starting provider (@<nome_do_bot>)
logged in to discord as <bot_user_id>
```

## Passo 5 — Aprovar pairing (DMs)

Quando um utilizador envia a primeira DM ao bot, recebe um codigo de pairing.
Para aprovar:

```bash
docker exec openclaw_core node dist/index.js pairing approve discord <codigo_de_pairing>
```

## Passo 6 — Diagnostico

```bash
docker exec openclaw_core node dist/index.js doctor
```

Deve mostrar:

```
Discord: ok (@<nome_do_bot>)
```

---

## Resolucao de problemas

### `Discord: not configured`

Verificar se a variavel de ambiente e `DISCORD_BOT_TOKEN` (nao `DISCORD_TOKEN`):

```bash
docker exec openclaw_core env | grep DISCORD
```

Se estiver errada, corrigir no `dev/.env` e recriar o container com `up -d --force-recreate`.

### `plugin not found: discord`

O diretorio `extensions/` nao foi copiado para a imagem Docker.
Verificar no Dockerfile se existe a linha:

```dockerfile
COPY --from=builder /build/extensions ./extensions
```

Se nao existir, adicionar, rebuildar e recriar o container.

### `Unknown Channel (404)`

O ID fornecido em `guilds` e um Guild ID (servidor), nao um Channel ID.
Isto e um aviso normal — o OpenClaw usa os config entries corretamente.

### Bot nao responde no servidor

Verificar se `requireMention` esta `true`. Se sim, e necessario mencionar o bot
com `@<nome_do_bot>` para ele responder.

### Env vars nao atualizam apos mudanca

Usar `up -d --force-recreate` em vez de `restart`:

```bash
docker compose --project-directory dev \
  -f base/docker-compose.yml \
  -f dev/docker-compose.override.yml \
  up -d --force-recreate
```

---

## Resumo de comandos

```bash
# 1. Configurar variaveis no dev/.env
#    DISCORD_BOT_TOKEN=<token_do_bot_discord>
#    DISCORD_GUILD_ID=<guild_id_do_servidor>

# 2. Recriar o container (para aplicar novas env vars)
docker compose --project-directory dev \
  -f base/docker-compose.yml \
  -f dev/docker-compose.override.yml \
  up -d --force-recreate

# 3. Verificar logs do Discord
docker exec openclaw_core cat /tmp/openclaw/openclaw-$(date +%Y-%m-%d).log | grep discord

# 4. Rodar diagnostico
docker exec openclaw_core node dist/index.js doctor

# 5. Aprovar pairing de um utilizador (DMs)
docker exec openclaw_core node dist/index.js pairing approve discord <codigo_de_pairing>

# 6. Verificar env vars no container
docker exec openclaw_core env | grep DISCORD
```
