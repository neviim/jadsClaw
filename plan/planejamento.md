Para garantir que você tenha flexibilidade no desenvolvimento e segurança máxima na produção, 
vamos estruturar o planejamento em dois perfis. O segredo aqui é usar a herança do Docker Compose 
para não repetir código, mantendo a "prisão" do container bem trancada.

---

## 📂 Estrutura de Pastas Unificada

Crie esta estrutura no seu Linux Mint para separar os ambientes:

```text
~/openclaw_project/
├── base/
│   └── docker-compose.yml      # Configurações comuns
├── dev/
│   ├── .env                    # Chaves de teste
│   └── docker-compose.override.yml
└── prod/
    ├── .env                    # Chaves reais (chmod 600)
    ├── docker-compose.prod.yml
    ├── data/                   # DB persistente
    └── config/                 # Configs estáticas

```

---

## ⚙️ 1. O Coração do Plano (Base Config)

Este arquivo define o que é comum a ambos. Salve em `base/docker-compose.yml`:

```yaml
services:
  openclawd:
    image: openclaw/openclawd:latest
    container_name: openclaw_core
    networks:
      - openclaw_internal
    env_file: .env
    # Proteção de Recursos
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: "1.5"

networks:
  openclaw_internal:
    driver: bridge

```

---

## 🛠️ 2. Ambiente de Desenvolvimento (Agilidade)

Focado em testes rápidos de Skills e Logs. Salve em `dev/docker-compose.override.yml`:

```yaml
services:
  openclawd:
    extends:
      file: ../base/docker-compose.yml
      service: openclawd
    ports:
      - "127.0.0.1:8080:8000" # Porta diferente para não conflitar
    volumes:
      - ./data:/app/data:rw
      - ./config:/app/config:rw # Escrita permitida para ajustes rápidos
    environment:
      - DEBUG=true
      - LOG_LEVEL=debug

```

---

## 🔒 3. Ambiente de Produção (Endurecido)

Aqui aplicamos o "Hardening" total que revisamos. Salve em `prod/docker-compose.prod.yml`:

```yaml
services:
  openclawd:
    extends:
      file: ../base/docker-compose.yml
      service: openclawd
    ports:
      - "127.0.0.1:8000:8000"
    volumes:
      - ./data:/app/data:rw
      - ./config:/app/config:ro # TOTALMENTE READ-ONLY
    
    # SEGURANÇA MÁXIMA
    user: "1000:1000"
    read_only: true
    security_opt:
      - no-new-privileges:true
      - apparmor=docker-default
    cap_drop:
      - ALL
    tmpfs:
      - /tmp:size=100M,noexec,nosuid,nodev
    restart: unless-stopped

```

---

## 🤖 4. Configuração de Canais e APIs (.env)

No seu arquivo `.env` (especialmente o de **Produção**), anexe estas variáveis para ativar o que você pediu:

```env
# --- CORE API ACCESS ---
ANTHROPIC_API_KEY=sua_chave_claude
GEMINI_API_KEY=sua_chave_gemini
ZAI_API_KEY=sua_chave_z_ai

# --- CHANNELS (TELEGRAM/DISCORD) ---
# Usando Long Polling para manter o bind 127.0.0.1 seguro
TELEGRAM_ENABLED=true
TELEGRAM_TOKEN=seu_token_aqui
TELEGRAM_ALLOWED_USERS=seu_id_usuario  # CRÍTICO: Só você acessa!

DISCORD_ENABLED=true
DISCORD_TOKEN=seu_token_discord

# --- WEB SKILLS ---
SEARCH_ENGINE_API=google_ou_tavily
SEARCH_API_KEY=sua_chave_busca

```

---

## 🚀 Como Executar

### Para Desenvolver:

```bash
cd ~/openclaw_project/dev
docker-compose -f ../base/docker-compose.yml -f docker-compose.override.yml up -d

```

### Para Produção:

```bash
cd ~/openclaw_project/prod
chmod 600 .env
docker-compose -f ../base/docker-compose.yml -f docker-compose.prod.yml up -d

```

---

## ✅ Notas de Fechamento do Planejamento

* **Acesso Web:** O OpenClaw usará as chaves do `.env` para sair para a internet. O container não precisa de portas abertas para isso.
* **Telegram/Discord:** Eles funcionarão via conexão de saída. Como você restringiu o acesso no `127.0.0.1`, a única "entrada" externa será através dos bots oficiais, que são protegidos por tokens.
* **Segurança de Root:** O parâmetro `user: "1000:1000"` garante que, se alguém "explodir" o OpenClaw, ele cairá em uma pasta vazia no seu Mint sem permissão de `sudo`.

Este plano agora cobre desde a vulnerabilidade de rede até o isolamento de privilégios. 

**Não esqueça de gerar um pequeno script em Bash para automatizar o backup da pasta `data/` de produção para um local seguro no meu Linux Mint**