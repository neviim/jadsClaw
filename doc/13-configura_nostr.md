# Configuracao do Canal Nostr no OpenClaw

## O que e Nostr

Nostr (Notes and Other Stuff Transmitted by Relays) e um protocolo descentralizado
de comunicacao. Nao tem contas tradicionais — a identidade e baseada em pares de
chaves criptograficas (secp256k1). As mensagens sao transmitidas atraves de relays
(servidores WebSocket publicos).

- **Chave privada (`nsec`)**: Equivalente a senha — NUNCA compartilhar
- **Chave publica (`npub`)**: Equivalente ao username — pode ser compartilhada
- **Relays**: Servidores que retransmitem mensagens entre utilizadores

## Pre-requisitos

- Container OpenClaw rodando (`openclaw_core`)
- Extensao `nostr` presente em `/app/extensions/nostr/` (incluida na imagem)

---

## Passo 1 — Gerar par de chaves Nostr

O OpenClaw inclui `nostr-tools` no container. Para gerar um novo par de chaves:

```bash
docker exec openclaw_core node -e "
const { generateSecretKey, getPublicKey } = require('/app/node_modules/.pnpm/node_modules/nostr-tools/lib/cjs/pure.js');
const { nsecEncode, npubEncode } = require('/app/node_modules/.pnpm/node_modules/nostr-tools/lib/cjs/nip19.js');

const sk = generateSecretKey();
const pk = getPublicKey(sk);

console.log('nsec=' + nsecEncode(sk));
console.log('npub=' + npubEncode(pk));
console.log('hex_private=' + Buffer.from(sk).toString('hex'));
console.log('hex_public=' + pk);
"
```

Guardar os valores gerados:

| Valor | Formato | Uso |
|-------|---------|-----|
| `nsec` | `nsec1...` | Chave privada — colocar no `.env` |
| `npub` | `npub1...` | Chave publica — partilhar com outros utilizadores |
| `hex_private` | 64 caracteres hex | Formato alternativo da chave privada |
| `hex_public` | 64 caracteres hex | Formato alternativo da chave publica |

**IMPORTANTE:** A chave privada (`nsec`) e como uma senha. Quem tiver acesso a ela
controla a identidade Nostr. Guardar em local seguro e nunca commitar no git.

## Passo 2 — Variaveis de ambiente

No ficheiro `dev/.env`, adicionar:

```env
NOSTR_ENABLED=true
# Chave privada Nostr (nsec) — NUNCA compartilhar ou commitar
NOSTR_PRIVATE_KEY=<chave_privada_nsec>
# Chave publica (npub) do utilizador autorizado a enviar DMs ao bot
NOSTR_ALLOWED_NPUB=<npub_do_utilizador_autorizado>
```

## Passo 3 — Configuracao do OpenClaw (`openclaw.json`)

No ficheiro `dev/data/openclaw.json`, adicionar a secao `nostr` dentro de `channels`
e o plugin em `plugins.entries`:

```json
{
  "channels": {
    "nostr": {
      "enabled": true,
      "privateKey": "<chave_privada_nsec>",
      "relays": [
        "wss://relay.damus.io",
        "wss://nos.lol",
        "wss://relay.primal.net",
        "wss://relay.snort.social",
        "wss://nostr.wine"
      ],
      "dmPolicy": "allowlist",
      "allowFrom": [
        "<npub_do_utilizador_autorizado>"
      ],
      "actions": {
        "sendMessage": true
      }
    }
  },
  "plugins": {
    "entries": {
      "nostr": {
        "enabled": true
      }
    }
  }
}
```

### Campos importantes

| Campo | Descricao |
|-------|-----------|
| `channels.nostr.enabled` | Ativa o canal Nostr |
| `channels.nostr.privateKey` | Chave privada em formato `nsec` ou hex |
| `channels.nostr.relays` | Array de URLs de relays WebSocket |
| `channels.nostr.dmPolicy` | `"allowlist"` = so pubkeys listadas; `"pairing"` = aprovacao manual; `"open"` = qualquer um; `"disabled"` = ignorar DMs |
| `channels.nostr.allowFrom` | Array de pubkeys (`npub` ou hex) autorizadas (usado com `"allowlist"`) |
| `channels.nostr.actions.sendMessage` | Habilita o envio de mensagens (responder DMs) |
| `plugins.entries.nostr.enabled` | Habilita o plugin Nostr no sistema de plugins |

### Relays configurados

