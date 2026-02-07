# Acesso ao Container e Configuracoes

## Metodo 1: Interface web (navegador)

O OpenClawD disponibiliza uma interface web acessivel pelo navegador.
Apos iniciar o container, acesse:

| Ambiente        | URL                          |
|-----------------|------------------------------|
| Desenvolvimento | http://127.0.0.1:8080        |
| Producao        | http://127.0.0.1:8000        |

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

# Ver arquivos de configuracao
docker exec openclaw_core ls -la /app/config/

# Ver dados persistentes
docker exec openclaw_core ls -la /app/data/
```

### Limitacoes em producao

Em producao, o filesystem e somente leitura. Isso significa que voce **nao
conseguira** criar ou editar arquivos diretamente dentro do container
(exceto em `/tmp`).

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
# Extrair um arquivo do container
docker cp openclaw_core:/app/data/algum_arquivo.db ./

# Extrair logs internos
docker cp openclaw_core:/app/logs/ ./logs_exportados/
```

## Metodo 4: API REST (se disponivel)

Se o OpenClawD expoe uma API REST, voce pode interagir via `curl`:

```bash
# Verificar saude do servico
curl http://127.0.0.1:8000/health

# Listar configuracoes (endpoint pode variar)
curl http://127.0.0.1:8000/api/config

# Enviar mensagem de teste
curl -X POST http://127.0.0.1:8000/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Ola, OpenClaw!"}'
```

**Consulte a documentacao oficial do OpenClawD para os endpoints exatos.**

## Fluxo recomendado para configuracao inicial

1. **Iniciar em modo dev:**
   ```bash
   ./scripts/start.sh dev
   ```

2. **Acessar a interface web:**
   Abra http://127.0.0.1:8080 no navegador.

3. **Fazer todas as configuracoes pela interface:**
   - Conectar APIs (Claude, Gemini)
   - Configurar Skills
   - Configurar canais (Telegram, Discord)
   - Testar funcionamento

4. **Exportar configuracoes:**
   Copie os arquivos de configuracao gerados para `prod/config/`:
   ```bash
   cp -a dev/config/* prod/config/
   ```

5. **Iniciar em producao:**
   ```bash
   ./scripts/stop.sh dev
   ./scripts/start.sh prod
   ```

6. **Verificar:**
   ```bash
   ./scripts/status.sh prod
   ```

## Troubleshooting de acesso

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
ssh -L 8000:127.0.0.1:8000 usuario@seu-mint
# Depois acesse http://127.0.0.1:8000 no computador remoto
```
