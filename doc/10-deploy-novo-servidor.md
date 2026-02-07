# Deploy em Novo Servidor de Producao

Guia completo para configurar o jadsClaw em um servidor Linux recem-instalado,
do zero ate o OpenClaw rodando em producao com auto-update.

## Pre-requisitos do servidor

- Linux baseado em Debian/Ubuntu (testado em Linux Mint 22 e Ubuntu 24.04)
- Acesso root ou usuario com `sudo`
- Conexao com a internet
- Minimo 4GB RAM e 20GB de disco

## Passo a passo

### 1. Atualizar o sistema

```bash
sudo apt update && sudo apt upgrade -y
sudo reboot
```

### 2. Instalar dependencias basicas

```bash
sudo apt install -y \
    curl \
    git \
    ufw \
    ca-certificates \
    gnupg
```

### 3. Instalar o Docker

```bash
# Instalar Docker e Compose
sudo apt install -y docker.io docker-compose-v2

# Habilitar Docker no boot
sudo systemctl enable docker
sudo systemctl start docker

# Adicionar seu usuario ao grupo docker (evita sudo)
sudo usermod -aG docker $USER

# Aplicar a mudanca de grupo (ou faça logout/login)
newgrp docker

# Verificar
docker --version
docker compose version
```

### 4. Configurar firewall

```bash
# Ativar UFW
sudo ufw enable

# Permitir SSH (importante! senao voce perde acesso remoto)
sudo ufw allow ssh

# NAO abrir porta 18789 — o acesso e local via 127.0.0.1
# Se precisar de acesso remoto, use tunel SSH (veja passo 11)

# Verificar regras
sudo ufw status
```

### 5. Clonar o projeto

```bash
# Criar diretorio de trabalho (ajuste conforme preferencia)
mkdir -p ~/Developer
cd ~/Developer

# Clonar o repositorio
git clone https://github.com/iapalandi/jadsClaw.git
cd jadsClaw
```

### 6. Obter a imagem do OpenClaw

**Opcao A — Baixar do Docker Hub (mais rapido):**

```bash
docker pull iapalandi/openclaw:latest
```

**Opcao B — Build local (se a imagem nao estiver no Docker Hub):**

```bash
./scripts/build-push.sh --no-push
```

O build leva alguns minutos na primeira vez.

### 7. Configurar variaveis de ambiente

```bash
# Copiar o template
cp prod/.env.example prod/.env

# Definir permissoes restritas
chmod 600 prod/.env

# Editar e preencher suas chaves
nano prod/.env
```

Variaveis obrigatorias a preencher:

```bash
# Gerar token do gateway
openssl rand -hex 32
# Copie o resultado para OPENCLAW_GATEWAY_TOKEN

# Preencha pelo menos:
OPENCLAW_GATEWAY_TOKEN=<token_gerado>
ANTHROPIC_API_KEY=<sua_chave_claude>
```

Veja [03-configuracao.md](03-configuracao.md) para detalhes de cada variavel.

### 8. Verificar diretorios de dados

Os diretorios de dados sao criados automaticamente pelo `start.sh`, mas
voce pode garantir que existem:

```bash
mkdir -p prod/data prod/config
```

### 9. Iniciar em producao

**Sem Watchtower:**

```bash
./scripts/start.sh prod
```

**Com Watchtower (recomendado — auto-update diario):**

```bash
# Login no Docker Hub (necessario para o Watchtower verificar atualizacoes)
docker login

# Iniciar com auto-update
./scripts/start.sh prod --with-watchtower
```

### 10. Verificar se tudo esta funcionando

```bash
# Status completo
./scripts/status.sh prod

# Verificar logs
./scripts/logs.sh prod --tail 50

# Testar acesso ao gateway
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:18789/
# Esperado: 200 ou 302
```

### 11. Parear dispositivo (primeiro acesso)

No primeiro acesso pelo navegador, o OpenClaw exige pareamento do dispositivo:

1. Acesse http://127.0.0.1:18789 (ou via tunel SSH) e insira a senha
2. O navegador mostrara "pairing required" — isso e normal
3. Aprove o dispositivo:
   ```bash
   # Listar requests pendentes
   docker exec openclaw_core node dist/index.js devices list

   # Aprovar (use o requestId da lista)
   docker exec openclaw_core node dist/index.js devices approve <requestId>
   ```
4. Recarregue a pagina e insira a senha novamente

Veja [06-acesso-container.md](06-acesso-container.md) para detalhes sobre pairing.

### 13. Acesso remoto (opcional)

O OpenClaw so escuta em `127.0.0.1` por seguranca. Para acessar de outra
maquina, use um tunel SSH:

```bash
# No seu computador local, execute:
ssh -L 18789:127.0.0.1:18789 usuario@ip-do-servidor

# Depois acesse no navegador local:
# http://127.0.0.1:18789
```

### 14. Configurar backup automatico (opcional)

```bash
# Testar backup manual
./scripts/backup.sh

# Agendar backup semanal via cron
crontab -e
```

Adicione a linha:

```
0 3 * * 0 /home/$USER/Developer/jadsClaw/scripts/backup.sh >> /home/$USER/openclaw_backups/backup.log 2>&1
```

Isso roda o backup todo domingo as 3h da manha.

## Resumo dos comandos

```bash
# 1. Sistema
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git ufw ca-certificates gnupg docker.io docker-compose-v2
sudo systemctl enable docker && sudo systemctl start docker
sudo usermod -aG docker $USER && newgrp docker

# 2. Firewall
sudo ufw enable && sudo ufw allow ssh

# 3. Projeto
cd ~/Developer
git clone https://github.com/iapalandi/jadsClaw.git && cd jadsClaw

# 4. Imagem
docker pull iapalandi/openclaw:latest

# 5. Configuracao
cp prod/.env.example prod/.env && chmod 600 prod/.env
nano prod/.env

# 6. Iniciar
docker login
./scripts/start.sh prod --with-watchtower

# 7. Verificar
./scripts/status.sh prod
```

## Checklist pos-deploy

- [ ] Sistema atualizado
- [ ] Docker instalado e rodando
- [ ] UFW ativo com SSH permitido
- [ ] Projeto clonado
- [ ] Imagem obtida (pull ou build)
- [ ] `.env` configurado com chaves reais e permissao 600
- [ ] Container rodando (`status.sh` OK)
- [ ] Gateway respondendo na porta 18789
- [ ] Dispositivo pareado (device pairing aprovado)
- [ ] Watchtower ativo (se desejado)
- [ ] Backup agendado no cron
- [ ] Acesso remoto via SSH tunnel testado (se necessario)

## Troubleshooting

### Docker nao inicia

```bash
sudo systemctl status docker
sudo journalctl -u docker --tail 50
```

### Permissao negada no Docker

```bash
# Verificar se o usuario esta no grupo docker
groups
# Se "docker" nao aparecer:
sudo usermod -aG docker $USER
# Logout e login novamente
```

### Container nao sobe

```bash
# Verificar logs detalhados
./scripts/logs.sh prod --tail 100

# Verificar se a porta esta livre
ss -tlnp | grep 18789

# Verificar se a imagem existe
docker images | grep openclaw
```

### Sem espaco em disco

```bash
# Verificar disco
df -h

# Limpar imagens Docker nao utilizadas
docker system prune -f
```