| Relay | URL | Tipo | Descricao |
|-------|-----|------|-----------|
| Damus | `wss://relay.damus.io` | Gratuito | Um dos relays mais populares, mantido pela equipa do Damus (iOS) |
| nos.lol | `wss://nos.lol` | Gratuito | Relay rapido e confiavel com boa cobertura global |
| Primal | `wss://relay.primal.net` | Gratuito | Mantido pela Primal (cliente web/mobile), boa performance |
| Snort | `wss://relay.snort.social` | Gratuito | Mantido pelo Snort (cliente web), relay estavel e bem conectado |
| Wine | `wss://nostr.wine` | Pago (~$7/mes) | Relay premium com filtragem de spam e melhor sinal/ruido |

### Relays adicionais (opcionais)

Se precisar de mais cobertura ou redundancia, considerar adicionar:

| Relay | URL | Tipo | Descricao |
|-------|-----|------|-----------|
| Nostr Band | `wss://relay.nostr.band` | Gratuito | Relay de indexacao, bom para descoberta de conteudo |
| Mutiny | `wss://nostr.mutinywallet.com` | Gratuito | Mantido pela Mutiny Wallet, focado em Bitcoin/Lightning |
| Nostr BG | `wss://nostr.bg` | Gratuito | Relay europeu, boa latencia para Europa |
| Relay Exchange | `wss://relay.exchange` | Gratuito | Relay de uso geral com boa disponibilidade |

### Notas sobre relays

