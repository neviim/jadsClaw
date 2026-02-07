# Seguranca e Hardening

## Visao geral das camadas de protecao

O projeto implementa seguranca em multiplas camadas para garantir que, mesmo
em caso de comprometimento do OpenClaw, o atacante nao consiga acessar a
maquina host.

```
┌─────────────────────────────────────────────┐
│  Camada 1: Rede (bind 127.0.0.1 + UFW)      │
├─────────────────────────────────────────────┤
│  Camada 2: Filesystem (read_only + tmpfs)   │
├─────────────────────────────────────────────┤
│  Camada 3: Privilegios (non-root + cap_drop)│
├─────────────────────────────────────────────┤
│  Camada 4: Recursos (limites mem/cpu)       │
├─────────────────────────────────────────────┤
│  Camada 5: Segredos (chmod 600 + .gitignore)│
└─────────────────────────────────────────────┘
```

## Detalhamento de cada protecao

### 1. Usuario non-root

```yaml
user: "1000:1000"
```

O container roda com o usuario `node` (uid 1000), que e o usuario padrao
da imagem `node:22-bookworm`. Isso significa que:
- Se o processo escapar do container, ele nao tera privilegios de root no host.
- Arquivos criados nos volumes terao as permissoes do seu usuario.

**Verificacao:**
```bash
docker exec openclaw_core whoami
# Esperado: node
```

### 2. Filesystem somente leitura

```yaml
read_only: true
tmpfs:
  - /tmp:size=100M,noexec,nosuid,nodev
  - /home/node/.cache:size=200M,noexec,nosuid,nodev
```

O filesystem inteiro do container e montado como somente leitura. Os unicos
locais gravaveis sao:
- `/tmp` — arquivos temporarios (100MB, sem execucao)
- `/home/node/.cache` — cache do Node.js (200MB, sem execucao)
- `/home/node/.openclaw` — dados persistentes (volume mapeado)

**Verificacao:**
```bash
docker exec openclaw_core touch /testfile
# Esperado: "Read-only file system" ou "Permission denied"
```

### 3. Capabilities removidas

```yaml
cap_drop:
  - ALL
```

Todas as capabilities do kernel Linux sao removidas. Isso impede:
- Montar filesystems
- Alterar configuracoes de rede
- Enviar sinais para processos externos
- Usar raw sockets (sem ARP spoofing ou sniffing)

**Verificacao:**
```bash
docker exec openclaw_core cat /proc/1/status | grep CapEff
# Esperado: 0000000000000000 (todos zeros = sem capabilities)
```

### 4. Prevencao de escalacao de privilegios

```yaml
security_opt:
  - no-new-privileges:true
  - apparmor=docker-default
```

- `no-new-privileges`: Impede que qualquer processo dentro do container ganhe
  privilegios adicionais via `setuid`, `setgid` ou capabilities de arquivo.
- `apparmor=docker-default`: Aplica o perfil AppArmor padrao do Docker, que
  restringe acesso a `/proc`, `/sys` e outros caminhos sensiveis.

### 5. Rede restrita

```yaml
ports:
  - "127.0.0.1:18789:18789"
  - "127.0.0.1:18790:18790"
```

As portas sao mapeadas APENAS para `127.0.0.1` (localhost). Isso significa:
- Ninguem na sua rede Wi-Fi/LAN consegue acessar o OpenClaw.
- O acesso e exclusivamente pelo navegador da sua maquina.

**NAO use:**
```yaml
# ERRADO — expoe para toda a rede
ports:
  - "18789:18789"
  - "0.0.0.0:18789:18789"
```

### 6. Limite de recursos

```yaml
deploy:
  resources:
    limits:
      memory: 2G
      cpus: "1.5"
```

Impede que o container consuma todos os recursos da maquina. Se o OpenClaw
tentar usar mais de 2GB de RAM, o Docker matara o processo (OOM kill).

## O que NUNCA fazer

| Acao perigosa                        | Motivo                                         |
|--------------------------------------|------------------------------------------------|
| `--privileged`                       | Da acesso total ao kernel do host              |
| `-v /:/host`                         | Expoe todo o filesystem da maquina             |
| `-v /var/run/docker.sock:/...`       | Permite controlar o Docker do host (escape)    |
| `network_mode: host`                 | Remove isolamento de rede completamente        |
| `cap_add: SYS_ADMIN`                 | Permite montar filesystems e escapar           |
| `cap_add: NET_RAW`                   | Permite sniffing e ARP spoofing                |
| Rodar sem `.gitignore` para `.env`   | Risco de vazar chaves API no repositorio       |

**Nota:** O Watchtower precisa do Docker socket para funcionar — isso e
esperado e seguro pois ele roda em um container separado com `read_only: true`
e `cap_drop: ALL`.

## Checklist de verificacao de seguranca

Execute o script de status para verificar todas as protecoes:

```bash
./scripts/status.sh prod
```

O script verifica automaticamente:
- [ ] Processo non-root (usuario `node`)
- [ ] Filesystem somente leitura
- [ ] Capabilities zeradas
- [ ] Healthcheck respondendo
- [ ] Portas mapeadas apenas em 127.0.0.1
- [ ] Status do Watchtower

### Verificacao manual adicional

```bash
# Socket do Docker NAO esta mapeado no openclaw_core
docker inspect openclaw_core --format='{{.HostConfig.Binds}}' | grep -v docker.sock

# Nenhuma capability ativa
docker inspect openclaw_core --format='{{.HostConfig.CapAdd}}'
# Esperado: [] ou vazio

# Modo privilegiado desativado
docker inspect openclaw_core --format='{{.HostConfig.Privileged}}'
# Esperado: false
```

## Firewall do host (UFW)

```bash
# Ativar firewall
sudo ufw enable

# Verificar status
sudo ufw status

# Como mapeamos para 127.0.0.1, o trafego externo ja e bloqueado.
# Mas por precaucao, nao abra as portas 18789/18790 no UFW.
```
