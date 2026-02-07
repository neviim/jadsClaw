# Visao Geral do Projeto

## O que e o jadsClaw

Ambiente Docker seguro e isolado para executar o **OpenClaw** no Linux Mint 22,
seguindo o principio de **Privilegio Minimo**. O projeto separa os ambientes de
desenvolvimento e producao com hardening completo para proteger chaves API,
credenciais e dados da maquina host.

A imagem Docker e buildada a partir do source oficial e publicada no Docker Hub
como `iapalandi/openclaw`. O Watchtower monitora atualizacoes automaticamente.

## Arquitetura

```
jadsClaw/
├── plan/                        # Planejamento do projeto
│   └── planejamento.md
├── doc/                         # Documentacao (este diretorio)
│   ├── 01-visao-geral.md        # Este arquivo
│   ├── 02-instalacao.md         # Guia de instalacao
│   ├── 03-configuracao.md       # Configuracao de .env e APIs
│   ├── 04-seguranca.md          # Hardening e protecao
│   ├── 05-scripts.md            # Uso dos scripts operacionais
│   ├── 06-acesso-container.md   # Acesso ao container e interface web
│   ├── 07-recomendacoes.md      # Boas praticas e alertas
│   ├── 08-watchtower.md         # Auto-update com Watchtower
│   └── 09-docker-hub.md         # Publicacao no Docker Hub
├── build/                       # Dockerfile para build da imagem
│   └── Dockerfile
├── base/                        # Compose base (configuracoes comuns)
│   └── docker-compose.yml
├── dev/                         # Ambiente de desenvolvimento
│   ├── .env.example             # Template de variaveis
│   ├── docker-compose.override.yml
│   ├── data/                    # Dados persistentes (dev)
│   └── config/                  # Configuracoes (dev, gravavel)
├── prod/                        # Ambiente de producao
│   ├── .env.example             # Template de variaveis
│   ├── docker-compose.prod.yml
│   ├── data/                    # Dados persistentes (prod)
│   └── config/                  # Configuracoes (prod, somente leitura)
├── docker-compose.watchtower.yml # Watchtower (auto-update)
├── scripts/                     # Scripts operacionais
│   ├── start.sh                 # Iniciar + validar
│   ├── stop.sh                  # Parar containers
│   ├── status.sh                # Verificar status e seguranca
│   ├── logs.sh                  # Visualizar logs
│   ├── backup.sh                # Backup dos dados de producao
│   └── build-push.sh            # Build e push da imagem para Docker Hub
└── .gitignore                   # Protege .env e data/ do versionamento
```

## Principios do projeto

1. **Isolamento total**: O container nao tem acesso a home do usuario nem a
   arquivos fora dos volumes mapeados explicitamente.
2. **Privilegio minimo**: Sem root, sem capabilities do kernel, filesystem
   somente leitura em producao.
3. **Segredos protegidos**: Chaves API ficam em `.env` com `chmod 600`, nunca
   versionadas no git.
4. **Acesso local apenas**: Portas mapeadas em `127.0.0.1`, sem exposicao na LAN.
5. **Dois ambientes**: Dev para testes rapidos, Prod para uso real com hardening.
6. **Auto-update**: Watchtower monitora a imagem no Docker Hub e atualiza
   automaticamente.

## Portas

| Servico         | Porta | Endereco completo          |
|-----------------|-------|----------------------------|
| Gateway (UI)    | 18789 | http://127.0.0.1:18789     |
| Bridge          | 18790 | 127.0.0.1:18790            |

Ambos os ambientes (dev e prod) usam as mesmas portas, vinculadas a 127.0.0.1.

## Proximos passos

Siga a documentacao na ordem numerada:
1. [Instalacao](02-instalacao.md)
2. [Configuracao](03-configuracao.md)
3. [Seguranca](04-seguranca.md)
4. [Scripts](05-scripts.md)
5. [Acesso ao container](06-acesso-container.md)
6. [Recomendacoes](07-recomendacoes.md)
7. [Watchtower](08-watchtower.md)
8. [Docker Hub](09-docker-hub.md)
9. [Deploy em novo servidor](10-deploy-novo-servidor.md)