- Usar **3-5 relays** para bom equilibrio entre redundancia e latencia
- Relays pagos (como `nostr.wine`) reduzem drasticamente o spam
- Consultar [nostr.watch](https://nostr.watch/relays/find) para monitorizar uptime e latencia dos relays
- Consultar [nostr.info/relays](https://nostr.info/relays/) para estatisticas de relays

### Opcoes de DM Policy

**Allowlist (restringir a pubkeys especificas — recomendado):**

```json
"dmPolicy": "allowlist",
"allowFrom": ["<npub_do_utilizador>"]
```

**Pairing (aprovacao manual):**

Novos remetentes recebem um codigo de pairing que deve ser aprovado.

```json
"dmPolicy": "pairing"
```

**Open (qualquer utilizador):**

```json
"dmPolicy": "open"
```

### Perfil Nostr (metadados NIP-01)

Configurar opcionalmente os metadados do perfil:

```json
"nostr": {
  "enabled": true,
  "privateKey": "<chave_privada_nsec>",
  "relays": ["wss://relay.damus.io", "wss://nos.lol"],
  "profile": {
    "name": "<nome_do_bot>",
    "displayName": "<nome_exibicao>",
    "about": "<descricao_do_bot>",
    "picture": "<url_https_do_avatar>",
    "website": "<url_https_do_site>"
  }
}
```

**Nota:** URLs do perfil devem usar HTTPS.

---

## Passo 4 — Aplicar patches (obrigatorio na versao 2026.2.6)

A extensao Nostr na versao `2026.2.6` do OpenClaw tem 3 bugs que impedem o
funcionamento. Os patches sao montados como volumes sobre os ficheiros originais
da imagem Docker.

### Estrutura dos patches

```
dev/
  patches/
    nostr/
      src/
        nostr-bus.ts    # Fix: subscribeMany + normalizePubkey
        channel.ts      # Fix: pipeline de inbound
```

### Bug 1 — `nostr-tools@2.23.0` subscribeMany double-wrapping

**Sintoma:** Relays rejeitam a subscricao com `ERROR: bad req: provided filter is not an object`

**Causa:** `pool.subscribeMany(relays, [filter], ...)` empacota o filtro duas vezes
internamente (`[[filter]]` em vez de `[filter]`), enviando um array onde o relay
espera um objeto.

**Fix em `nostr-bus.ts`:** Passar o filtro como objeto unico em vez de array:

```typescript
// ANTES (bugado):
const sub = pool.subscribeMany(relays, [{ kinds: [4], "#p": [pk], since }], {...});

// DEPOIS (fix):
const sub = pool.subscribeMany(relays, { kinds: [4], "#p": [pk], since } as any, {...});
```

### Bug 2 — `handleInboundMessage` nao existe

**Sintoma:** `runtime.channel.reply.handleInboundMessage is not a function`

**Causa:** A extensao Nostr chama `runtime.channel.reply.handleInboundMessage()` que
nunca existiu no SDK do OpenClaw. Os canais built-in (Telegram, Discord) usam o
pipeline completo: `finalizeInboundContext` -> `recordInboundSession` ->
`dispatchReplyWithBufferedBlockDispatcher`.

**Fix em `channel.ts`:** Substituir a chamada `handleInboundMessage` pelo pipeline
completo de inbound, incluindo:
- Verificacao de DM policy (allowlist/pairing/open/disabled)
- Resolucao de rota do agente (`resolveAgentRoute`)
- Formatacao do envelope (`formatAgentEnvelope`)
- Finalizacao do contexto (`finalizeInboundContext`)
- Registo de sessao (`recordInboundSession`)
- Dispatch da resposta (`dispatchReplyWithBufferedBlockDispatcher`)

### Bug 3 — `normalizePubkey` corrupcao de hex

**Sintoma:** DMs de utilizadores na allowlist sao bloqueados com `drop DM not allowed`

**Causa:** `nip19.decode()` no build CJS do `nostr-tools@2.23.0` retorna `data` como
string hex em vez de `Uint8Array`. A funcao `normalizePubkey` fazia
`Array.from(decoded.data)` que, numa string, cria array de caracteres individuais,
corrompendo o resultado.

**Fix em `nostr-bus.ts`:** Detectar quando `decoded.data` e string e retornar diretamente:

```typescript
// ANTES (bugado):
return Array.from(decoded.data)
  .map((b) => b.toString(16).padStart(2, "0"))
  .join("");

// DEPOIS (fix):
if (typeof decoded.data === "string") {
  return decoded.data.toLowerCase();
}
return Array.from(decoded.data)
  .map((b: number) => b.toString(16).padStart(2, "0"))
  .join("");
```

### Volume mounts no docker-compose

No ficheiro `dev/docker-compose.override.yml`, os patches sao montados como read-only:

```yaml
volumes:
  - ./data:/home/node/.openclaw:rw
  - ./config:/app/config:rw
  # Patch: fix nostr-tools@2.23.0 subscribeMany double-wrapping bug
  - ./patches/nostr/src/nostr-bus.ts:/app/extensions/nostr/src/nostr-bus.ts:ro
  # Patch: fix missing handleInboundMessage — use standard inbound pipeline
  - ./patches/nostr/src/channel.ts:/app/extensions/nostr/src/channel.ts:ro
```

### Nota sobre atualizacoes

Quando o OpenClaw lancar uma versao que corrija estes bugs, os patches podem ser
removidos:

1. Remover as linhas de volume mount no `docker-compose.override.yml`
2. Opcionalmente apagar `dev/patches/`
3. Recriar o container

Para verificar se uma nova versao corrigiu os bugs:

```bash
# Verificar se subscribeMany ainda tem o bug
docker exec openclaw_core node -e "
const { SimplePool } = require('/app/node_modules/.pnpm/nostr-tools@*/node_modules/nostr-tools');
// Se nao der erro de import, verificar a versao
"

# Verificar se handleInboundMessage existe
docker exec openclaw_core node -e "
// Se 'handleInboundMessage' aparecer, a funcao existe e o patch channel.ts pode ser removido
"
```

---

## Passo 5 — Recriar o container

```bash
docker compose --project-directory dev \
  -f base/docker-compose.yml \
  -f dev/docker-compose.override.yml \
  up -d --force-recreate
```

## Passo 6 — Verificar o status

```bash
docker exec openclaw_core node dist/index.js doctor
```

Deve mostrar:

```
Nostr: configured
```

**Nota:** A Control UI pode mostrar `Running: No` mesmo com o Nostr funcionando.
Isto e um problema cosmetico — o framework nao propaga o estado `running: true`
para extensoes carregadas via `jiti` (transpiler TypeScript em runtime) da mesma
forma que faz para canais nativos. Nao afeta a funcionalidade.

Verificar nos logs se o provider iniciou:

```bash
docker logs openclaw_core 2>&1 | grep nostr
```

Deve mostrar:

```
[nostr] [default] starting Nostr provider (pubkey: <hex_pubkey>)
[nostr] [default] Nostr provider started, connected to 5 relay(s)
```

## Passo 7 — Testar

Para contactar o bot no Nostr, usar um cliente Nostr (ex: Damus, Primal, Amethyst)
e enviar uma DM para a chave publica (`npub`) gerada no Passo 1.

Clientes Nostr recomendados:

| Plataforma | Cliente | URL |
|------------|---------|-----|
| iOS | Damus | [damus.io](https://damus.io) |
| Android | Amethyst | [Play Store](https://play.google.com/store/apps/details?id=com.vitorpamplona.amethyst) |
| Web | Primal | [primal.net](https://primal.net) |
| Web | Snort | [snort.social](https://snort.social) |

---

## Teste com relay local

Para testar sem depender de relays publicos:

```bash
docker run -p 7777:7777 ghcr.io/hoytech/strfry
```

E usar no config:

```json
"relays": ["ws://localhost:7777"]
```

---

## Resolucao de problemas

### `Nostr: not configured`

Verificar se a chave privada esta no `.env`:

```bash
docker exec openclaw_core env | grep NOSTR
```

### `plugin not found: nostr`

Verificar se o diretorio `extensions/` foi copiado na imagem Docker:

```bash
docker exec openclaw_core ls /app/extensions/nostr/
```

Se nao existir, corrigir o Dockerfile (adicionar `COPY --from=builder /build/extensions ./extensions`),
rebuildar e recriar.

### `ERROR: bad req: provided filter is not an object`

O patch `nostr-bus.ts` nao esta aplicado. Verificar se o volume mount existe
no `docker-compose.override.yml` e se o ficheiro `dev/patches/nostr/src/nostr-bus.ts` existe.

### `handleInboundMessage is not a function`

O patch `channel.ts` nao esta aplicado. Verificar se o volume mount existe
no `docker-compose.override.yml` e se o ficheiro `dev/patches/nostr/src/channel.ts` existe.

### `drop DM not allowed (dmPolicy=allowlist)` para utilizador que esta na allowlist

O patch de `normalizePubkey` nao esta aplicado. Este fix esta no mesmo ficheiro
`nostr-bus.ts`. Verificar se a versao do patch inclui a correcao de
`typeof decoded.data === "string"`.

### Nao recebe mensagens

- Verificar se os relays estao acessiveis
- Confirmar que o remetente esta a enviar para a `npub` correta
- Verificar se `dmPolicy` nao esta como `"disabled"`
- Confirmar que o remetente usa NIP-04 (kind:4) e nao NIP-44 (kind:1059 gift-wrap)

### Env vars nao atualizam

Usar `up -d --force-recreate` (nao `restart`):

```bash
docker compose --project-directory dev \
  -f base/docker-compose.yml \
  -f dev/docker-compose.override.yml \
  up -d --force-recreate
```

### Control UI mostra `Running: No`

Isto e cosmético. Verificar nos logs se o provider esta ativo:

```bash
docker logs openclaw_core 2>&1 | grep "Nostr provider started"
```

Se aparecer `connected to X relay(s)`, o canal esta funcionando normalmente.

---

## Resumo de comandos

```bash
# 1. Gerar par de chaves Nostr
docker exec openclaw_core node -e "
const { generateSecretKey, getPublicKey } = require('/app/node_modules/.pnpm/node_modules/nostr-tools/lib/cjs/pure.js');
const { nsecEncode, npubEncode } = require('/app/node_modules/.pnpm/node_modules/nostr-tools/lib/cjs/nip19.js');
const sk = generateSecretKey();
const pk = getPublicKey(sk);
console.log('nsec=' + nsecEncode(sk));
console.log('npub=' + npubEncode(pk));
"

# 2. Configurar env vars no dev/.env
#    NOSTR_PRIVATE_KEY=<chave_privada_nsec>
#    NOSTR_ALLOWED_NPUB=<npub_do_utilizador_autorizado>

# 3. Recriar o container
docker compose --project-directory dev \
  -f base/docker-compose.yml \
  -f dev/docker-compose.override.yml \
  up -d --force-recreate

# 4. Rodar diagnostico
docker exec openclaw_core node dist/index.js doctor

# 5. Verificar logs do Nostr
docker logs openclaw_core 2>&1 | grep nostr

# 6. Verificar env vars no container
docker exec openclaw_core env | grep NOSTR
```

---

## Resumo dos ficheiros envolvidos

| Ficheiro | Descricao |
|----------|-----------|
| `dev/.env` | Variaveis de ambiente (`NOSTR_PRIVATE_KEY`, `NOSTR_ALLOWED_NPUB`) |
| `dev/.env.example` | Template com placeholders |
| `dev/data/openclaw.json` | Configuracao do OpenClaw (channels, plugins, relays, allowlist) |
| `dev/docker-compose.override.yml` | Volume mounts dos patches |
| `dev/patches/nostr/src/nostr-bus.ts` | Patch: subscribeMany + normalizePubkey |
| `dev/patches/nostr/src/channel.ts` | Patch: pipeline de inbound (substitui handleInboundMessage) |
