# Watchtower — Auto-update de containers

## O que e o Watchtower

O Watchtower monitora containers Docker em execucao e verifica periodicamente
se existem novas versoes das imagens no registro (Docker Hub). Quando encontra
uma atualizacao, ele para o container, baixa a nova imagem e reinicia com as
mesmas configuracoes.

## Por que nickfedor/watchtower?

O Watchtower original (`containrrr/watchtower`) esta **arquivado** e
**incompativel com Docker 29+**. O fork `nickfedor/watchtower` e um
drop-in replacement mantido ativamente que corrige essa incompatibilidade.

## Configuracao

O Watchtower e configurado no arquivo `docker-compose.watchtower.yml` na raiz
do projeto.

### Parametros configurados

| Variavel                    | Valor              | Descricao                                    |
|-----------------------------|--------------------|----------------------------------------------|
| WATCHTOWER_LABEL_ENABLE     | `true`             | So monitora containers com label habilitado  |
| WATCHTOWER_CLEANUP          | `true`             | Remove imagens antigas apos update           |
| WATCHTOWER_SCHEDULE         | `0 0 4 * * *`      | Verifica diariamente as 4h da manha          |
| WATCHTOWER_INCLUDE_STOPPED  | `false`            | Nao atualiza containers parados              |
| WATCHTOWER_REVIVE_STOPPED   | `false`            | Nao reinicia containers que foram parados    |

### Labels dos containers

O Watchtower usa `WATCHTOWER_LABEL_ENABLE=true`, o que significa que ele so
atualiza containers que tenham a label:

```yaml
labels:
  - "com.centurylinklabs.watchtower.enable=true"
```

Esta label ja esta configurada nos compose files de dev e prod. O proprio
container do Watchtower tem a label definida como `false` para nao se
auto-atualizar.

## Como usar

### Iniciar com Watchtower

```bash
# Iniciar OpenClaw + Watchtower juntos
./scripts/start.sh prod --with-watchtower
./scripts/start.sh dev --with-watchtower
```

### Parar

O Watchtower e parado automaticamente pelo `stop.sh`:

```bash
./scripts/stop.sh prod
```

### Verificar status

```bash
./scripts/status.sh prod
# A secao "Watchtower" mostra se esta rodando

# Ou verificar diretamente
docker logs openclaw_watchtower --tail 20
```

## Autenticacao no Docker Hub

O Watchtower precisa de acesso ao Docker Hub para verificar atualizacoes
de imagens privadas. Ele monta `~/.docker/config.json` em modo somente
leitura para isso.

### Configurar autenticacao

```bash
# Login no Docker Hub (necessario apenas uma vez)
docker login

# Verificar se o config.json foi criado
ls -la ~/.docker/config.json
```

Se o arquivo `~/.docker/config.json` nao existir, o Watchtower pode falhar
ao iniciar. Faca `docker login` antes de usar `--with-watchtower`.

## Seguranca

O container do Watchtower possui hardening:

- `read_only: true` — filesystem somente leitura
- `cap_drop: ALL` — sem capabilities do kernel
- `no-new-privileges:true` — sem escalacao de privilegios
- Docker socket montado em **somente leitura** (`:ro`)

**Nota sobre o Docker socket:** O Watchtower precisa do Docker socket para
monitorar e atualizar containers. Isso lhe da acesso ao Docker daemon,
mas e mitigado pelo `read_only` e pela ausencia de capabilities.

## Schedule (cron)

O formato do schedule segue cron de 6 campos (com segundos):

```
WATCHTOWER_SCHEDULE=0 0 4 * * *
                    │ │ │ │ │ │
                    │ │ │ │ │ └── Dia da semana (0-6, 0=Domingo)
                    │ │ │ │ └──── Mes (1-12)
                    │ │ │ └────── Dia do mes (1-31)
                    │ │ └──────── Hora (0-23)
                    │ └────────── Minuto (0-59)
                    └──────────── Segundo (0-59)
```

Exemplos:
- `0 0 4 * * *` — Todo dia as 4h (padrao)
- `0 0 */6 * * *` — A cada 6 horas
- `0 0 4 * * 1` — Toda segunda-feira as 4h

Para alterar o schedule, edite `docker-compose.watchtower.yml`.

## Troubleshooting

### Watchtower nao inicia

```bash
# Verificar se o Docker socket existe
ls -la /var/run/docker.sock

# Verificar se o config.json existe
ls -la ~/.docker/config.json

# Se nao existir, faca login
docker login
```

### Watchtower nao atualiza o container

1. Verifique se o container tem a label correta:
   ```bash
   docker inspect openclaw_core --format='{{.Config.Labels}}'
   ```

2. Verifique os logs do Watchtower:
   ```bash
   docker logs openclaw_watchtower --tail 50
   ```

3. Verifique se existe uma nova imagem no Docker Hub:
   ```bash
   docker pull iapalandi/openclaw:latest
   ```

### Forcar verificacao manual

```bash
# Executar watchtower uma unica vez (run-once)
docker exec openclaw_watchtower /watchtower --run-once
```
