# Instalacao

## Pre-requisitos

### 1. Docker Engine

```bash
# Verificar se ja esta instalado
docker --version

# Se nao estiver, instalar no Linux Mint 22
sudo apt update
sudo apt install -y docker.io docker-compose-v2

# Adicionar seu usuario ao grupo docker (evita usar sudo)
sudo usermod -aG docker $USER

# Reiniciar a sessao para aplicar (logout/login ou):
newgrp docker

# Verificar se funciona sem sudo
docker info
```

### 2. Ferramentas auxiliares

```bash
# curl (para healthchecks)
sudo apt install -y curl

# UFW firewall (normalmente ja vem no Mint)
sudo apt install -y ufw
sudo ufw enable
```

## Instalacao do projeto

### 1. Clonar ou acessar o repositorio

```bash
cd ~/Developer/jadsClaw
```

### 2. Criar os arquivos .env

**Desenvolvimento:**
```bash
cd dev
cp .env.example .env
# Editar e preencher suas chaves:
nano .env
```

**Producao:**
```bash
cd ../prod
cp .env.example .env
chmod 600 .env
# Editar e preencher suas chaves:
nano .env
```

### 3. Verificar a imagem Docker

```bash
# Baixar a imagem do OpenClawD
docker pull openclaw/openclawd:latest

# Verificar se foi baixada
docker images | grep openclaw
```

### 4. Primeiro inicio

```bash
# Voltar para a raiz do projeto
cd ~/Developer/jadsClaw

# Iniciar em modo desenvolvimento (primeira vez, para testar)
./scripts/start.sh dev

# Verificar se esta rodando
./scripts/status.sh dev
```

### 5. Verificacao pos-instalacao

```bash
# Ver logs para confirmar que iniciou corretamente
./scripts/logs.sh dev --tail 50

# Testar acesso local
curl http://127.0.0.1:8080/health
```

## Atualizacao da imagem

```bash
# Parar o ambiente atual
./scripts/stop.sh dev

# Baixar nova versao
docker pull openclaw/openclawd:latest

# Reiniciar
./scripts/start.sh dev
```

## Desinstalacao completa

```bash
# Parar e remover containers e volumes anonimos
./scripts/stop.sh dev --remove
./scripts/stop.sh prod --remove

# Remover a imagem (opcional)
docker rmi openclaw/openclawd:latest

# Remover dados (CUIDADO: irreversivel!)
# rm -rf prod/data dev/data
```
