# Rota Vital · Atividade individual 1 (Serverless)

Função serverless que recebe uma requisição do Rota Vital (POST `/guias`) e devolve a guia de transporte de bolsas de sangue.

- **Disciplina:** Infraestrutura de Software · ADS · CESAR School · 2026.2
- **Estudante:** [SEU NOME]
- **Caminho escolhido:** **A — AWS SAM CLI local** (Python 3.12, Docker, sem conta na nuvem)
- **Vídeo (até 3 min):** [LINK DO VÍDEO]

## Estrutura

```
template.yaml          # SAM: função, rota POST /guias, Timeout em Globals
hello_world/app.py     # handler da função
events/pedido.json     # evento API Gateway (pedido válido)
events/demorar.json    # evento com demorar=true (teste do timeout)
scripts/experimentos.sh# chamadas curl dos Passos 4 e 5
evidencias/            # prints dos comandos e saídas
```

## Como rodar

Pré-requisitos: Docker em execução, AWS SAM CLI (`sam --version`), Python 3.12. No Windows, usar Git Bash ou WSL.

```bash
sam build

# Passo 3 - invocação com evento (rodar 2x e anotar o tempo)
sam local invoke -e events/pedido.json

# Passo 4 - gatilho HTTP
sam local start-api
curl -X POST http://127.0.0.1:3000/guias -H "Content-Type: application/json" \
  -d '{"requisicaoId":"R-002","hospital":"H-Caruaru"}'
# repetir 3x; depois parar e subir com:
sam local start-api --warm-containers LAZY

# Passo 5 - limite de tempo (Timeout 3 s -> depois 10 s, com novo sam build)
curl -X POST http://127.0.0.1:3000/guias -H "Content-Type: application/json" \
  -d '{"requisicaoId":"R-003","demorar":true}'
```

`scripts/experimentos.sh` faz as chamadas curl em sequência.

## Resultados medidos

| Experimento | Resultado |
|---|---|
| `sam local invoke` #1 | [PREENCHER: ex. Duration/tempo total] |
| `sam local invoke` #2 | [PREENCHER] |
| `start-api` sem warm (3 chamadas) | `invocacaoNesteAmbiente` = [1, 1, 1] (conferir) |
| `start-api --warm-containers LAZY` (3 chamadas) | `invocacaoNesteAmbiente` = [1, 2, 3] (conferir) |
| `demorar=true`, Timeout 3 s | [PREENCHER: mensagem de timeout / HTTP 502] |
| `demorar=true`, Timeout 10 s | [PREENCHER: HTTP 201 após ~5 s] |

## Respostas

**1. Por que a primeira invocação demorou mais que a segunda? O que acontece na fase de Init?**
Na primeira invocação não existe ambiente de execução pronto, então acontece um *cold start*: o serviço cria o ambiente (no SAM local, um container Docker), baixa/monta o código, inicia o runtime Python e executa o código fora do handler (a fase **Init**, onde `import json, time` e `contador = 0` rodam). Só depois o handler é executado (fase Invoke). Na segunda invocação, se o ambiente for reaproveitado, o Init já foi feito e só o Invoke acontece, por isso é mais rápida. [Complemente com seus tempos medidos. Obs.: no `sam local invoke` cada chamada pode criar um container novo, então os tempos podem ser parecidos; comente o que você observou.]

**2. O que o campo `invocacaoNesteAmbiente` mostrou com e sem `--warm-containers`? O que isso diz sobre guardar estado numa variável global?**
Sem `--warm-containers`, cada requisição subiu um container novo, e o campo mostrou sempre 1. Com `--warm-containers LAZY`, o container foi mantido e o contador subiu (1, 2, 3...). Isso mostra que a variável global só sobrevive se o ambiente for reaproveitado, e isso não é garantido: o provedor pode destruir o ambiente a qualquer momento, e requisições simultâneas usam ambientes diferentes, cada um com seu próprio contador. Portanto não se deve guardar estado importante (estoque, status de requisição) em variável global; ele deve ficar em um serviço externo (banco de dados, cache, fila). A variável global serve no máximo como cache descartável (ex.: conexão com o banco).

**3. O que aconteceu com `demorar = true`? Qual é o tempo máximo de uma execução no Lambda e o que fazer com um trabalho mais longo?**
A função dorme 5 s, mas o Timeout do template é 3 s, então a execução foi interrompida pela plataforma: [PREENCHER com a mensagem exata, ex. "Function 'GuiaFunction' timed out after 3 seconds", e o retorno HTTP 502/erro ao cliente]. Com Timeout 10 s, a função terminou e devolveu 201 após ~5 s. O máximo do Lambda é **15 minutos (900 s)**. Trabalhos mais longos devem ser quebrados em etapas menores (ex.: Step Functions orquestrando várias funções, ou fila SQS com várias execuções curtas) ou migrados para um serviço sem esse limite, como containers (ECS/Fargate) ou AWS Batch.

**4. Custo de 1 milhão de execuções com 128 MB e 100 ms (us-east-1)**
- Requisições: 1.000.000 × US$ 0,20 / 1.000.000 = **US$ 0,20**
- Computação: 128 MB = 0,125 GB; 0,125 GB × 0,1 s = 0,0125 GB-s por execução
  → 1.000.000 × 0,0125 = 12.500 GB-s
  → 12.500 × US$ 0,0000166667 = **US$ 0,2083**
- **Total ≈ US$ 0,41** por milhão de execuções (sem considerar a faixa gratuita, que cobriria isso integralmente).

**5. Em que parte do Rota Vital uma função assim faria sentido e em qual não faria?**
Faz sentido em tarefas curtas, sem estado e acionadas por evento ou com demanda irregular: gerar a guia de transporte quando uma requisição é aprovada, validar os dados de um pedido, enviar notificação ao hospital quando uma bolsa muda de status, processar um evento de uma fila. Paga-se só quando há uso e escala sozinho. Não faria sentido onde há conexão ou estado contínuo, como o rastreamento em tempo real do veículo (conexões longas/WebSocket), ou onde o cold start de centenas de ms é inaceitável no caminho crítico de uma emergência sem alguma mitigação (ex.: concorrência provisionada). Também não é ideal para o armazenamento do estoque de bolsas em si, que deve ficar em um banco de dados, nem para processamentos que passam de 15 minutos. [Ajuste com os componentes reais do seu projeto em grupo.]

## Uso de IA

- **Ferramenta:** Claude (Anthropic).
- **Finalidade:** gerar o esqueleto do projeto (template.yaml, eventos, script de curl) e um rascunho do README com as respostas.
- **Como validei:** [PREENCHER com o que você de fato fez: rodei todos os comandos localmente, conferi os tempos e saídas, reescrevi as respostas com minhas palavras, comparei com a documentação da AWS (ciclo de vida do ambiente, cotas e preços do Lambda)].
