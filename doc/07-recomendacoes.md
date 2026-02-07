# Recomendacoes e Boas Praticas

## Gestao de chaves API

### Escopo minimo

Ao criar chaves API, use sempre o menor escopo possivel:

| Servico   | Permissao recomendada                                |
|-----------|------------------------------------------------------|
| Claude    | Somente Messages/Chat (sem Admin, sem Fine-tuning)   |
| Gemini    | Somente GenerateContent                              |
| Telegram  | Bot com acesso restrito por ALLOWED_USERS            |
| Discord   | Bot com permissoes minimas no servidor               |

### Rate limiting e orcamento

Configure limites de gasto nas plataformas:
- **Anthropic Console:** Defina um limite mensal em Settings > Billing
- **Google AI Studio:** Configure cotas no Google Cloud Console
- **Groq/Z.ai:** Verifique limites do plano gratuito

### Rotacao de chaves

Troque suas chaves API periodicamente:
- **Frequencia recomendada:** A cada 30-90 dias
- **Processo:**
  1. Gere uma nova chave na plataforma
  2. Atualize o `.env`
  3. Reinicie o container: `./scripts/stop.sh prod && ./scripts/start.sh prod`
  4. Confirme funcionamento: `./scripts/status.sh prod`
  5. Revogue a chave antiga na plataforma

### Monitoramento de uso

Ative alertas de uso anormal nos dashboards das APIs:
- Picos de consumo inesperados podem indicar vazamento de chave
- Se detectar uso suspeito, revogue a chave imediatamente

## Seguranca do host (Linux Mint)

### Firewall

```bash
# Manter UFW ativo
sudo ufw enable
sudo ufw status

# NAO abrir portas 18789 ou 18790 no firewall
# O bind em 127.0.0.1 ja impede acesso externo
```

### Atualizacoes

```bash
# Manter o sistema atualizado
sudo apt update && sudo apt upgrade -y

# Manter o Docker atualizado
sudo apt install --only-upgrade docker.io
```

### Docker daemon

- Nunca exponha o Docker daemon na rede (TCP socket)
- Mantenha a configuracao padrao (unix socket)
- Verifique periodicamente: `docker info | grep "Server Version"`

## Backups

### Frequencia recomendada

| Dados           | Frequencia | Comando                    |
|-----------------|------------|----------------------------|
| Dados de prod   | Semanal    | `./scripts/backup.sh`      |
| Arquivo .env    | Apos mudanca | Copia manual segura      |

### Onde armazenar backups

- Em um diretorio fora do projeto (padrao: `~/openclaw_backups/`)
- Opcionalmente em midia externa ou nuvem criptografada
- **Nunca** no mesmo disco sem backup externo

### Backup do .env

O script de backup NAO inclui o `.env` por seguranca. Para fazer backup
das chaves, use um gerenciador de senhas (KeePass, Bitwarden) ou copie
manualmente para midia criptografada.

## Volumes e persistencia

### O que cada volume armazena

| Volume               | Caminho no container       | Conteudo                | Backup necessario  |
|----------------------|----------------------------|-------------------------|--------------------|
| `data/`              | `/home/node/.openclaw`     | Banco de dados, estado  | Sim                |
| `config/`            | `/app/config`              | Configuracoes           | Sim                |

### Permissoes dos volumes

Em producao, `config/` e montado como somente leitura (`:ro`). Para alterar
configuracoes:
1. Pare o container
2. Edite os arquivos em `prod/config/`
3. Reinicie o container

## O que fazer em caso de incidente

### Suspeita de vazamento de chave API

1. **Imediatamente:** Revogue a chave na plataforma do provedor
2. Pare o container: `./scripts/stop.sh prod`
3. Gere uma nova chave
4. Atualize o `.env`
5. Verifique logs de uso na plataforma para identificar uso nao autorizado
6. Reinicie: `./scripts/start.sh prod`

### Container comprometido

1. Pare imediatamente: `./scripts/stop.sh prod --remove`
2. Revogue todas as chaves API
3. Verifique logs: `./scripts/logs.sh prod --tail 1000`
4. Recrie o ambiente do zero (nao reutilize volumes potencialmente comprometidos)
5. Gere novas chaves e reconfigure

### Container nao inicia

1. Verifique logs: `./scripts/logs.sh prod --tail 200`
2. Verifique status: `./scripts/status.sh prod`
3. Tente em modo dev para depurar: `./scripts/start.sh dev`
4. Verifique se a imagem esta correta: `docker images | grep openclaw`
5. Tente recriar: `./scripts/stop.sh prod --remove && ./scripts/start.sh prod`

## Atualizacoes do OpenClaw

### Automatica (via Watchtower)

Com o Watchtower habilitado, atualizacoes sao aplicadas automaticamente
diariamente as 4h da manha. Veja [doc/08-watchtower.md](08-watchtower.md).

### Manual

Antes de atualizar a imagem:
1. Faca backup: `./scripts/backup.sh`
2. Pare o ambiente: `./scripts/stop.sh prod`
3. Baixe a nova imagem: `docker pull iapalandi/openclaw:latest`
4. Inicie: `./scripts/start.sh prod`
5. Verifique: `./scripts/status.sh prod`

Se algo der errado, restaure o backup e reconstrua a imagem com a versao anterior:
```bash
./scripts/build-push.sh --version <tag_anterior> --no-push
```

## Checklist periodico de manutencao

### Semanal
- [ ] Verificar status: `./scripts/status.sh prod`
- [ ] Verificar logs por erros: `./scripts/logs.sh prod --tail 500`
- [ ] Fazer backup: `./scripts/backup.sh`

### Mensal
- [ ] Atualizar sistema: `sudo apt update && sudo apt upgrade`
- [ ] Verificar se o Watchtower esta atualizando corretamente
- [ ] Revisar uso de API nos dashboards
- [ ] Verificar espaco em disco

### Trimestral
- [ ] Rotacionar chaves API
- [ ] Revisar permissoes e seguranca
- [ ] Testar restauracao de backup
- [ ] Verificar se UFW esta ativo
- [ ] Rebuildar a imagem com `./scripts/build-push.sh`
