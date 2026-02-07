# Acesso ao Container e Configuracoes

## Metodo 1: Interface web (navegador)

O OpenClaw disponibiliza uma interface web (Gateway UI) acessivel pelo navegador.
Apos iniciar o container, acesse:

| Servico         | URL                          |
|-----------------|------------------------------|
| Gateway (UI)    | http://127.0.0.1:18789       |

A interface web permite:
- Configurar modelos de IA (Claude, Gemini, etc.)
- Gerenciar Skills e plugins
- Configurar canais (Telegram, Discord)
- Monitorar logs e status
- Ajustar parametros de comportamento

**Nota:** O acesso e restrito a `127.0.0.1` (apenas sua maquina). Ninguem na
rede local consegue acessar.

## Metodo 2: Acesso direto ao terminal do container

Para configuracoes avancadas ou depuracao, voce pode abrir um shell dentro
do container.

### Shell interativo

```bash
# Abrir bash (ou sh, dependendo da imagem)
docker exec -it openclaw_core /bin/bash

# Se bash nao estiver disponivel, tente sh
docker exec -it openclaw_core /bin/sh
```

### Executar comando unico

```bash
# Ver variaveis de ambiente carregadas
docker exec openclaw_core env

# Verificar processos rodando
docker exec openclaw_core ps aux

# Verificar conectividade de rede
docker exec openclaw_core curl -s http://httpbin.org/ip

# Ver dados persistentes do OpenClaw
docker exec openclaw_core ls -la /home/node/.openclaw/

# Ver arquivos de configuracao
docker exec openclaw_core ls -la /app/config/
```

### Limitacoes em producao

Em producao, o filesystem e somente leitura. Isso significa que voce **nao
conseguira** criar ou editar arquivos diretamente dentro do container
(exceto em `/tmp` e `/home/node/.cache`).

Para alterar configuracoes em producao:
1. Edite os arquivos na pasta `prod/config/` do host
2. Reinicie o container:
   ```bash
   ./scripts/stop.sh prod
   ./scripts/start.sh prod
   ```

Em desenvolvimento, o `config/` e gravavel, entao voce pode editar tanto pelo
host quanto de dentro do container.

## Metodo 3: Copiar arquivos entre host e container

### Copiar do host para o container

```bash
# Copiar arquivo de configuracao para dentro do container
docker cp meu_arquivo.conf openclaw_core:/app/config/
```

**Nota:** Em producao com `read_only: true`, use os volumes mapeados.
Coloque o arquivo em `prod/config/` no host e ele aparecera automaticamente
em `/app/config/` dentro do container.

### Copiar do container para o host

```bash
# Extrair dados do OpenClaw
docker cp openclaw_core:/home/node/.openclaw/ ./dados_exportados/

# Extrair um arquivo especifico
docker cp openclaw_core:/home/node/.openclaw/algum_arquivo ./
```

## Metodo 4: API REST (se disponivel)

Se o OpenClaw expoe uma API REST, voce pode interagir via `curl`:

```bash
# Verificar se o gateway esta respondendo
curl http://127.0.0.1:18789/

# Listar configuracoes (endpoint pode variar)
curl http://127.0.0.1:18789/api/config

# Enviar mensagem de teste
curl -X POST http://127.0.0.1:18789/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Ola, OpenClaw!"}'
```

**Consulte a documentacao oficial do OpenClaw para os endpoints exatos.**

## Fluxo recomendado para configuracao inicial

1. **Iniciar em modo dev:**
   ```bash
   ./scripts/start.sh dev
   ```

2. **Acessar a interface web:**
   Abra http://127.0.0.1:18789 no navegador e insira a senha (`OPENCLAW_GATEWAY_PASSWORD`).

3. **Aprovar o dispositivo (primeiro acesso):**
   O navegador mostrara "pairing required". Aprove via terminal:
   ```bash
   docker exec openclaw_core node dist/index.js devices list
   docker exec openclaw_core node dist/index.js devices approve <requestId>
   ```
   Recarregue a pagina e insira a senha novamente.

4. **Fazer todas as configuracoes pela interface:**
   - Conectar APIs (Claude, Gemini)
   - Configurar Skills
   - Configurar canais (Telegram, Discord)
   - Testar funcionamento

4. **Exportar configuracoes:**
   Copie os arquivos de configuracao gerados para `prod/config/`:
   ```bash
   cp -a dev/config/* prod/config/
   ```

6. **Iniciar em producao:**
   ```bash
   ./scripts/stop.sh dev
   ./scripts/start.sh prod
   ```

7. **Verificar:**
   ```bash
   ./scripts/status.sh prod
   ```

