# Seguranca e Hardening

## Visao geral das camadas de protecao

O projeto implementa seguranca em multiplas camadas para garantir que, mesmo
em caso de comprometimento do OpenClawD, o atacante nao consiga acessar a
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

O container roda com o mesmo UID/GID do seu usuario local. Isso significa que:
- Se o processo escapar do container, ele nao tera privilegios de root no host.
- Arquivos criados nos volumes terao as permissoes do seu usuario.

**Verificacao:**
```bash
docker exec openclaw_core whoami
# Esperado: NÃO deve retornar "root"
```

### 2. Filesystem somente leitura

```yaml
read_only: true
tmpfs:
  - /tmp:size=100M,noexec,nosuid,nodev
```

O filesystem inteiro do container e montado como somente leitura. O unico
local gravavel e o `/tmp`, que:
- Tem tamanho limitado (100MB)
- `noexec`: nao permite execucao de binarios
- `nosuid`: ignora bits SUID/SGID
- `nodev`: nao permite dispositivos especiais

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

**Por que NAO usamos cap_add NET_RAW:**
`NET_RAW` permite crafting de pacotes de rede. Isso habilita ataques de ARP
spoofing e network sniffing de dentro do container. O OpenClawD nao precisa
disso para funcionar — conexoes HTTP de saida funcionam sem esta capability.

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
  - "127.0.0.1:8000:8000"
```

A porta e mapeada APENAS para `127.0.0.1` (localhost). Isso significa:
- Ninguem na sua rede Wi-Fi/LAN consegue acessar o OpenClawD.
- O acesso e exclusivamente pelo navegador da sua maquina.

**NAO use:**
```yaml
# ERRADO — expoe para toda a rede
ports:
  - "8000:8000"
  - "0.0.0.0:8000:8000"
```

### 6. Limite de recursos

```yaml
deploy:
  resources:
    limits:
      memory: 2G
      cpus: "1.5"
```

Impede que o container consuma todos os recursos da maquina. Se o OpenClawD
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

## Checklist de verificacao de seguranca

Execute o script de status para verificar todas as protecoes:

```bash
./scripts/status.sh prod
```

O script verifica automaticamente:
- [ ] Processo non-root
- [ ] Filesystem somente leitura
- [ ] Capabilities zeradas
- [ ] Healthcheck respondendo
- [ ] Portas mapeadas apenas em 127.0.0.1

### Verificacao manual adicional

```bash
# Socket do Docker NAO esta mapeado
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
# Mas por precaucao, nao abra as portas 8000/8080 no UFW.
```
