# Configuracao

## Estrutura dos arquivos .env

Cada ambiente (dev e prod) possui seu proprio arquivo `.env`. Estes arquivos
contem todas as chaves API e configuracoes sensiveis.

**Nunca versione os arquivos `.env` no git.** O `.gitignore` ja protege contra
isso, mas sempre verifique antes de fazer commit.

## Variaveis disponiveis

### APIs principais

| Variavel           | Descricao                          | Obrigatoria |
|--------------------|------------------------------------|-------------|
| ANTHROPIC_API_KEY  | Chave da API do Claude (Anthropic) | Sim         |
| GEMINI_API_KEY     | Chave da API do Google Gemini      | Nao         |
| ZAI_API_KEY        | Chave da API do Z.ai (Groq)        | Nao         |

### Canais de comunicacao

| Variavel                 | Descricao                                         |
|--------------------------|---------------------------------------------------|
| TELEGRAM_ENABLED         | `true` ou `false` para ativar Telegram            |
| TELEGRAM_TOKEN           | Token do bot obtido via @BotFather                |
| TELEGRAM_ALLOWED_USERS   | IDs de usuario permitidos (separados por virgula) |
| DISCORD_ENABLED          | `true` ou `false` para ativar Discord             |
| DISCORD_TOKEN            | Token do bot do Discord                           |

**IMPORTANTE:** O campo `TELEGRAM_ALLOWED_USERS` e critico para seguranca.
Sem ele, qualquer pessoa que encontrar seu bot podera interagir com o OpenClawD.

Para descobrir seu ID do Telegram, envie uma mensagem para @userinfobot.

### Busca web (Skills)

| Variavel          | Descricao                              |
|-------------------|----------------------------------------|
| SEARCH_ENGINE_API | Motor de busca: `google` ou `tavily`   |
| SEARCH_API_KEY    | Chave da API do motor de busca         |

### Configuracoes de ambiente

| Variavel   | Dev     | Prod    | Descricao                    |
|------------|---------|---------|------------------------------|
| DEBUG      | `true`  | `false` | Modo de depuracao            |
| LOG_LEVEL  | `debug` | `info`  | Nivel de verbosidade dos logs|

## Como obter as chaves API

### Claude (Anthropic)
1. Acesse https://console.anthropic.com/
2. Va em API Keys
3. Crie uma nova chave com permissoes minimas (somente chat/messages)
4. Copie e cole no `.env`

### Google Gemini
1. Acesse https://aistudio.google.com/apikey
2. Crie uma chave de API
3. Copie e cole no `.env`

### Telegram Bot
1. Abra o Telegram e fale com @BotFather
2. Use o comando /newbot
3. Siga as instrucoes e copie o token
4. Copie e cole no `.env`

### Discord Bot
1. Acesse https://discord.com/developers/applications
2. Crie uma nova aplicacao
3. Va em Bot > Token > Reset Token
4. Copie e cole no `.env`

## Docker Compose — Arquivos de configuracao

### base/docker-compose.yml

Define os recursos compartilhados entre ambientes:
- Imagem do OpenClawD
- Limite de memoria (2G) e CPU (1.5 cores)
- Rede interna do Docker

### dev/docker-compose.override.yml

Configuracoes especificas de desenvolvimento:
- Porta `8080` (local)
- Volumes com escrita permitida em `data/` e `config/`
- Debug ativado

### prod/docker-compose.prod.yml

Configuracoes de producao com hardening:
- Porta `8000` (local)
- `config/` em somente leitura
- Filesystem somente leitura
- Sem root, sem capabilities
- Healthcheck automatico
- Restart automatico

## Validacao da configuracao

Apos preencher o `.env`, use o script de validacao:

```bash
./scripts/start.sh dev
```

O script verifica automaticamente:
- Se o Docker esta instalado e rodando
- Se os arquivos de configuracao existem
- Se o `.env` contem valores placeholder nao substituidos
- Se as permissoes do `.env` estao corretas (producao)
- Se a porta necessaria esta disponivel