## Pareamento de dispositivos (Device Pairing)

O OpenClaw exige que cada dispositivo (navegador, CLI, etc.) seja **aprovado
manualmente** antes de poder usar o sistema. Isso e um mecanismo de seguranca:
mesmo com a senha correta, um dispositivo novo precisa ser pareado.

### Por que o pairing existe

- **Sem confianca automatica**: todo dispositivo precisa de aprovacao explicita
- **Rotacao de tokens**: cada aprovacao gera um token unico para o dispositivo
- **Auditoria**: dispositivos pareados ficam registrados em `devices/paired.json`

### Fluxo de pareamento

1. Voce acessa a Control UI no navegador e insere a senha
2. O Gateway registra o dispositivo como **pendente**
3. Um operador aprova o dispositivo via CLI
4. O navegador reconecta automaticamente e funciona

### Como aprovar um dispositivo

```bash
# Listar dispositivos (pendentes e pareados)
docker exec openclaw_core node dist/index.js devices list

# Aprovar um dispositivo pendente (use o requestId da lista)
docker exec openclaw_core node dist/index.js devices approve <requestId>
```

**Exemplo completo:**

```bash
$ docker exec openclaw_core node dist/index.js devices list

Pending (1)
┌──────────────────────────────────────┬──────────┬────────────┐
│ Request                              │ Role     │ IP         │
├──────────────────────────────────────┼──────────┼────────────┤
│ 3a37ea79-20f8-4352-be27-31875b82ba77 │ operator │ 172.18.0.1 │
└──────────────────────────────────────┴──────────┴────────────┘

$ docker exec openclaw_core node dist/index.js devices approve 3a37ea79-20f8-4352-be27-31875b82ba77
Approved 4885a2ea...
```

Apos aprovar, recarregue a pagina no navegador e insira a senha novamente.

> **Nota:** Requests pendentes expiram apos 5 minutos. Se expirar, recarregue
> a pagina no navegador para gerar um novo request e aprove novamente.

### Dados sensiveis

Os arquivos de pareamento ficam em:
- `data/devices/paired.json` — dispositivos aprovados (contem tokens)
- `data/devices/pending.json` — requests pendentes

Trate `paired.json` como dados sensiveis (equivalente a credenciais).

## Troubleshooting de acesso

### "disconnected (1008): pairing required"

Este erro aparece no navegador quando o dispositivo ainda nao foi aprovado pelo
operador.

**Solucao:**
1. Verifique se ha requests pendentes:
   ```bash
   docker exec openclaw_core node dist/index.js devices list
   ```
2. Aprove o dispositivo:
   ```bash
   docker exec openclaw_core node dist/index.js devices approve <requestId>
   ```
3. Recarregue a pagina no navegador e insira a senha novamente

### "unauthorized: gateway password missing"

Este erro aparece no navegador quando a `OPENCLAW_GATEWAY_PASSWORD` esta configurada
no `.env` mas ainda nao foi informada na interface web.

**Solucao:**
1. Abra http://127.0.0.1:18789 no navegador
2. Clique no icone de **Settings** (engrenagem)
3. No campo de senha/password, informe a mesma senha definida em `OPENCLAW_GATEWAY_PASSWORD` no seu `.env`
4. A conexao sera autenticada e o erro desaparece

Para verificar qual senha esta configurada:
```bash
grep OPENCLAW_GATEWAY_PASSWORD dev/.env   # desenvolvimento
grep OPENCLAW_GATEWAY_PASSWORD prod/.env  # producao
```

### "Connection refused" ao acessar pelo navegador

- O container pode ainda estar inicializando. Aguarde 15-30 segundos.
- Verifique se esta rodando: `./scripts/status.sh prod`
- Verifique os logs: `./scripts/logs.sh prod --tail 50`

### Nao consigo editar arquivos dentro do container (producao)

Isso e intencional. Em producao, o filesystem e somente leitura por seguranca.
Edite os arquivos em `prod/config/` no host e reinicie o container.

### Container reinicia em loop

Verifique os logs para identificar o erro:
```bash
./scripts/logs.sh prod --tail 200
```
Causas comuns:
- Chaves API invalidas no `.env`
- Porta ja em uso
- Permissoes incorretas nos volumes

### Nao consigo acessar de outro computador na rede

Isso tambem e intencional. O acesso e restrito a `127.0.0.1` por seguranca.
Se voce realmente precisa de acesso remoto (NAO recomendado), considere usar
um tunel SSH em vez de abrir a porta:

```bash
# No computador remoto:
ssh -L 18789:127.0.0.1:18789 usuario@seu-mint
# Depois acesse http://127.0.0.1:18789 no computador remoto
```
